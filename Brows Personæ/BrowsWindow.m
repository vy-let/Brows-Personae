//
//  BrowsWindow.m
//  Brows Personæ
//
//  Created by Taldar Baddley on 2014-10-12.
//  Copyright (c) 2014 Eightt. All rights reserved.
//


#import "BrowsWindow.h"

#import "BrowsTab.h"

@interface BrowsWindow () {
    
}

@end

@implementation BrowsWindow



- (id)init {
    if (!(self = [super initWithWindowNibName:@"BrowsWindow"])) return nil;
    
    
    
    return self;
}



- (void)windowDidLoad {
    [super windowDidLoad];
    
    [[self window] setStyleMask:[[self window] styleMask] | NSFullSizeContentViewWindowMask];  // Set here for easier layout in nib.
    [[self window] setTitleVisibility:NSWindowTitleHidden];
    
    [self iDoDeclare];
    
}



- (void)iDoDeclare {
    
    [[locationBox rac_textSignal] subscribeNext:^(id x) {
        NSLog(@"%@", x);
    }];
    
}








@end
