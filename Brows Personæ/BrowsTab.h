//
//  BrowsTab.h
//  Brows Personæ
//
//  Created by Taldar Baddley on 2014-10-12.
//  Copyright (c) 2014 Eightt. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import <WebKit/WebKit.h>
@class BrowsPersona;
@class EIIGIsolatedCookieWebView;


@interface BrowsTab : NSViewController {
    IBOutlet WKWebView *pageView;
    
    IBOutlet NSVisualEffectView *tooblar;
    IBOutlet NSImageView *pageSecurityIndicator;
    IBOutlet NSProgressIndicator *pageSpinny;
    IBOutlet NSButton *gotoTheBackwardButton;
    IBOutlet NSButton *goFrothButton;
    IBOutlet NSTextField *locationBox;
    IBOutlet NSButton *goStopReloadButton;
    IBOutlet NSTextField *personaIndicator;
    
}

- (instancetype)initWithProfile:(BrowsPersona *)profile initialLocation:(NSURL *)loc;
- (instancetype)initWithProfileNamed:(NSString *)profileName initialLocation:(NSURL *)loc;

- (IBAction)submitLocation:(id)sender;
- (IBAction)gotoTheBackward:(id)sender;
- (IBAction)goFroth:(id)sender;
- (IBAction)stopLoad:(id)sender;
- (IBAction)reLoad:(id)sender;

- (void)tabWillClose;

@property (nonatomic, readonly) NSImage *thumbnail;
@property (nonatomic, readonly) NSImage *favicon;

@end

