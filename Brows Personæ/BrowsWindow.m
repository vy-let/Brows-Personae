//
//  BrowsWindow.m
//  Brows Personæ
//
//  Created by Taldar Baddley on 2014-10-12.
//  Copyright (c) 2014 Eightt. All rights reserved.
//


#import "BrowsWindow.h"

#import <tgmath.h>
#import <ReactiveCocoa/ReactiveCocoa.h>
#import <NSArray+Functional/NSArray+Functional.h>
#import "BrowsTab.h"
#import "BrowsTabList.h"
#import "BrowsTabTableCellView.h"
#import "MktabController.h"
#import "BrowsTabState.h"
#import "BrowsPersona.h"





@interface BrowsWindow () {
    NSArray *initialTabs;
    
    dispatch_once_t didInitNewtab;
    MktabController *newtabController;
    __weak NSPopover *newtabPopover;
    
}

@end





@implementation BrowsWindow



- (id)initWithTabs:(NSArray *)tabs {
    if (!(self = [super initWithWindowNibName:@"BrowsWindow"])) return nil;
    
    initialTabs = [tabs copy];
    
    return self;
}



- (id)init {
    return [self initWithTabs:@[ ]];
}

- (void)dealloc {
    // This is getting really hackey. If we need to tab-will-close one more time,
    // some serious refactor is in order.
    NSLog(@"BrowsWindow (controller) will dealloc.");
    
//    [[tabsListController tabs] applyBlock:^(BrowsTab *tab) {
//        [tab tabWillClose];
//    }];
//    [tabsListController swapTabs:@[]];
    
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}



- (NSArray *)tabs {
    return [tabsListController tabs];
}

- (BrowsTabList *)tabListController {
    return tabsListController;
}



- (void)awakeFromNib {
    [super awakeFromNib];
    
    [tabsList registerNib:[[NSNib alloc] initWithNibNamed:@"TabCell" bundle:[NSBundle mainBundle]]
            forIdentifier:@"BrowsTabCell"];
    
    if (initialTabs)
        [tabsListController swapTabs:initialTabs];
    initialTabs = nil;
    
}




- (void)windowDidLoad {
    [super windowDidLoad];
    [[self window] setDelegate:self];
    
    [[self window] setStyleMask: [[self window] styleMask] | NSFullSizeContentViewWindowMask ];  // Set here for easier layout in nib.
    [[self window] setTitleVisibility:NSWindowTitleHidden];
    [[self window] setTitlebarAppearsTransparent:YES];
    
    NSRect windyFrame = [[self window] frame];
    windyFrame.origin.y = 0;
    windyFrame.size.height = 10000;
    [[self window] setFrame:windyFrame display:YES];
    
    if ([[tabsListController tabs] count]) {
        // Replace with last-selected indices.
        [tabsList selectRowIndexes:[NSIndexSet indexSetWithIndex:0] byExtendingSelection:NO];
        
    } else {
        // Mktab!
        dispatch_async(dispatch_get_main_queue(), ^{
            [self newTab:newTabButton];
        });
        
    }
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(ei_windowWillClose:)
                                                 name:NSWindowWillCloseNotification
                                               object:[self window]];
    
    @weakify(noTabPlaceholder)
    @weakify(multiTabsPlaceholder)
    RACSignal *viewForTabSelection =[[tabsListController tabSelection] map:^id(NSArray *selTabs) {
        @strongify(noTabPlaceholder) @strongify(multiTabsPlaceholder)
        
        switch ([selTabs count]) {
            case 1:
                return [[selTabs objectAtIndex:0] view];
                
            case 0:
                return noTabPlaceholder;
                
            default:
                return multiTabsPlaceholder;
                
        }
        
    }];
    
    @weakify(windowBody)
    [viewForTabSelection subscribeNext:^(NSView *selTab) {
        @strongify(windowBody)
        
        [windowBody setSubviews:@[selTab]];
        
        NSDictionary *views = NSDictionaryOfVariableBindings(selTab);
        [windowBody addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"H:|[selTab]|"
                                                                           options:0
                                                                           metrics:nil
                                                                             views:views]];
        [windowBody addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"V:|[selTab]|"
                                                                           options:0
                                                                           metrics:nil
                                                                             views:views]];
        
    }];
    
    
    
    [self _bindTooblarControlsToPresentTab];
    
    
}


- (void)_bindTooblarControlsToPresentTab {
    RACSignal *presentTab = [[tabsListController tabSelection] distinctUntilChanged];
    @weakify(forwardBackwardButton, locationBox, goStopReloadButton, pageTitleField, personaIndicator, securityIndicator)
    
    [presentTab subscribeNext:^(NSArray *selTabs) {
        // None of these controls should be nil unless all of them are. For succinctness, we’ll just check one.
        @strongify(forwardBackwardButton, locationBox, goStopReloadButton, pageTitleField, personaIndicator, securityIndicator)
        if (!forwardBackwardButton)
            return;
        
        BrowsTab *selTab = nil;
        if ([selTabs count] == 1)
            selTab = [selTabs objectAtIndex:0];
        
        BOOL enableControls = !!selTab;
        
        [@[forwardBackwardButton, locationBox, goStopReloadButton, pageTitleField, personaIndicator, securityIndicator]
         applyBlock:^(NSControl *tooblarControl) {
             [tooblarControl setEnabled:enableControls];
             
         }];
        
        [personaIndicator setStringValue:selTab ? [[selTab browsProfile] name] : @""];
        
    }];
    
    RACSignal *latestTabState = [[presentTab
                                  map:^id(NSArray *selTabs) {
                                      return [selTabs count] == 1 ?
                                      [(BrowsTab *)[selTabs objectAtIndex:0] tabState] :
                                      [RACSignal return:[BrowsTabState nilState]];
                                  }]
                                 switchToLatest];
    
    //
    // Can go back?
    [[[latestTabState map:^id(BrowsTabState *state) {
        return @([state canGoBackward]);
    }] distinctUntilChanged]
     
     subscribeNext:^(NSNumber *canGoBack) {
         @strongify(forwardBackwardButton)
         [forwardBackwardButton setEnabled:[canGoBack boolValue] forSegment:0];
     }];
    
    //
    // Can go forward?
    [[[latestTabState map:^id(BrowsTabState *state) {
        return @([state canGoForward]);
    }] distinctUntilChanged]
     
     subscribeNext:^(NSNumber *canGoForward) {
         @strongify(forwardBackwardButton)
         [forwardBackwardButton setEnabled:[canGoForward boolValue] forSegment:1];
     }];
    
    //
    // Location?
    RAC(locationBox, stringValue, @"") = [[latestTabState map:^id(BrowsTabState *state) {
        return [state location];
    }] distinctUntilChanged];
    
    //
    // Title?
    RAC(pageTitleField, stringValue, @"") = [[latestTabState map:^id(BrowsTabState *state) {
        return [state title];
    }] distinctUntilChanged];
    
    //
    // Is secure?
    RAC(securityIndicator, image) = [[latestTabState map:^id(BrowsTabState *state) {
        return [state isSecure] ? [NSImage imageNamed:@"NSLockLockedTemplate"] : [NSImage imageNamed:@"NSLockUnlockedTemplate"];
    }] distinctUntilChanged];
    
    //
    // Go? Stop? Reload?
    [[[[latestTabState map:^id(BrowsTabState *state) {
        return @([state isLoading]);
    }] combineLatestWith:[latestTabState map:^id(BrowsTabState *state) {
        return @([state isEditingLocation]);
    }]] distinctUntilChanged]
     
     subscribeNext:^(RACTuple *isLoadingIsEditing) {
         @strongify(goStopReloadButton)
         
         [goStopReloadButton setImage:[NSImage imageNamed:( [[isLoadingIsEditing second] boolValue] ? @"NSMenuOnStateTemplate" :
                                                             [[isLoadingIsEditing first] boolValue] ? @"NSStopProgressTemplate" :
                                                                                                      @"NSReloadTemplate" )]];
         
         [goStopReloadButton setAction:( [[isLoadingIsEditing second] boolValue] ? @selector(submitLocation:) :
                                          [[isLoadingIsEditing first] boolValue] ? @selector(stopLoad:) :
                                                                                   @selector(reLoad:) )];
         
    }];
    
    
}



// For some reason this is not called by the window, even though we're the delegate.
// So we use manual notifications instead, and this method is prefixed to avoid possible duplicate calls.
- (void)ei_windowWillClose:(NSNotification *)notification {
    if ([notification object] != [self window]) {
        NSLog(@"Receiving window-will-close for the wrong window");
        return;
    }
    NSLog(@"BrowsWindow will close");
}



- (IBAction)newTab:(id)sender {
    dispatch_once(&didInitNewtab, ^{
        newtabController = [[MktabController alloc] initWithBrowsWindow:self];
    });
    
    NSPopover *pop = newtabPopover;
    if (pop) return;
    
    newtabPopover = pop = [[NSPopover alloc] init];
    [pop setContentViewController:newtabController];
    [pop setBehavior:NSPopoverBehaviorSemitransient];
    
    [pop showRelativeToRect:[newTabButton bounds]
                     ofView:newTabButton
              preferredEdge:NSMaxYEdge];
    
}


- (void)finalizeNewTabPanelWithTab:(BrowsTab *)tab {
    [newtabPopover performClose:nil];
    newtabPopover = nil;  // just in case
    
    if (!tab) return;
    
    [tabsListController putTab:tab];
    [tabsList selectRowIndexes:[NSIndexSet indexSetWithIndex:0] byExtendingSelection:NO];
    
}






@end


















