//
//  BrowsTab.m
//  Brows Personæ
//
//  Created by Taldar Baddley on 2014-10-12.
//  Copyright (c) 2014 Eightt. All rights reserved.
//

#import <WebKit/WebKit.h>
#import <ReactiveCocoa/ReactiveCocoa.h>

#import "BrowsWindow.h"
#import "BrowsTabList.h"
#import "BrowsTab.h"
#import "BrowsTabState.h"
#import "BrowsPersona.h"
#import "EIIGIsolatedCookieWebView.h"
#import "EIIGIsolatedCookieWebViewResourceLoadDelegate.h"
#import "WebView+ScrollViewAccess.h"
#import <NSArray+Functional/NSArray+Functional.h>
#import "Helpies.h"
#import "PublicSuffixList.h"


@interface WKWebView (WKPrivate)
@property (nonatomic, setter=_setTopContentInset:) CGFloat _topContentInset;
@end

@implementation WKWebView (WKPrivate)
@dynamic _topContentInset;
@end


@interface BrowsTab () {
    NSObject *tabViewButtonThing;
    BrowsPersona *browsProfile;
    RACSubject *locationDasu;  // Into which submit events are pushed.
    RACSignal *tabState;
    
    NSImage *latestThumbnail;
    NSImage *latestFavicon;
    
    NSURL *initialLocation;
    
    NSView *jsOverlayPane;
    void (^jsFinishOverlay)(BOOL wasAffirmative);
    
}

@end



@implementation BrowsTab

- (instancetype)initWithProfile:(BrowsPersona *)profile initialLocation:(NSURL *)urlOrSearch {
    if (!(self = [super initWithNibName:@"BrowsTab" bundle:nil])) return nil;
    
    browsProfile = profile;
    locationDasu = [RACSubject subject];
    
    initialLocation = urlOrSearch;
    
    [self _setPageViewWithConfiguration:nil];
    
    return self;
    
}

- (instancetype)initWithProfile:(BrowsPersona *)profile webViewConfiguration:(WKWebViewConfiguration *)conf {
    if (!(self = [self initWithProfile:profile initialLocation:nil]))  return nil;
    [self _setPageViewWithConfiguration:conf];
    
    return self;
}

- (instancetype)initWithProfileNamed:(NSString *)profileName initialLocation:(NSURL *)urlOrSearch {
    NSString *rootHost = [[PublicSuffixList suffixList] publiclyRegistrableDomain:[urlOrSearch host]];
    if (!rootHost)  rootHost = [urlOrSearch host];
    
    return [self initWithProfile:[BrowsPersona named:profileName withRootHost:rootHost]
                 initialLocation:urlOrSearch];
}

- (id)init {
    NSAssert(false, @"Cannot raw-init a BrowsTab!");
    return nil;
}

- (void)dealloc {
    //[pageView close];
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [self _dismissPriorAlertHandler];
    NSLog(@"Brows Tab for %@ at %@ is being deallocated.", [browsProfile name], [[pageView URL] absoluteString]);
}


- (void)awakeFromNib {
    [super awakeFromNib];
    [tooblarBacking setBlendingMode:NSVisualEffectBlendingModeWithinWindow];
    [tooblarBacking setMaterial:NSVisualEffectMaterialTitlebar];
    
    [@[jsAlertPane, jsQueryPane] applyBlock:^(NSVisualEffectView *pane) {
        [pane setBlendingMode:NSVisualEffectBlendingModeWithinWindow];
        [pane setMaterial:NSVisualEffectMaterialLight];
        [pane setAppearance:[NSAppearance appearanceNamed:NSAppearanceNameVibrantLight]];
    }];
    
    [self placePageView];
    
    // The following settings were from WebKitLegacy:
    //[[pageView preferences] setPrivateBrowsingEnabled:YES];
    //[[pageView mainFrame] setEi_browsPersona:browsProfile];
    [pageView setCustomUserAgent:@"Mozilla/5.0 (Macintosh; Intel Mac OS X 10_10_2) AppleWebKit/600.3.18 (KHTML, like Gecko) Version/8.0.3 Safari/600.3.18"];
    //[pageView setShouldUpdateWhileOffscreen:NO];
    //[pageView setShouldCloseWithWindow:NO];
    
    [self setUpRACListeners];
    [self pushInitialInterfaceState];  // Must happen *after* RAC is already listening, in some cases.
    
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(updateProgress:)
                                                 name:WebViewProgressEstimateChangedNotification
                                               object:pageView];
    
}



- (void)tabWillClose { }



- (void)_setPageViewWithConfiguration:(WKWebViewConfiguration *)config {
    WKPreferences *webPrefs = [[WKPreferences alloc] init];
    [webPrefs setJavaEnabled:NO];
    [webPrefs setJavaScriptEnabled:YES];
    [webPrefs setJavaScriptCanOpenWindowsAutomatically:YES];
    [webPrefs setPlugInsEnabled:NO];
    
    if (!config) {
        config = [[WKWebViewConfiguration alloc] init];
        [config setProcessPool:[browsProfile webProcessPool]];  // Usually, making the tab (as here) will be the first time the profile is asked for its process pool, which should be lazily created.
        [config setPreferences:webPrefs];
        [config setSuppressesIncrementalRendering:NO];
        [config setWebsiteDataStore:[browsProfile webkitDataBacking]];
    }
    
    
    pageView = [[WKWebView alloc] initWithFrame:NSMakeRect(0, 0, 500, 500)
                                  configuration:config];
    
}

- (void)placePageView {
    // Ya know, there's a REASON we have nib files. There's a fucking reason.
    // Ugh.
    
    [pageView setTranslatesAutoresizingMaskIntoConstraints:NO];
    //[pageView setNavigationDelegate:self];
    [pageView setUIDelegate:self];
    
    [[self view] addSubview:pageView
                 positioned:NSWindowBelow
                 relativeTo:tooblarBacking];
    
    
    NSDictionary *applicableParties = NSDictionaryOfVariableBindings(pageView);
    [NSLayoutConstraint activateConstraints:
     [[NSLayoutConstraint constraintsWithVisualFormat:@"H:|[pageView]|"
                                              options:0
                                              metrics:nil
                                                views:applicableParties]
      arrayByAddingObjectsFromArray:
      [NSLayoutConstraint constraintsWithVisualFormat:@"V:|[pageView]|"
                                              options:0
                                              metrics:nil
                                                views:applicableParties]]];
    
    
}



- (void)setUpRACListeners {
    
    // TODO Listen for page changes and interaction
    //RACSignal *pageViewSendEventSignal = [[[pageView ei_scrollView] documentView] rac_signalForSelector:@selector(sendEvent:)];
    RACSignal *pageViewSendEventSignal = [RACSignal never];  // TODO unstub
    
    // As soon as the web view gains its final resource load delegate,
    // inform that delegate of the tab's site profile:
    //
    // TODO Have the resource load delegate fetch this from the WebView's mainFrame directly.
    //
    @weakify(browsProfile)
//    [[[[RACObserve(pageView, resourceLoadDelegate)
//        startWith:[pageView resourceLoadDelegate]]  // Make sure we get the first one
//       skipUntilBlock:^BOOL(id resourceLoadDelegate) {  return [resourceLoadDelegate respondsToSelector:@selector(setBrowsPersona:)];  }]
//      take:1]  // Make sure it's our custom subclass, and just take that single one
//     subscribeNext:^(EIIGIsolatedCookieWebViewResourceLoadDelegate *resourceLoadDelegate) {  @strongify(browsProfile)
//         [resourceLoadDelegate setBrowsPersona:browsProfile];  // And inform the delegate.
//     }];
    
    
    @weakify(pageView)
    RACSignal *tabClosure = [[self rac_signalForSelector:@selector(tabWillClose)] take:1];
    [tabClosure subscribeNext:^(id x) {
        [@[locationDasu]
         makeObjectsPerformSelector:@selector(sendCompleted)];
    }];
    
    
//    RACSignal *locationEditEnd = [[locationBox rac_signalForSelector:@selector(textDidEndEditing:)
//                                                        fromProtocol:@protocol(NSTextDelegate)]
//                                  takeUntil:tabClosure];
//    RACSignal *locationEditStart = [[locationBox rac_signalForSelector:@selector(textDidBeginEditing:)
//                                                          fromProtocol:@protocol(NSTextDelegate)]
//                                    takeUntil:tabClosure];
//    
//    RACSignal *locationIsBeingEdited = [[RACSignal merge:@[
//                                                [locationEditStart mapReplace:@(YES)]
//                                                ,[locationEditEnd mapReplace:@(NO)]
//                                                ,[locationDasu mapReplace:@(NO)]
//                                                ]]
//                             startWith:@(NO)];
    
    @weakify(tooblarBacking, self)
    // Whenever the page view has some sort of loading change, or the tooblar changes height, make sure we've fixed the content inset.
//    dispatch_async(dispatch_get_main_queue(), ^{
//        // Do this later so that we can refer to the tab selection signal,
//        // after the view has attached to the window hierarchy.
//        
//        [[[[RACSignal merge:@[RACObserve(pageView, loading),
//                              RACObserve(tooblarBacking, frame),
//                              [[[[[[self view] window] windowController] tabListController] tabSelection] filter:^BOOL(BrowsTab *newSelTab) { @strongify(self)  return newSelTab == self;  }]
//                              ]]
//           delay:0.01]
//          takeUntil:tabClosure]
//         subscribeNext:^(id someBooleanOrBullshit) {
//             @strongify(tooblarBacking, pageView)
//             CGFloat tooblarHeight = [tooblarBacking frame].size.height;
//             
//             //if ([pageView ei_topContentInset] != tooblarHeight)
//             [pageView setEi_topContentInset:tooblarHeight];
//             
//             
//             
//         }];
//        
//    });
    
    
//    @weakify(locationBox)
//    [locationDasu subscribeNext:^(id x) {
//        @strongify(locationBox)
//        
//        NSString *request = [locationBox stringValue];
//        NSURL *requestURL = urlForLocation(request, NULL, NULL);
//        // Right now, we don't care whether those were inferred-protocol or search, hence NULLs.
//        
//        if (!requestURL) return;  // Just abort the whole thing. Act like they said nothing.
//        
//        dispatch_async(dispatch_get_main_queue(), ^{  // Postpone until location editing session has fully popped.
//            @strongify(self)
//            [self performStandardRequest:requestURL];
//        });
//        
//    }];
    
    RACSignal *actualPageURL = [RACObserve(pageView, URL)
                                filter:^BOOL(id value) {
                                    return !!value;
                                    
                                }];
    
//    [actualPageURL subscribeNext:^(NSURL *url) {
//        @strongify(locationBox)
//        [locationBox setStringValue:[url absoluteString]];
//    }];
    
    RACSignal *pageURLMatchesPersona = [actualPageURL map:^id(NSURL *url) {
        @strongify(browsProfile)
        NSString *rootHost = [[PublicSuffixList suffixList] publiclyRegistrableDomain:[url host]];
        return @([rootHost isEqualToString:[browsProfile rootHost]]);
    }];
    
//    @weakify(personaIndicator)
//    [[pageURLMatchesPersona map:^id(NSNumber *itMatches) {
//        return [itMatches boolValue] ? [NSColor controlTextColor] : [NSColor colorWithCalibratedRed:233/255.0 green:0 blue:14/255.0 alpha:1];
//    }] subscribeNext:^(NSColor *matchingColor) {
//        @strongify(personaIndicator)
//        [personaIndicator setTextColor:matchingColor];
//    }];
    
    
//    [locationEditEnd subscribeNext:^(id x) {
//        @strongify(locationBox) @strongify(pageView)
//        if ([pageView URL])
//            [locationBox setStringValue:[[pageView URL] absoluteString]];
//    }];
    
    
    
//    @weakify(pageSpinny)
//    
    RACSignal *pageLoadingProgress = [RACObserve(pageView, estimatedProgress) startWith:@(0.0)];
//    [pageLoadingProgress subscribeNext:^(NSNumber *latest) {
//        @strongify(pageSpinny)
//        double latestValue = [latest doubleValue];
//        
//        [pageSpinny setDoubleValue:latestValue];
//        [pageSpinny setIndeterminate:(  latestValue < 0.101 || latestValue >= 1  )];
//        
//        // When the page starts loading, it reports its progress as “0.1,” which is awful to test against.
//        // Presumably it's always less than 0.101. So that's what I'm saying.
//        
//    }];
//    
    RACSignal *pageIsLoading = [RACObserve(pageView, loading) startWith:@NO];
//    [pageIsLoading subscribeNext:^(NSNumber *latest) {
//        @strongify(pageSpinny, pageView)
//        if ([latest boolValue])
//            [pageSpinny startAnimation:pageView];
//        else
//            [pageSpinny stopAnimation:pageView];
//        
//    }];
    
//    @weakify(gotoTheBackwardButton, goFrothButton)
//    [[[RACObserve(pageView, canGoBack) startWith:@(NO)] takeUntil:tabClosure]
//     subscribeNext:^(NSNumber *canI) {
//        @strongify(gotoTheBackwardButton)
//        [gotoTheBackwardButton setEnabled:[canI boolValue]];
//    }];
//    [[[RACObserve(pageView, canGoForward) startWith:@(NO)] takeUntil:tabClosure]
//     subscribeNext:^(NSNumber *canI) {
//        @strongify(goFrothButton)
//        [goFrothButton setEnabled:[canI boolValue]];
//    }];
    
    
//    @weakify(goStopReloadButton)
//    [[[pageIsLoading combineLatestWith:locationIsBeingEdited] map:^(RACTuple *isLoadingIsEditing) {
//        return [NSImage imageNamed:( [[isLoadingIsEditing second] boolValue] ? @"NSMenuOnStateTemplate" :
//                                      [[isLoadingIsEditing first] boolValue] ? @"NSStopProgressTemplate" :
//                                                                               @"NSReloadTemplate" )];
//    }] subscribeNext:^(NSImage *buttonImage) {
//        @strongify(goStopReloadButton)
//        [goStopReloadButton setImage:buttonImage];
//    }];
//    
//    [[pageIsLoading combineLatestWith:locationIsBeingEdited] subscribeNext:^(RACTuple *isLoadingIsEditing) {
//        @strongify(goStopReloadButton)
//        [goStopReloadButton setAction:( [[isLoadingIsEditing second] boolValue] ? @selector(submitLocation:) :
//                                         [[isLoadingIsEditing first] boolValue] ? @selector(stopLoad:) :
//                                                                                  @selector(reLoad:) )];
//    }];
    
    
    
    [/*[*/[pageViewSendEventSignal throttle:3]
      //      merge:[pageLoadingProgress throttle:0.86400]]
     subscribeNext:^(id x) {
         @strongify(self)
         [self _updateThumbnail];
     }];
    
    // TODO figure out how the hell to get the favicon.
    [[RACSignal return:[NSImage imageNamed:@"NSNetwork"]]
     subscribeNext:^(NSImage *favicon) {
         @strongify(self)
         [self setFavicon:favicon];
     }];
    
    
    RACSignal *pageTitle = RACObserve(pageView, title);
    RACSignal *pageIsSecure = RACObserve(pageView, hasOnlySecureContent);
    RACSignal *canBack = RACObserve(pageView, canGoBack);
    RACSignal *canForth = RACObserve(pageView, canGoForward);
    
    
    tabState = [[RACSignal combineLatest:@[ [actualPageURL map:^id(NSURL *url) {  return [url absoluteString];  }]  // 0
                                 , pageIsLoading  // 1
                                 , pageLoadingProgress  // 2
                                 , pageTitle  // 3
                                 , pageIsSecure  // 4
                                 , canBack  // 5
                                 , canForth  // 6
                               ]]
     
     map:^id(RACTuple *pageInfo) {
         return [[BrowsTabState alloc] initWithCanGoBackward:[pageInfo[5] boolValue]
                                                canGoForward:[pageInfo[6] boolValue]
                                                    location:pageInfo[0]
                                                isEditingLoc:NO  // TODO unstub
                                                   isLoading:[pageInfo[1] boolValue]
                                             loadingProgress:[pageInfo[2] doubleValue]
                                                       title:pageInfo[3]
                                                    isSecure:[pageInfo[4] boolValue]];
         
     }];
    
    
    
    
    

}



- (void)pushInitialInterfaceState {
    
//    [personaIndicator setStringValue:[browsProfile name]];
    
    // This will trigger a listener (above) to say 'no no no, that should be x instead!':
    //[pageView _setTopContentInset:0];
    
    // Fragile RACSubjects should be init'd here:
    
    // Set initial location:
    if (initialLocation) {
//        [locationBox setStringValue:[initialLocation absoluteString]];  // Not abs. necessary, but makes for a more responsive feel
        [self performStandardRequest:initialLocation];
    }

}



- (IBAction)submitLocation:(id)sender {
    [locationDasu sendNext:[RACUnit defaultUnit]];
    
}



- (IBAction)gotoTheBackward:(id)sender {
    [pageView goBack:sender];
}

- (IBAction)goFroth:(id)sender {
    [pageView goForward:sender];
}



- (void)stopLoad:(id)sender {
    [pageView stopLoading:sender];
}

- (void)reLoad:(id)sender {
    [pageView reload:sender];
}



- (void)performStandardRequest:(NSURL *)location {
    [pageView loadRequest:[NSURLRequest requestWithURL:location
                                           cachePolicy:NSURLRequestReloadIgnoringLocalCacheData
                                       timeoutInterval:30]];
}




#pragma mark - Properties

- (BrowsPersona *)browsProfile {
    return browsProfile;
}

- (RACSignal *)tabState {
    return tabState;
}

- (NSImage *)favicon {
    return latestFavicon ? latestFavicon : [NSImage imageNamed:@"NSNetwork"];
}

- (void)setFavicon:(NSImage *)favicon {
    latestFavicon = favicon;
}

- (void)_updateThumbnail {
    
    if (!pageView) {
        [self setThumbnail:[NSImage imageNamed:@"NSNetwork"]];
        return;
    }
    
    NSRect pageViewVisibleRect = [pageView visibleRect];
    if (pageViewVisibleRect.size.width == 0 || pageViewVisibleRect.size.height == 0) {
        pageViewVisibleRect = [pageView frame];
    }
    
    //
    // Scale the image into a maximum box of 512x512.
    // First find the sizes:
    CGFloat maxDimension = 512;
    CGFloat largerWidth = pageViewVisibleRect.size.width;
    CGFloat largerHeight = pageViewVisibleRect.size.height;
    CGFloat scalingFactor = MIN( maxDimension / largerWidth,  maxDimension / largerHeight );
    
    CGFloat smallerWidth = (CGFloat)( (NSInteger)(largerWidth * scalingFactor) );  // Truncate to avoid 1px of extra white
    CGFloat smallerHeight = (CGFloat)( (NSInteger)(largerHeight * scalingFactor) );
    
    // Establish the drawing context
    CGColorSpaceRef sRGB = CGColorSpaceCreateWithName(kCGColorSpaceSRGB);
    CGContextRef thumbContext = CGBitmapContextCreate(NULL,
                                                      smallerWidth, smallerHeight,
                                                      8 /* bits per component */,
                                                      4 * smallerWidth /* bytes per row */,
                                                      sRGB,
                                                      (CGBitmapInfo)kCGImageAlphaPremultipliedLast);
    CGColorSpaceRelease(sRGB);
    
    // Scale the context...
    CGContextSetInterpolationQuality(thumbContext, kCGInterpolationMedium);
    CGContextScaleCTM(thumbContext, scalingFactor, scalingFactor);
    
    // ...so that drawing the webview will scale down natively:
    [[pageView layer] renderInContext:thumbContext];
    
    // Frame the drawing and so on
    CGImageRef nail = CGBitmapContextCreateImage(thumbContext);
    NSImage *thumb = [[NSImage alloc] initWithCGImage:nail size:NSMakeSize(smallerWidth, smallerHeight)];
    
    CFRelease(nail);  CFRelease(thumbContext);
    
    [self setThumbnail:thumb];
    
}

- (NSImage *)thumbnail {
    return latestThumbnail;
}

- (void)setThumbnail:(NSImage *)thumbnail {
    // RAC observers of our thumbnail should be able to see these updates.
    latestThumbnail = thumbnail;
}

- (WKWebView *)pageView {
    return pageView;
}








#pragma mark -
#pragma mark UI Delegate


- (nullable WKWebView *)webView:(WKWebView *)webView
 createWebViewWithConfiguration:(WKWebViewConfiguration *)configuration
            forNavigationAction:(WKNavigationAction *)navigationAction
                 windowFeatures:(WKWindowFeatures *)windowFeatures {
    
    BrowsWindow *parentWindow = [[[self view] window] windowController];
    BrowsTabList *tabsListController = [parentWindow tabListController];
    NSUInteger ourPresentIndex = [tabsListController indexOfTab:self];
    
    BrowsTab *newTab = [[BrowsTab alloc] initWithProfile:browsProfile
                                         webViewConfiguration:configuration];
    
    [tabsListController putTab:newTab atIndex:ourPresentIndex];
    [tabsListController selectTabsAtIndices:[NSIndexSet indexSetWithIndex:ourPresentIndex]];
    
    
    return [newTab pageView];
    
}



- (void)webView:(WKWebView *)webView runJavaScriptAlertPanelWithMessage:(NSString *)message initiatedByFrame:(WKFrameInfo *)frame completionHandler:(void (^)(void))completionHandler {
    
    [self _dismissPriorAlertHandler];
    
    // TODO LOCALIZE THIS!!!
    [jsAlertHeader setStringValue:[NSString stringWithFormat:@"The page at %@ says:", [[[frame request] URL] host]]];
    [jsAlertMessage setStringValue:(message ? message : @"")];
    [jsAlertCancelButton setHidden:YES];
    
    [[self view] addSubview:jsAlertPane positioned:NSWindowAbove relativeTo:pageView];
    [self _bindPaneToTab:jsAlertPane];
    
    @weakify(jsAlertPane)
    jsFinishOverlay = [^(BOOL wasAffirmative){
        @strongify(jsAlertPane)
        completionHandler();
        [jsAlertPane removeFromSuperview];
        
    } copy];
    
}



- (void)webView:(WKWebView *)webView runJavaScriptConfirmPanelWithMessage:(NSString *)message initiatedByFrame:(WKFrameInfo *)frame completionHandler:(void (^)(BOOL))completionHandler {
    
    [self _dismissPriorAlertHandler];
    
    // TODO LOCALIZE THIS!!!
    [jsAlertHeader setStringValue:[NSString stringWithFormat:@"The page at %@ asks:", [[[frame request] URL] host]]];
    [jsAlertMessage setStringValue:(message ? message : @"")];
    [jsAlertCancelButton setHidden:NO];
    
    [[self view] addSubview:jsAlertPane positioned:NSWindowAbove relativeTo:pageView];
    [self _bindPaneToTab:jsAlertPane];
    
    @weakify(jsAlertPane)
    jsFinishOverlay = [^(BOOL wasAffirmative){
        @strongify(jsAlertPane)
        completionHandler(wasAffirmative);
        [jsAlertPane removeFromSuperview];
        
    } copy];
    
}



- (void)webView:(WKWebView *)webView runJavaScriptTextInputPanelWithPrompt:(NSString *)prompt defaultText:(NSString *)defaultText initiatedByFrame:(WKFrameInfo *)frame completionHandler:(void (^)(NSString *))completionHandler {
    
    [self _dismissPriorAlertHandler];
    
    // TODO LOCALIZE THIS!!!
    [jsQueryHeader setStringValue:[NSString stringWithFormat:@"The page at %@ asks:", [[[frame request] URL] host]]];
    [jsQueryMessage setStringValue:(prompt ? prompt : @"")];
    [jsQueryResponseField setStringValue:(defaultText ? defaultText : @"")];
    
    [[self view] addSubview:jsQueryPane positioned:NSWindowAbove relativeTo:pageView];
    [self _bindPaneToTab:jsQueryPane];
    
    @weakify(jsQueryPane, jsQueryResponseField)
    jsFinishOverlay = [^(BOOL wasAffirmative){
        @strongify(jsQueryPane, jsQueryResponseField)
        completionHandler(wasAffirmative ? [jsQueryResponseField stringValue] : nil);
        
        [jsQueryPane removeFromSuperview];
        
    } copy];
    
}



- (IBAction)finishJSAlertPanelAffirmatively:(id)sender {
    if (!jsFinishOverlay)
        return;
    
    jsFinishOverlay(YES);
    jsFinishOverlay = nil;
    
}

- (IBAction)finishJSAlertPanelNegatively:(id)sender {
    if (!jsFinishOverlay)
        return;
    
    jsFinishOverlay(NO);
    jsFinishOverlay = nil;
    
}



- (void)_dismissPriorAlertHandler {
    [self finishJSAlertPanelNegatively:nil];
}

- (void)_bindPaneToTab:(NSView *)bindPane {
    NSDictionary *applicableParties = NSDictionaryOfVariableBindings(bindPane);
    [NSLayoutConstraint activateConstraints:
     [[NSLayoutConstraint constraintsWithVisualFormat:@"H:|[bindPane]|"
                                              options:0
                                              metrics:nil
                                                views:applicableParties]
      arrayByAddingObjectsFromArray:
      [NSLayoutConstraint constraintsWithVisualFormat:@"V:|[bindPane]|"
                                              options:0
                                              metrics:nil
                                                views:applicableParties]]];
}








#pragma mark -
#pragma mark Frame Load Delegate


// TODO implementate this shit


//- (void)webView:(WebView *)sender didStartProvisionalLoadForFrame:(WebFrame *)frame {
//    if (frame != [pageView mainFrame]) return;
//    
//    [pageIsLoading sendNext:@(YES)];
//    [pageLoadingProgress sendNext:@(-1)];  // Spin
//    
//}
//
//
//- (void)webView:(WebView *)sender didCommitLoadForFrame:(WebFrame *)frame {
//    if (frame != [pageView mainFrame]) return;
//    
//    [pageLoadingProgress sendNext:@(0)];
//    [self _commitLocationToHistory];  // Record in history as soon as we put a foot down.
//    
//}
//
//
//- (void)webView:(WebView *)sender didFinishLoadForFrame:(WebFrame *)frame {
//    if (frame != [pageView mainFrame]) return;
//    
//    [pageLoadingProgress sendNext:@(1)];
//    [pageIsLoading sendNext:@(NO)];
//    [self _commitLocationToHistory];  // Make sure we get the final URL and title.
//    
//}
//
//- (void)webView:(WebView *)sender didFailProvisionalLoadWithError:(NSError *)error forFrame:(WebFrame *)frame {
//    if (frame != [pageView mainFrame]) return;
//    
//    [pageIsLoading sendNext:@(NO)];
//    // TODO Display error if necessary
//    
//}
//
//- (void)webView:(WebView *)sender didFailLoadWithError:(NSError *)error forFrame:(WebFrame *)frame {
//    if (frame != [pageView mainFrame]) return;
//    
//    [pageIsLoading sendNext:@(NO)];
//    // TODO Display error if necessary
//    
//    // Record the load that failed.
//    // If we're at a page that can't be reached at all, the extra history item won't harm anyone.
//    // If the page stalled out, we still want to record it in history.
//    // If the page was still loading and we navigated through it (e.g. clicking a google search result)
//    // then we want to make sure we recorded the title of the page that was loading, if it was available.
//    // The title won't be available on commit-load, and is normally recorded on finish-load.
//    [self _commitLocationToHistory];
//    
//}

- (void)_commitLocationToHistory {
    WKBackForwardListItem *pageLocation = [[pageView backForwardList] currentItem];
    if (pageLocation)
        [browsProfile putHistoryItem:pageLocation];
    
}

- (void)updateProgress:(NSNotification *)note {
    
}







@end
