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


@interface BrowsTab : NSViewController <WKNavigationDelegate, WKUIDelegate> {
    IBOutlet WKWebView *pageView;  // still IBOutlet---wishful thinking, I suppose.
    
    IBOutlet NSLayoutConstraint *tooblarBackingHeightStrut;
    
    IBOutlet NSVisualEffectView *tooblarBacking;
    
    IBOutlet NSVisualEffectView *jsAlertPane;
    IBOutlet NSTextField *jsAlertHeader;
    IBOutlet NSTextField *jsAlertMessage;
    IBOutlet NSButton *jsAlertCancelButton;
    
    IBOutlet NSVisualEffectView *jsQueryPane;
    IBOutlet NSTextField *jsQueryHeader;
    IBOutlet NSTextField *jsQueryMessage;
    IBOutlet NSTextField *jsQueryResponseField;
    
}

- (instancetype)initWithProfile:(BrowsPersona *)profile webViewConfiguration:(WKWebViewConfiguration *)conf;
- (instancetype)initWithProfile:(BrowsPersona *)profile initialLocation:(NSURL *)loc;
- (instancetype)initWithProfileNamed:(NSString *)profileName initialLocation:(NSURL *)loc;

- (IBAction)submitLocation:(id)sender;
- (IBAction)gotoTheBackward:(id)sender;
- (IBAction)goFroth:(id)sender;
- (IBAction)stopLoad:(id)sender;
- (IBAction)reLoad:(id)sender;

- (IBAction)finishJSAlertPanelAffirmatively:(id)sender;
- (IBAction)finishJSAlertPanelNegatively:(id)sender;

- (void)tabWillClose;

@property (nonatomic, readonly) BrowsPersona *browsProfile;
@property (nonatomic, readonly) WKWebView *pageView;
@property (nonatomic, readonly) NSImage *thumbnail;
@property (nonatomic, readonly) NSImage *favicon;
@property (nonatomic, readonly) RACSignal *tabState;

@end

