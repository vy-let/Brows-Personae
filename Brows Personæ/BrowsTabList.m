//
//  BrowsTabList.m
//  Brows Personæ
//
//  Created by Violet Baddley on 2015-2-16.
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

- (void)dealloc {
    NSLog(@"BrowsTabList will dealloc with browsTabs: %@", browsTabs);
    [browsTabs enumerateObjectsWithOptions:NSEnumerationReverse usingBlock:^(BrowsTab *tab, NSUInteger idex, BOOL *stop) {
        NSLog(@"Closing tab completely: %@", tab);
        [self _closeTabCompletely:tab animate:NO];
    }];
    [tabsList enumerateAvailableRowViewsUsingBlock:^(NSTableRowView *rowView, NSInteger row) {
        BrowsTabTableCellView *retainer = [rowView viewAtColumn:0];
        NSLog(@"Removing tab from its last (?) leash: %@", retainer);
        [retainer setObjectValue:nil];
    }];
}



- (void)awakeFromNib {
    // Called every single time there's a new tab cell created, for any reason.
    [super awakeFromNib];
    
    // Should be OK---only called on main thread, right?
    if (!tabSelection) {
        @weakify(tabsList, browsTabs)
        // signalForSelector “completes when the receiver is deallocated” so we don’t need to clean up:
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

- (void)pullTabsFromIndices:(NSIndexSet *)idices animate:(BOOL)shouldAnimate {
    [tabsList beginUpdates];
    [browsTabs removeObjectsAtIndexes:idices];
    [tabsList removeRowsAtIndexes:idices withAnimation:( shouldAnimate ? (NSTableViewAnimationSlideLeft | NSTableViewAnimationEffectFade) : NSTableViewAnimationEffectNone)];
    [tabsList endUpdates];
}

- (RACSignal *)tabSelection { return tabSelection; }

- (void)selectTabsAtIndices:(NSIndexSet *)idices {
    [tabsList selectRowIndexes:idices byExtendingSelection:NO];
}

- (NSUInteger)indexOfTab:(BrowsTab *)tab {
    return [browsTabs indexOfObject:tab];
    
}



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
    
    if (applicableTab)
        [self _closeTabCompletely:applicableTab animate:YES];
    
}

- (void)_closeTabCompletely:(BrowsTab *)applicableTab animate:(BOOL)shouldAnimate {
    [applicableTab tabWillClose];
    
    NSUInteger tabidex = [browsTabs indexOfObject:applicableTab];
    if (tabidex == NSNotFound)
        return;
    
    [self pullTabsFromIndices:[NSIndexSet indexSetWithIndex:tabidex] animate:shouldAnimate];
    
}



- (NSInteger)numberOfRowsInTableView:(NSTableView *)tableView {
    return [browsTabs count];
    
}

- (id)tableView:(NSTableView *)tableView objectValueForTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row {
    return [browsTabs objectAtIndex:row];
}



- (NSView *)tableView:(NSTableView *)tableView viewForTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row {
    //BrowsTab *applicableTab = [self tableView:tableView objectValueForTableColumn:tableColumn row:row];
    BrowsTabTableCellView *availableView = [tableView makeViewWithIdentifier:@"BrowsTabCell" owner:self];
    
    //[availableView setRepresentedTab:applicableTab];
    
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

- (void)tableView:(NSTableView *)tableView didRemoveRowView:(NSTableRowView *)rowView forRow:(NSInteger)row {
    if (row < 0)
        [[rowView viewAtColumn:0] setObjectValue:nil];
}

- (void)tableViewSelectionDidChange:(NSNotification *)notification {  /* Swizzled out */  }












@end
