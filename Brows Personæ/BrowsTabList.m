//
//  BrowsTabList.m
//  Brows Personæ
//
//  Created by Talus Baddley on 2015-2-16.
//  Copyright (c) 2015 Eightt. All rights reserved.
//

#import "BrowsTabList.h"
#import <ReactiveCocoa/ReactiveCocoa.h>
#import "BrowsTabTableCellView.h"
#import "BrowsWindow.h"
#import "BrowsTab.h"



@interface BrowsTabList () {
    NSMutableArray *browsTabs;
    RACSignal *tabSelection;
}

@end



@implementation BrowsTabList



- (id)init {
    if (!(self = [super init])) return nil;
    
    browsTabs = [NSMutableArray array];
    
    return self;
}



- (void)awakeFromNib {
    // Called every single time there's a new tab cell created, for any reason.
    [super awakeFromNib];
    
    // Should be OK---only called on main thread, right?
    if (!tabSelection) {
        @weakify(tabsList, browsTabs)
        tabSelection = [[[[[self rac_signalForSelector:@selector(tableViewSelectionDidChange:)]
                           map:^id(RACTuple *args) { return [args first]; }]
                          filter:^BOOL(NSNotification *note) { @strongify(tabsList) return [note object] == tabsList; }]
                         map:^id(NSNotification *note) {
                             @strongify(tabsList, browsTabs)
                             return [browsTabs objectsAtIndexes:[tabsList selectedRowIndexes]];
                         }]
                        startWith:[browsTabs objectsAtIndexes:[tabsList selectedRowIndexes]]];  // There's gotta be a better way to bump the signal.
    }
    
}



- (void)swapTabs:(NSArray *)newTabs {
    // SHALL NOT ANIMATE.
    
    // Why not just reassign? B/c our signals have already-established pointers.
    [browsTabs removeAllObjects];
    [browsTabs addObjectsFromArray:newTabs];
    [tabsList reloadData];
}

- (NSArray *)tabs {
    return [browsTabs copy];
}

- (void)putTab:(BrowsTab *)tab atIndex:(NSUInteger)idex {
    [tabsList beginUpdates];
    [browsTabs insertObject:tab atIndex:idex];
    [tabsList insertRowsAtIndexes:[NSIndexSet indexSetWithIndex:idex] withAnimation:NSTableViewAnimationSlideDown];
    [tabsList endUpdates];
    //[tabsList reloadData];
}

- (void)putTab:(BrowsTab *)tab {
    [self putTab:tab atIndex:0];
}

- (void)pullTabsFromIndices:(NSIndexSet *)idices {
    [tabsList beginUpdates];
    [browsTabs removeObjectsAtIndexes:idices];
    [tabsList removeRowsAtIndexes:idices withAnimation:NSTableViewAnimationSlideLeft | NSTableViewAnimationEffectFade];
    [tabsList endUpdates];
}

- (RACSignal *)tabSelection { return tabSelection; }



- (IBAction)closeSelectedTab:(id)sender {
    // TODO
    NSBeep();
}

- (IBAction)closeTab:(id)sender {
    if (![[sender superview] respondsToSelector:@selector(representedTab)]) {
        NSLog(@"Superview of close button does not represent a tab.");
        return;
    }
    
    BrowsTab *applicableTab = [(BrowsTabTableCellView *)[sender superview] representedTab];
    
//    if ([applicableTab respondsToSelector:@selector(shouldClose)]) {
//        if ( ![applicableTab shouldClose] )  return;
//    }
    
    if (applicableTab) {
        NSUInteger tabidex = [browsTabs indexOfObject:applicableTab];
        if (tabidex != NSNotFound)
            [self pullTabsFromIndices:[NSIndexSet indexSetWithIndex:tabidex]];
    }
    
}



- (NSInteger)numberOfRowsInTableView:(NSTableView *)tableView {
    return [browsTabs count];
    
}



- (NSView *)tableView:(NSTableView *)tableView viewForTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row {
    BrowsTab *applicableTab = [browsTabs objectAtIndex:row];
    BrowsTabTableCellView *availableView = [tableView makeViewWithIdentifier:@"BrowsTabCell" owner:self];
    
    [availableView setRepresentedTab:applicableTab];
    
    // TODO Add drop-shadow to thumbnail if not present.
    
    return availableView;
    
    
}



- (CGFloat)tableView:(NSTableView *)tableView heightOfRow:(NSInteger)row {
        // TODO make dummy hidden cell and measure its height.
        CGFloat colWidth = [(NSTableColumn *)[[tableView tableColumns] objectAtIndex:0] width];
        
        // subtract the 8pt l/r margin, mult. by aspect ratio, and add the 8pt t/b margin.
        return round( (colWidth - 8 - 8) * (3 / 2.0) + 8 + 8 );
        
    
    return [tableView rowHeight];
}

- (void)tableViewSelectionDidChange:(NSNotification *)notification {  /* Swizzled out */  }












@end
