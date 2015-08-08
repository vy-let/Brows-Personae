//
//  BrowsTabList.h
//  Brows Personæ
//
//  Created by Violet Baddley on 2015-2-16.
//  Copyright (c) 2015 Eightt. All rights reserved.
//

#import <Cocoa/Cocoa.h>
@class RACSignal;
@class BrowsWindow;
@class BrowsTab;

@interface BrowsTabList : NSObject <NSTableViewDataSource, NSTableViewDelegate> {
    __weak IBOutlet NSTableView *tabsList;
    __weak IBOutlet BrowsWindow *windowController;
}


- (NSArray *)tabs;
- (void)swapTabs:(NSArray *)newTabs;
- (void)putTab:(BrowsTab *)tab;
- (void)putTab:(BrowsTab *)tab atIndex:(NSUInteger)idex;
- (NSUInteger)indexOfTab:(BrowsTab *)tab;

- (IBAction)closeSelectedTab:(id)sender;
- (IBAction)closeTab:(id)sender;

- (RACSignal *)tabSelection;
- (void)selectTabsAtIndices:(NSIndexSet *)idices;

@end
