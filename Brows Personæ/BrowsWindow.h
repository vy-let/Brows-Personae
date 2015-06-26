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
}


- (IBAction)newTab:(id)sender;
- (void)finalizeNewTabPanelWithTab:(BrowsTab *)tab;

- (NSArray *)tabs;
- (BrowsTabList *)tabListController;



@end
