//
//  MktabController.m
//  Brows Personæ
//
//  Created by Talus Baddley on 2015-2-14.
//  Copyright (c) 2015 Eightt. All rights reserved.
//

#import "MktabController.h"
#import "BrowsWindow.h"
#import "BrowsTab.h"
#import "SiteProfile.h"
#import "RACStream+SlidingWindow.h"
#import "Helpies.h"
#import "PublicSuffixList.h"

@interface MktabController () {
    __weak BrowsWindow *browsWindow;
    NSDate *lastClosed;
}

@end



@implementation MktabController



- (instancetype)initWithBrowsWindow:(BrowsWindow *)windowController {
    if (!(self = [super initWithNibName:@"Mktab" bundle:nil])) return nil;
    
    browsWindow = windowController;
    lastClosed = [NSDate date];
    
    // Pre-load the PSL on a separate thread.
    // It should take less than a second on any reasonable hardware, but should
    // nevertheless happen before the first keystroke.
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        [PublicSuffixList suffixList];
    });
    
    return self;
}


- (void)awakeFromNib {
    [super awakeFromNib];
    
    [self setUpRACStreams];
    
}



- (void)setUpRACStreams {
    
    RACSignal *locationSignal = [[locationBox rac_textSignal] startWith:@""];
    RACSignal *locationDestIssearch = [locationSignal map:^(NSString *loc) {
        BOOL isSearch;
        NSURL *eventualDest = urlForLocation(loc, NULL, &isSearch);
        return [RACTuple tupleWithObjects:
                loc ? loc : [RACTupleNil tupleNil]
                , eventualDest ? eventualDest : [RACTupleNil tupleNil]
                , @(isSearch)
                , nil];
    }];
    
    @weakify(gotoButton, suggestionsView, bookmarksView, contentSep, self)
    [[[locationDestIssearch map:^(RACTuple *tupTup) { return [tupTup third]; }] distinctUntilChanged]
     subscribeNext:^(NSNumber *x) {
         
         // Update search/link button icon
         @strongify(gotoButton)
         [gotoButton setImage:([x boolValue] ?
                               [NSImage imageNamed:@"NSRevealFreestandingTemplate"] :
                               [NSImage imageNamed:@"NSFollowLinkFreestandingTemplate"]
                               )];
     }];
    
    
    // Figure out when we should be showing suggestions:
    RACSignal *showSuggestions = [[locationSignal map:^(NSString *loc) {
        return @(!isBasicallyEmpty(loc));
    }] distinctUntilChanged];
    
    // Swap the suggestions/bookmarks views:
    [[[showSuggestions
       map:^id(NSNumber *suggest) {
           @strongify(suggestionsView, bookmarksView)
           return [suggest boolValue] ? suggestionsView : bookmarksView;
       }]
      nilPaddedSlidingWindowSized:2]
     subscribeNext:^(RACTuple *views) {
         @strongify(contentSep, self)
         
         // Swap first view out for second view.
         NSView *container = [self view];
         NSView *oldView = [views first];
         NSView *newView = [views second];
         
         [oldView removeFromSuperview];
         
         if (!newView) return;
         [container addSubview:newView];
         
         NSDictionary *applicableParties = NSDictionaryOfVariableBindings(newView, contentSep);
         [NSLayoutConstraint activateConstraints:
          [[NSLayoutConstraint constraintsWithVisualFormat:@"H:|[newView]|"
                                                   options:0
                                                   metrics:nil
                                                     views:applicableParties]
           arrayByAddingObjectsFromArray:
           [NSLayoutConstraint constraintsWithVisualFormat:@"V:[contentSep]-(-1)-[newView]|"
                                                   options:0
                                                   metrics:nil
                                                     views:applicableParties]]];
         
     }];
    
    // Don't show the content separator when we have the suggestions up:
    [showSuggestions subscribeNext:^(NSNumber *x) {
        @strongify(contentSep)
        [contentSep setHidden:[x boolValue]];
    }];
    
    
    RACSignal *derivedPersona = [locationDestIssearch reduceEach:^id(NSString *location, NSURL *dest, NSNumber *isSearch) {
        // Avoid unnecessarily waiting for the PSL on the main thread before any text is entered:
        if (!dest)  return nil;
        
        NSArray *privatePublicParts = [[PublicSuffixList suffixList] partition:[dest host]];
        NSString *lastPrivatePart = [[[PublicSuffixList suffixList]
                                      domainLabels:[privatePublicParts firstObject]]
                                     lastObject];
        
        NSMutableArray *registrableParts = [@[] mutableCopy];
        if ([lastPrivatePart length])  [registrableParts addObject:lastPrivatePart];
        if ([[privatePublicParts lastObject] length])  [registrableParts addObject:[privatePublicParts lastObject]];
        NSString *registrableDomain = [registrableParts componentsJoinedByString:@"."];
        
        return registrableDomain;
        
    }];
    
    @weakify(personaBox)
    [derivedPersona subscribeNext:^(NSString *profile) {
        @strongify(personaBox)
        [personaBox setStringValue:(profile ? profile : @"")];
    }];
    
    
}



- (void)viewWillAppear {
    
    // If the last time we saw this view was over 2 min ago, clear everything out.
    if ([lastClosed timeIntervalSinceNow] < -120) {
        [self clear];
    }
    
}

- (void)viewWillDisappear {
    lastClosed = [NSDate date];
}

- (void)viewDidAppear {
    [locationBox selectText:nil];
}


- (void)iWantToGoToThere:(id)sender {
    NSString *location = [locationBox stringValue];
    NSString *personaName = [personaBox stringValue];
    
    if (![personaName length]) {
        NSBeep();
        [personaBox selectText:sender];
        return;
    }
    
    NSURL *desiredLocation = urlForLocation(location, NULL, NULL);
    if (!desiredLocation) {
        [browsWindow finalizeNewTabPanelWithTab:nil];
        return;
    }
    
    [browsWindow finalizeNewTabPanelWithTab:[[BrowsTab alloc] initWithProfileNamed:personaName
                                                                   initialLocation:desiredLocation]];
    
}


- (void)clear {
    // Clear out the text-boxes and let the suggestions fall away.
    // Should also scroll the bookmarks list to the top.
    [locationBox setStringValue:@""];
    
    // May not be needed if RAC updates it for us:
    [personaBox setStringValue:@""];
    
}


@end
