//
//  SiteProfile.m
//  Brows Personæ
//
//  Created by Taldar Baddley on 2014-10-12.
//  Copyright (c) 2014 Eightt. All rights reserved.
//

#import "SiteProfile.h"

@interface SiteProfile () {
    NSString *name;
}

@end

@implementation SiteProfile


static dispatch_queue_t profileSanity;


+ (void)initialize {
    profileSanity = dispatch_queue_create("SiteProfileSanityQueue", DISPATCH_QUEUE_SERIAL);
}


+ (instancetype)named:(NSString *)profileName {
    __block id result;
    
    dispatch_sync(profileSanity, ^{
        result = nil;
    });
    
    return result;
}

@end
