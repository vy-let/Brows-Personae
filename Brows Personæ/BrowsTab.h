//
//  BrowsTab.h
//  Brows Personæ
//
//  Created by Taldar Baddley on 2014-10-12.
//  Copyright (c) 2014 Eightt. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import <WebKit/WebKit.h>
@class SiteProfile;
@class IGIsolatedCookieWebView;


@interface BrowsTab : NSViewController {
    IBOutlet IGIsolatedCookieWebView *pageView;
    
    IBOutlet NSVisualEffectView *tooblar;
    IBOutlet NSImageView *pageSecurityIndicator;
    IBOutlet NSProgressIndicator *pageSpinny;
    IBOutlet NSSegmentedControl *forwardBackwardButtons;
    IBOutlet NSTextField *locationBox;
    IBOutlet NSButton *goStopReloadButton;
    IBOutlet NSTextField *personaIndicator;
    
}

- (instancetype)initWithProfile:(SiteProfile *)profile;
- (instancetype)initWithProfileNamed:(NSString *)profileName;

- (IBAction)submitLocation:(id)sender;
- (IBAction)goBackOrForward:(id)sender;

- (NSImage *)thumbnail;
- (NSImage *)favicon;

@end
