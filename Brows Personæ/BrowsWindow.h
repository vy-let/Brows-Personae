//
//  BrowsWindow.h
//  Brows Personæ
//
//  Created by Taldar Baddley on 2014-10-12.
//  Copyright (c) 2014 Eightt. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import <ReactiveCocoa/ReactiveCocoa.h>

@interface BrowsWindow : NSWindowController <NSTableViewDataSource, NSTableViewDelegate> {
    IBOutlet NSTableView *tabsList;
    IBOutlet NSView *windowBody;
    IBOutlet NSView *noTabPlaceholder;
    IBOutlet NSView *multiTabsPlaceholder;
}


- (IBAction)newTab:(id)sender;



@end
