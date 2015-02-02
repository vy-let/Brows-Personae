//
//  BrowsTab.m
//  Brows Personæ
//
//  Created by Taldar Baddley on 2014-10-12.
//  Copyright (c) 2014 Eightt. All rights reserved.
//

#import "BrowsTab.h"
#import "SiteProfile.h"

#import <WebKit/WebKit.h>

@interface BrowsTab () {
    NSObject *tabViewButtonThing;
    WebView *webView;
    SiteProfile *browsProfile;
}

@end



@implementation BrowsTab

- (instancetype)initWithProfile:(SiteProfile *)profile {
    if (!(self = [super initWithNibName:@"BrowsTab" bundle:nil])) return nil;
    
    browsProfile = profile;
    
    return self;
    
}

- (instancetype)initWithProfileNamed:(NSString *)profileName {
    return [self initWithProfile:[SiteProfile named:profileName]];
}

- (id)init {
    NSAssert(false, @"Cannot raw-init a BrowsTab!");
    return nil;
}



- (NSImage *)favicon {
    return [NSImage imageNamed:@"NSMobileMe"];
}

- (NSImage *)thumbnail {
    return [NSImage imageNamed:@"NSMultipleDocuments"];
}



@end
