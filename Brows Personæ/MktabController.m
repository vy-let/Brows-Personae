//
//  MktabController.m
//  Brows Personæ
//
//  Created by Talus Baddley on 2015-2-14.
//  Copyright (c) 2015 Eightt. All rights reserved.
//

#import "MktabController.h"
#import <NSArray+Functional/NSArray+Functional.h>
#import "BrowsWindow.h"
#import "BrowsTab.h"
#import "BrowsPersona.h"
#import "RACStream+SlidingWindow.h"
#import "Helpies.h"
#import "PublicSuffixList.h"

@interface MktabController () {
    __weak BrowsWindow *browsWindow;
    NSDate *lastClosed;
    NSArray *orderedSuggestions;
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
        
        return [[PublicSuffixList suffixList] publiclyRegistrableDomain:[dest host]];
        
    }];
    
    @weakify(personaBox)
    [derivedPersona subscribeNext:^(NSString *profile) {
        @strongify(personaBox)
        [personaBox setStringValue:(profile ? profile : @"")];
    }];
    
    
    
    @weakify(locationBox)
    [locationSignal subscribeNext:^(NSString *ipnut) {
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            NSMutableArray *mainThreadResults = [NSMutableArray array];
            
            [[BrowsPersona allLocalPersonæ] applyBlock:^(BrowsPersona *persona) {
                [persona findHistoryItemsMatching:ipnut deliveringResultsToMainQueueByDoing:^(NSArray *results, BOOL *stop) {
                    @strongify(locationBox, self)
                    
                    if (![[locationBox stringValue] isEqual:ipnut]) {
                        // User has moved on. Do not process results, pass go, or collect $200. Tear it down, we're done.
                        *stop = YES;
                        return;
                    }
                    
                    for (NSArray *resultTuple in results) {
                        // Main thread results will contain a new @[rank, history item, persona] tuple for the suggestion.
                        [mainThreadResults addObject:[resultTuple arrayByAddingObject:persona]];
                        
                        // Now use that structure to sort as a sort of proto-priority queue.
                        [mainThreadResults sortUsingComparator:^NSComparisonResult(NSArray *leftTuple, NSArray *rightTuple) {
                            
                            // Do rankwise comparison first, as priority.
                            NSComparisonResult rankwiseComparison = [leftTuple[0] compare: rightTuple[0]];
                            if (rankwiseComparison != NSOrderedSame)
                                return rankwiseComparison;
                            
                            // Elsewise do most recent first.
                            NSTimeInterval leftAtime = [leftTuple[1] lastVisitedTimeInterval];  NSTimeInterval rightAtime = [rightTuple[1] lastVisitedTimeInterval];
                            return (  leftAtime > rightAtime ? NSOrderedDescending
                                    : leftAtime < rightAtime ? NSOrderedAscending
                                    :                          NSOrderedSame      );
                            
                        }];
                        
                    }
                    
                    [self _updateHistoryResults:mainThreadResults];
                    
                    
                }];
            }];
            
        });
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



- (void)_updateHistoryResults:(NSArray *)rankedResults {
    orderedSuggestions = rankedResults;  // Yes, it really is actually mutated after assignment---but only on the main thread (-_^)!
    [suggestionsList reloadData];
}


- (void)clear {
    // Clear out the text-boxes and let the suggestions fall away.
    // Should also scroll the bookmarks list to the top.
    [locationBox setStringValue:@""];
    
    // May not be needed if RAC updates it for us:
    [personaBox setStringValue:@""];
    
    [self _updateHistoryResults:@[]];
    
}







#pragma mark History Suggestions View Data Source



- (NSInteger)numberOfRowsInTableView:(NSTableView *)tableView {
    return [orderedSuggestions count];
}

- (id)tableView:(NSTableView *)tableView objectValueForTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row {
    NSArray *relevantSuggestion = [orderedSuggestions objectAtIndex:row];
    WebHistoryItem *relevantHistoryItem = relevantSuggestion[1];
    BrowsPersona *relevantPersona = relevantSuggestion[2];
    
    if (tableColumn == locationSuggestionColumn) {
        return [NSString stringWithFormat:@"%@ — %@", [relevantHistoryItem title], [relevantHistoryItem URLString]];
        
    } else if (tableColumn == personaSuggestionColumn) {
        return [relevantPersona name];
        
    }
    
    return @"";
    
}

- (void)tableViewSelectionDidChange:(NSNotification *)notification {
    NSInteger selectedRow = [suggestionsList selectedRow];
    if (selectedRow == -1)
        return;
    else if (selectedRow >= [orderedSuggestions count]) {
        NSLog(@"Selection did change to a nonexistant row!");
        return;
    }
    
    NSArray *selectedResultTuple = [orderedSuggestions objectAtIndex:selectedRow];
    NSString *location = [(WebHistoryItem *)selectedResultTuple[1] URLString];
    BrowsPersona *persona = selectedResultTuple[2];
    
    [locationBox setStringValue:location];
    [personaBox setStringValue:[persona name]];
    
}

















@end
