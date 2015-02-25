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
    IBOutlet NSButton *gotoTheBackwardButton;
    IBOutlet NSButton *goFrothButton;
    IBOutlet NSTextField *locationBox;
    IBOutlet NSButton *goStopReloadButton;
    IBOutlet NSTextField *personaIndicator;
    
}

- (instancetype)initWithProfile:(SiteProfile *)profile initialLocation:(NSURL *)loc;
- (instancetype)initWithProfileNamed:(NSString *)profileName initialLocation:(NSURL *)loc;

- (IBAction)submitLocation:(id)sender;
- (IBAction)gotoTheBackward:(id)sender;
- (IBAction)goFroth:(id)sender;
- (IBAction)stopLoad:(id)sender;
- (IBAction)reLoad:(id)sender;

@property (nonatomic) NSImage *thumbnail;
@property (nonatomic) NSImage *favicon;

@end
