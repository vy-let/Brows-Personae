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
#import "Helpies.h"

@interface BrowsTab () {
    NSObject *tabViewButtonThing;
    SiteProfile *browsProfile;
    RACSignal *locationIsBeingEdited;
    RACSubject *locationDasu;  // Into which submit events are pushed.
}

@end



@implementation BrowsTab

- (instancetype)initWithProfile:(SiteProfile *)profile {
    if (!(self = [super initWithNibName:@"BrowsTab" bundle:nil])) return nil;
    
    browsProfile = profile;
    locationDasu = [RACSubject subject];
    
    return self;
    
}

- (instancetype)initWithProfileNamed:(NSString *)profileName {
    return [self initWithProfile:[SiteProfile named:profileName]];
}

- (id)init {
    NSAssert(false, @"Cannot raw-init a BrowsTab!");
    return nil;
}


- (void)awakeFromNib {
    [super awakeFromNib];
    [tooblar setBlendingMode:NSVisualEffectBlendingModeWithinWindow];
    [tooblar setMaterial:NSVisualEffectMaterialTitlebar];
    
    locationIsBeingEdited = [RACSignal merge:@[
                                               [[locationBox rac_signalForSelector:@selector(textDidBeginEditing:)
                                                                      fromProtocol:@protocol(NSTextDelegate)]      mapReplace:@(YES)],
                                               [[locationDasu startWith:[RACUnit defaultUnit]]                     mapReplace:@(NO)]
                                               ]];
    
    @weakify(locationBox) @weakify(pageView)
    [locationDasu subscribeNext:^(id x) {
        @strongify(locationBox)
        NSString *request = [locationBox stringValue];
        NSURL *requestURL = isProbablyURLWithScheme(request) ? [NSURL URLWithString:request] :
                                 isProbablyNakedURL(request) ? [NSURL URLWithString:[@"http://" stringByAppendingString:request]] :
                                                               nil;
        // Either it's not a URL-looking thing, or it's not actually parseable as a URL (URLWithString: returning nil).
        // In both cases, take it to be a search.
        if (!requestURL)
            requestURL = searchEngineURLForQuery(request);
        
        dispatch_async(dispatch_get_main_queue(), ^{  // Postpone until location editing session has fully popped.
            @strongify(pageView)
            NSLog(@"Loading “%@”", requestURL);
            [[pageView mainFrame] loadRequest:[NSURLRequest requestWithURL:requestURL
                                                               cachePolicy:NSURLRequestReloadIgnoringLocalCacheData
                                                           timeoutInterval:30]];
        });
        
    }];
    
    
    
    // DEBUG-ONLY COLOR CHANGES
    [locationIsBeingEdited subscribeNext:^(NSNumber *x) {
        @strongify(locationBox)
        [locationBox setBackgroundColor:([x boolValue] ?
                                         [NSColor colorWithCalibratedRed:1 green:0.95 blue:0.95 alpha:1] :
                                         [NSColor colorWithCalibratedRed:0.95 green:0.95 blue:1 alpha:1]
         )];
        
    }];
    
}



- (IBAction)submitLocation:(id)sender {
    [locationDasu sendNext:[RACUnit defaultUnit]];
    
}



- (NSImage *)favicon {
    return [NSImage imageNamed:@"NSMobileMe"];
}

- (NSImage *)thumbnail {
    return [NSImage imageNamed:@"NSMultipleDocuments"];
}



@end
