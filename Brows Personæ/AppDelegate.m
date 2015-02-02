//
//  AppDelegate.m
//  Brows Personæ
//
//  Created by Taldar Baddley on 2014-10-12.
//  Copyright (c) 2014 Eightt. All rights reserved.
//

#import "AppDelegate.h"
#import "BrowsWindow.h"
#import "BrowsTabTableCellView.h"

@interface AppDelegate () {
    NSMutableArray *browsWindows;
}

@property (weak) IBOutlet NSWindow *window;
@end

@implementation AppDelegate

- (id)init {
    if (!(self = [super init]))
        return nil;
    
    browsWindows = [[NSMutableArray alloc] init];
    
    return self;
}

- (IBAction)newBrowsWindow:(id)sender {
    BrowsWindow *newWindow = [[BrowsWindow alloc] init];
    [browsWindows addObject:newWindow];
    
    [newWindow showWindow:sender];
}

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification {
    // Insert code here to initialize your application
    
}

- (void)applicationWillTerminate:(NSNotification *)aNotification {
    // Insert code here to tear down your application
}

@end
