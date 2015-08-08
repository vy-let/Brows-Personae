//
//  MktabController.h
//  Brows Personæ
//
//  Created by Violet Baddley on 2015-2-14.
//  Copyright (c) 2015 Eightt. All rights reserved.
//

#import <Cocoa/Cocoa.h>
@class BrowsWindow;

@interface MktabController : NSViewController <NSTableViewDataSource, NSTableViewDelegate> {
    IBOutlet NSTextField *locationBox;
    IBOutlet NSTextField *personaBox;
    IBOutlet NSButton *gotoButton;
    IBOutlet NSBox *contentSep;
    
    IBOutlet NSView *bookmarksView;
    IBOutlet NSCollectionView *bookmarksList;
    
    IBOutlet NSView *suggestionsView;
    IBOutlet NSTableView *suggestionsList;
    IBOutlet NSTableColumn *locationSuggestionColumn;
    IBOutlet NSTableColumn *personaSuggestionColumn;
    
}

- (instancetype)initWithBrowsWindow:(BrowsWindow *)windowController;

- (IBAction)iWantToGoToThere:(id)sender;

@end
