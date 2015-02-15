//
//  MktabController.h
//  Brows Personæ
//
//  Created by Talus Baddley on 2015-2-14.
//  Copyright (c) 2015 Eightt. All rights reserved.
//

#import <Cocoa/Cocoa.h>
@class BrowsWindow;

@interface MktabController : NSViewController {
    IBOutlet NSTextField *locationBox;
    IBOutlet NSTextField *personaBox;
    IBOutlet NSButton *gotoButton;
    IBOutlet NSBox *contentSep;
    
    IBOutlet NSView *bookmarksView;
    IBOutlet NSCollectionView *bookmarksList;
    
    IBOutlet NSView *suggestionsView;
    IBOutlet NSTableView *suggestionsList;
    
}

- (instancetype)initWithBrowsWindow:(BrowsWindow *)windowController;

- (IBAction)iWantToGoToThere:(id)sender;

@end
