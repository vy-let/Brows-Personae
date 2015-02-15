//
//  MktabController.m
//  Brows Personæ
//
//  Created by Talus Baddley on 2015-2-14.
//  Copyright (c) 2015 Eightt. All rights reserved.
//

#import "MktabController.h"
#import "BrowsWindow.h"
#import "BrowsTab.h"

@interface MktabController () {
    __weak BrowsWindow *browsWindow;
}

@end



@implementation MktabController



- (instancetype)initWithBrowsWindow:(BrowsWindow *)windowController {
    if (!(self = [super initWithNibName:@"Mktab" bundle:nil])) return nil;
    
    browsWindow = windowController;
    
    return self;
}


- (void)awakeFromNib {
    [super awakeFromNib];
    
    [self setUpRACStreams];
    
}


- (void)setUpRACStreams {
    
}


- (void)viewWillAppear {
    // If it's been more than (sixty?) seconds since we've last seen the view,
}

- (void)viewDidAppear {
    // Set location box as key view and select its contents.
}


- (void)iWantToGoToThere:(id)sender {
    NSString *personaName = [personaBox stringValue];
    
    if (!personaName) {
        NSBeep();
        [personaBox selectText:sender];
        return;
    }
    
    [browsWindow finalizeNewTabPanelWithTab:[[BrowsTab alloc] initWithProfileNamed:personaName]];
    
}


- (void)clear {
    // Clear out the text-boxes and let the suggestions fall away.
    // Should also scroll the bookmarks list to the top.
}


@end
