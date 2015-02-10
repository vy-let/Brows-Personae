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
    @weakify(locationBox)
    [locationIsBeingEdited subscribeNext:^(NSNumber *x) {
        @strongify(locationBox);
        [locationBox setBackgroundColor:([x boolValue] ?
                                         [NSColor colorWithCalibratedRed:1 green:0.9 blue:0.9 alpha:1] :
                                         [NSColor colorWithCalibratedRed:0.9 green:0.9 blue:1 alpha:1]
         )];
        
    }];
    
    
    
}



- (IBAction)submitLocation:(id)sender {
    [locationDasu sendNext:[RACUnit defaultUnit]];
    
    NSString *request = [sender stringValue];
    NSURL *potentialURL = [NSURL URLWithString:request];
    NSLog(@"\n abso %@\n base %@\n host %@\n rpth %@\n rstr %@\n schm %@\n strd %@",
          [potentialURL absoluteString],
          [potentialURL baseURL],
          [potentialURL host],
          [potentialURL relativePath],
          [potentialURL relativeString],
          [potentialURL scheme],
          [potentialURL standardizedURL]);
    
    if (potentialURL && ![potentialURL scheme]) {
        potentialURL = [NSURL URLWithString:[@"https://" stringByAppendingString:[potentialURL absoluteString]]];
    }
    
    if ([potentialURL scheme] && [potentialURL host])
        [[pageView mainFrame] loadRequest:[NSURLRequest requestWithURL:potentialURL
                                                           cachePolicy:NSURLRequestReloadIgnoringLocalCacheData
                                                       timeoutInterval:30.0]];
    
}



- (NSImage *)favicon {
    return [NSImage imageNamed:@"NSMobileMe"];
}

- (NSImage *)thumbnail {
    return [NSImage imageNamed:@"NSMultipleDocuments"];
}



@end
