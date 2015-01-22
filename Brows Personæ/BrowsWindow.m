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





@interface BrowsWindow () {
    NSMutableArray *tabs;
    RACSignal *frontTab;
    __weak id<RACSubscriber> tabChanger;
}

@end





@implementation BrowsWindow



- (id)init {
    if (!(self = [super initWithWindowNibName:@"BrowsWindow"])) return nil;
    
    tabs = [NSMutableArray array];
    __block BrowsWindow *bself = self;
    frontTab = [RACSignal createSignal:^RACDisposable *(id<RACSubscriber> subscriber) {
        bself->tabChanger = subscriber;
        return nil;  // No cleanup.
    }];
    
    return self;
}




- (void)windowDidLoad {
    [super windowDidLoad];
    
    [[self window] setStyleMask:[[self window] styleMask] | NSFullSizeContentViewWindowMask];  // Set here for easier layout in nib.
    [[self window] setTitleVisibility:NSWindowTitleHidden];
    [[self window] setTitlebarAppearsTransparent:YES];
    

    [self iDoDeclare];
    
}



- (void)iDoDeclare {
    
    [[locationBox rac_textSignal] subscribeNext:^(id x) {
        NSLog(@"%@", x);
    }];
    
    [frontTab subscribeNext:^(BrowsTab *presentTab) {
        // Change out subviews.
    }];
    
}



- (IBAction)newTab:(id)sender {
    
}












@end
