//
//  BrowsTabTableCellView.h
//  Brows Personæ
//
//  Created by Talus Baddley on 2015-1-22.
//  Copyright (c) 2015 Eightt. All rights reserved.
//

#import <Cocoa/Cocoa.h>
@class BrowsTab;

@interface BrowsTabTableCellView : NSTableCellView

@property (nonatomic, weak) BrowsTab *representedTab;
@property (nonatomic) IBOutlet NSImageView *thumbnailView;
@property (nonatomic) IBOutlet NSImageView *faviconView;
@property (nonatomic) IBOutlet NSButton *tabCloseButton;

+ (instancetype)measurementDummyView;

@end
