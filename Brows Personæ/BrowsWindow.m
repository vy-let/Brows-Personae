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
#import "BrowsTab.h"
#import "BrowsTabTableCellView.h"





@interface BrowsWindow () {
    NSMutableArray *browsTabs;
    RACSignal *tabSelection;
    RACSignal *viewForTabSelection;
}

@end





@implementation BrowsWindow



- (id)initWithTabs:(NSArray *)tabs {
    if (!(self = [super initWithWindowNibName:@"BrowsWindow"])) return nil;
    
    browsTabs = [tabs mutableCopy];
    
    return self;
}



- (id)init {
    return [self initWithTabs:@[ [[BrowsTab alloc] initWithProfileNamed:@"a.com"],
                                 [[BrowsTab alloc] initWithProfileNamed:@"b.org"] ]];
}



- (void)awakeFromNib {
    [super awakeFromNib];
    
    [tabsList registerNib:[[NSNib alloc] initWithNibNamed:@"TabCell" bundle:[NSBundle mainBundle]]
            forIdentifier:@"BrowsTabCell"];
    
}




- (void)windowDidLoad {
    [super windowDidLoad];
    
    [[self window] setStyleMask: [[self window] styleMask] | NSFullSizeContentViewWindowMask ];  // Set here for easier layout in nib.
//    [[self window] setTitleVisibility:NSWindowTitleHidden];
    [[self window] setTitlebarAppearsTransparent:YES];
    
    @weakify(tabsList)
    @weakify(browsTabs)
    tabSelection = [[[[[self rac_signalForSelector:@selector(tableViewSelectionDidChange:)]
                       map:^id(RACTuple *args) { return [args first]; }]
                      filter:^BOOL(NSNotification *note) { @strongify(tabsList); return [note object] == tabsList; }]
                     map:^id(NSNotification *note) {
                        @strongify(tabsList); @strongify(browsTabs);
                        return [browsTabs objectsAtIndexes:[tabsList selectedRowIndexes]];
                     }]
                    startWith:@[]];
    
    
    @weakify(noTabPlaceholder)
    @weakify(multiTabsPlaceholder)
    viewForTabSelection =[tabSelection map:^id(NSArray *selTabs) {
        @strongify(noTabPlaceholder); @strongify(multiTabsPlaceholder);
        
        switch ([selTabs count]) {
            case 1:
                return [[selTabs objectAtIndex:0] view];
                
            case 0:
                return noTabPlaceholder;
                
            default:
                return multiTabsPlaceholder;
                
        }
        
    }];
    
    [viewForTabSelection subscribeNext:^(NSView *selTab) {
        [windowBody setSubviews:@[selTab]];
    }];
    
    
    if ([browsTabs count]) {
        [tabsList selectRowIndexes:[NSIndexSet indexSetWithIndex:0] byExtendingSelection:NO];
    }
    
}



- (IBAction)newTab:(id)sender {
    // TODO Pop over!
    
    
}









- (NSInteger)numberOfRowsInTableView:(NSTableView *)tableView {
    if (tableView == tabsList) {
        return [browsTabs count];
        
    }
    
    
    return 0;
    
}



- (NSView *)tableView:(NSTableView *)tableView viewForTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row {
    if (tableView == tabsList) {
        BrowsTab *applicableTab = [browsTabs objectAtIndex:row];
        BrowsTabTableCellView *availableView = [tableView makeViewWithIdentifier:@"BrowsTabCell" owner:self];
        
        [[availableView thumbnailView] setImage:[applicableTab thumbnail]];
        [[availableView faviconView] setImage:[applicableTab favicon]];
        
        // TODO Add drop-shadow to thumbnail if not present.
        
        return availableView;
        
    }
    
    return nil;
    
}



- (CGFloat)tableView:(NSTableView *)tableView heightOfRow:(NSInteger)row {
    if (tableView == tabsList) {
        // TODO make dummy hidden cell and measure its height.
        CGFloat colWidth = [[[tableView tableColumns] objectAtIndex:0] width];
        
        // subtract the 8pt l/r margin, mult. by aspect ratio, and add the 8pt t/b margin.
        return round( (colWidth - 8 - 8) * (3 / 2.0) + 8 + 8 );
        
    }
    
    return [tableView rowHeight];
}

- (void)tableViewSelectionDidChange:(NSNotification *)notification {  /* Swizzled out */  }





@end


















