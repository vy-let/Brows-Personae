//
//  BrowsWindow.h
//  Brows Personæ
//
//  Created by Taldar Baddley on 2014-10-12.
//  Copyright (c) 2014 Eightt. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import <ReactiveCocoa/ReactiveCocoa.h>
@class BrowsTab;
@class BrowsTabList;

@interface BrowsWindow : NSWindowController <NSWindowDelegate> {
    IBOutlet NSTableView *tabsList;
    IBOutlet BrowsTabList *tabsListController;
    IBOutlet NSButton *newTabButton;
    IBOutlet NSView *windowBody;
    IBOutlet NSView *noTabPlaceholder;
    IBOutlet NSView *multiTabsPlaceholder;
    
    IBOutlet NSSegmentedControl *forwardBackwardButton;
    IBOutlet NSTextField *locationBox;
    IBOutlet NSButton *goStopReloadButton;
    IBOutlet NSTextField *pageTitleField;
    IBOutlet NSTextField *personaIndicator;
    IBOutlet NSButton *securityIndicator;
    
}


- (IBAction)newTab:(id)sender;
- (void)finalizeNewTabPanelWithTab:(BrowsTab *)tab;

- (NSArray *)tabs;
- (BrowsTabList *)tabListController;


- (IBAction)goToLocation:(id)sender;
- (IBAction)stopLoading:(id)sender;
- (IBAction)reload:(id)sender;

// - (IBAction)revealPageCertificateInformation:(id)sender;  // TODO un-unimplement this.



@end
