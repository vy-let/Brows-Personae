//
//  BrowsWindow.m
//  Brows Personæ
//
//  Created by Taldar Baddley on 2014-10-12.
//  Copyright (c) 2014 Eightt. All rights reserved.
//


#import "BrowsWindow.h"

#import <ReactiveCocoa/ReactiveCocoa.h>
#import "BrowsTab.h"
#import "BrowsTabTableCellView.h"





@interface BrowsWindow () {
    NSMutableArray *browsTabs;
    NSNib *tabCellNib;
}

@end





@implementation BrowsWindow



- (id)initWithTabs:(NSArray *)tabs {
    if (!(self = [super initWithWindowNibName:@"BrowsWindow"])) return nil;
    
    browsTabs = [tabs mutableCopy];
    tabCellNib = [[NSNib alloc] initWithNibNamed:@"TabCell" bundle:[NSBundle mainBundle]];
    
    return self;
}



- (id)init {
    return [self initWithTabs:@[]];
}




- (void)windowDidLoad {
    [super windowDidLoad];
    
    [[self window] setStyleMask:[[self window] styleMask] | NSFullSizeContentViewWindowMask];  // Set here for easier layout in nib.
//    [[self window] setTitleVisibility:NSWindowTitleHidden];
    [[self window] setTitlebarAppearsTransparent:YES];
    

    
}



- (IBAction)newTab:(id)sender {
    // Pop over!
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
        
    }
    
    return nil;
    
}





@end


















