//
//  BrowsTab.m
//  Brows Personæ
//
//  Created by Taldar Baddley on 2014-10-12.
//  Copyright (c) 2014 Eightt. All rights reserved.
//

#import <WebKit/WebKit.h>
#import <ReactiveCocoa/ReactiveCocoa.h>

#import "BrowsTab.h"
#import "SiteProfile.h"
#import "IGIsolatedCookieWebView.h"
#import "WebView+ScrollViewAccess.h"
#import "Helpies.h"


@interface BrowsTab () {
    NSObject *tabViewButtonThing;
    SiteProfile *browsProfile;
    RACSubject *locationDasu;  // Into which submit events are pushed.
    RACSubject *pageIsLoading;
    RACSubject *pageLoadingProgress;
    
    NSURL *initialLocation;
    
}

@end



@implementation BrowsTab

- (instancetype)initWithProfile:(SiteProfile *)profile initialLocation:(NSURL *)urlOrSearch {
    if (!(self = [super initWithNibName:@"BrowsTab" bundle:nil])) return nil;
    
    browsProfile = profile;
    locationDasu = [RACSubject subject];
    pageIsLoading = [RACSubject subject];
    pageLoadingProgress = [RACSubject subject];
    
    initialLocation = urlOrSearch;
    
    return self;
    
}

- (instancetype)initWithProfileNamed:(NSString *)profileName initialLocation:(NSURL *)urlOrSearch {
    return [self initWithProfile:[SiteProfile named:profileName] initialLocation:urlOrSearch];
}

- (id)init {
    NSAssert(false, @"Cannot raw-init a BrowsTab!");
    return nil;
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    NSLog(@"Brows Tab for %@ at %@ is being deallocated.", [browsProfile name], [pageView mainFrameURL]);
}


- (void)awakeFromNib {
    [super awakeFromNib];
    [tooblar setBlendingMode:NSVisualEffectBlendingModeWithinWindow];
    [tooblar setMaterial:NSVisualEffectMaterialTitlebar];
    
    [pageView setCustomUserAgent:@"Mozilla/5.0 (Macintosh; Intel Mac OS X 10_10_2) AppleWebKit/600.3.18 (KHTML, like Gecko) Version/8.0.3 Safari/600.3.18"];
    
    [self setUpRACListeners];
    [self pushInitialInterfaceState];  // Must happen *after* RAC is already listening, in some cases.
    
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(updateProgress:)
                                                 name:WebViewProgressEstimateChangedNotification
                                               object:pageView];
    
}



- (void)tabWillClose { }



- (void)setUpRACListeners {
    RACSignal *tabClosure = [[self rac_signalForSelector:@selector(tabWillClose)] take:1];
    [tabClosure subscribeNext:^(id x) {
        [@[locationDasu, pageIsLoading, pageLoadingProgress]
         makeObjectsPerformSelector:@selector(sendCompleted)];
    }];
    
    
    RACSignal *locationEditEnd = [[locationBox rac_signalForSelector:@selector(textDidEndEditing:)
                                             fromProtocol:@protocol(NSTextDelegate)]
                       takeUntil:tabClosure];
    RACSignal *locationEditStart = [[locationBox rac_signalForSelector:@selector(textDidBeginEditing:)
                                                          fromProtocol:@protocol(NSTextDelegate)]
                                    takeUntil:tabClosure];
    
    [pageIsLoading sendNext:@(NO)];
    RACSignal *locationIsBeingEdited = [[RACSignal merge:@[
                                                [locationEditStart mapReplace:@(YES)]
                                                ,[locationEditEnd mapReplace:@(NO)]
                                                ,[locationDasu mapReplace:@(NO)]
                                                ]]
                             startWith:@(NO)];
    
    @weakify(tooblar) @weakify(pageView)
    [[RACObserve([pageView ei_scrollView], contentInsets) takeUntil:tabClosure]
     subscribeNext:^(NSValue *edgeInsets) {
        @strongify(tooblar)
        NSEdgeInsets contentInsets;  [edgeInsets getValue:&contentInsets];
        CGFloat tooblarHeight = [tooblar frame].size.height;
        
        if (contentInsets.top != tooblarHeight) {
            [[pageView ei_scrollView] setContentInsets:NSEdgeInsetsMake(tooblarHeight, 0, 0, 0)];
            
        }
        
    }];
    
#pragma mark User Submits Page Location
    
    @weakify(locationBox) @weakify(self)
    [locationDasu subscribeNext:^(id x) {
        @strongify(locationBox)
        
        NSString *request = [locationBox stringValue];
        NSURL *requestURL = urlForLocation(request, NULL, NULL);
        // Right now, we don't care whether those were inferred-protocol or search, hence NULLs.
        
        if (!requestURL) return;  // Just abort the whole thing. Act like they said nothing.
        
        dispatch_async(dispatch_get_main_queue(), ^{  // Postpone until location editing session has fully popped.
            @strongify(self)
            NSLog(@"Loading “%@”", requestURL);
            [self performStandardRequest:requestURL];
        });
        
    }];
    
    
    
    [locationEditEnd subscribeNext:^(id x) {
        @strongify(locationBox) @strongify(pageView)
        if ([pageView mainFrameURL])
            [locationBox setStringValue:[pageView mainFrameURL]];
    }];
    
    
    
    // DEBUG-ONLY COLOR CHANGES
    [locationIsBeingEdited subscribeNext:^(NSNumber *x) {
        @strongify(locationBox)
        [locationBox setBackgroundColor:([x boolValue] ?
                                         [NSColor colorWithCalibratedRed:1 green:0.95 blue:0.95 alpha:1] :
                                         [NSColor colorWithCalibratedRed:0.95 green:0.95 blue:1 alpha:1]
                                         )];
        
    }];
    
    
    @weakify(pageSpinny)
    [pageLoadingProgress subscribeNext:^(NSNumber *prague) {
        @strongify(pageSpinny)
        [[pageSpinny animator] setDoubleValue:[prague doubleValue]];
    }];
    
    [[pageIsLoading combineLatestWith:pageLoadingProgress] subscribeNext:^(RACTuple *latest) {
        @strongify(pageSpinny)
        double progress = [[latest second] doubleValue];
        BOOL isLoading = [[latest first] boolValue];
        
        if (!isLoading) {
            [pageSpinny setIndeterminate:YES];  [pageSpinny stopAnimation:nil];
            
        } else if (progress < 0 || progress > 1) {
            [pageSpinny setIndeterminate:YES];  [pageSpinny startAnimation:nil];
            
        } else {
            [pageSpinny setIndeterminate:NO];  [pageSpinny startAnimation:nil];
            
        }
        
    }];
    
    @weakify(gotoTheBackwardButton, goFrothButton)
    [[[RACObserve(pageView, canGoBack) startWith:@(NO)] takeUntil:tabClosure]
     subscribeNext:^(NSNumber *canI) {
        @strongify(gotoTheBackwardButton)
        [gotoTheBackwardButton setEnabled:[canI boolValue]];
    }];
    [[[RACObserve(pageView, canGoForward) startWith:@(NO)] takeUntil:tabClosure]
     subscribeNext:^(NSNumber *canI) {
        @strongify(goFrothButton)
        [goFrothButton setEnabled:[canI boolValue]];
    }];
    
    
    [pageIsLoading subscribeNext:^(id x) {
        NSLog(@"Is page loading? %@", x);
    }];
    [locationIsBeingEdited subscribeNext:^(id x) {
        NSLog(@"Is location being edited? %@", x);
    }];
    @weakify(goStopReloadButton)
    [[[pageIsLoading combineLatestWith:locationIsBeingEdited] map:^(RACTuple *isLoadingIsEditing) {
        return [NSImage imageNamed:( [[isLoadingIsEditing second] boolValue] ? @"NSMenuOnStateTemplate" :
                                      [[isLoadingIsEditing first] boolValue] ? @"NSStopProgressTemplate" :
                                                                               @"NSReloadTemplate" )];
    }] subscribeNext:^(NSImage *buttonImage) {
        @strongify(goStopReloadButton)
        [goStopReloadButton setImage:buttonImage];
    }];
    
    [[pageIsLoading combineLatestWith:locationIsBeingEdited] subscribeNext:^(RACTuple *isLoadingIsEditing) {
        @strongify(goStopReloadButton)
        [goStopReloadButton setAction:( [[isLoadingIsEditing second] boolValue] ? @selector(submitLocation:) :
                                         [[isLoadingIsEditing first] boolValue] ? @selector(stopLoad:) :
                                                                                  @selector(reLoad:) )];
    }];
    

}



- (void)pushInitialInterfaceState {
    
    [personaIndicator setStringValue:[browsProfile name]];
    
    // This will trigger a listener (above) to say 'no no no, that should be x instead!':
    [[pageView ei_scrollView] setContentInsets:NSEdgeInsetsMake(0, 0, 0, 0)];
    
    // Fragile RACSubjects should be init'd here:
    [pageIsLoading sendNext:@(0)];
    [pageLoadingProgress sendNext:@(-1)];
    
    // Set initial location:
    if (initialLocation) {
        [locationBox setStringValue:[initialLocation absoluteString]];  // Not abs. necessary, but makes for a more responsive feel
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
    [[pageView mainFrame] loadRequest:[NSURLRequest requestWithURL:location
                                                       cachePolicy:NSURLRequestReloadIgnoringLocalCacheData
                                                   timeoutInterval:30]];
}




#pragma mark - Properties

- (NSImage *)favicon {
    return [NSImage imageNamed:@"NSMobileMe"];
}

- (NSImage *)thumbnail {
    return [NSImage imageNamed:@"NSMultipleDocuments"];
}








#pragma mark -
#pragma mark Frame Load Delegate


- (void)webView:(WebView *)sender didStartProvisionalLoadForFrame:(WebFrame *)frame {
    if (frame != [pageView mainFrame]) return;
    
    NSString *pageLoc = [[[[frame provisionalDataSource] request] URL] absoluteString];
    if (pageLoc) [locationBox setStringValue:pageLoc];
    
    NSLog(@"Provisionally load with content inset top %f", [[pageView ei_scrollView] contentInsets].top);
    
    [pageIsLoading sendNext:@(YES)];
    [pageLoadingProgress sendNext:@(-1)];  // Spin
    
}


- (void)webView:(WebView *)sender didCommitLoadForFrame:(WebFrame *)frame {
    if (frame != [pageView mainFrame]) return;
    
    NSLog(@"Commit load with content inset top %f", [[pageView ei_scrollView] contentInsets].top);
    
    [pageLoadingProgress sendNext:@(0)];
    
}


- (void)webView:(WebView *)sender didFinishLoadForFrame:(WebFrame *)frame {
    if (frame != [pageView mainFrame]) return;
    
    [pageLoadingProgress sendNext:@(1)];
    [pageIsLoading sendNext:@(NO)];
    
    NSLog(@"Finish load %@ with content inset top %f", [pageView ei_scrollView], [[pageView ei_scrollView] contentInsets].top);
    
}

- (void)webView:(WebView *)sender didFailProvisionalLoadWithError:(NSError *)error forFrame:(WebFrame *)frame {
    if (frame != [pageView mainFrame]) return;
    
    [pageIsLoading sendNext:@(NO)];
    NSBeep();
    NSLog(@"Did fail provisional load with error: %@", error);
    
}

- (void)webView:(WebView *)sender didFailLoadWithError:(NSError *)error forFrame:(WebFrame *)frame {
    if (frame != [pageView mainFrame]) return;
    
    [pageIsLoading sendNext:@(NO)];
    NSBeep();
    NSLog(@"Did fail load with error: %@", error);
    
}

- (void)updateProgress:(NSNotification *)note {
    [pageLoadingProgress sendNext:@([pageView estimatedProgress])];
}







@end
