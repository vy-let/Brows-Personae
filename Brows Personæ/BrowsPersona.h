//
//  SiteProfile.h
//  Brows Personæ
//
//  Created by Taldar Baddley on 2014-10-12.
//  Copyright (c) 2014 Eightt. All rights reserved.
//

#import <Foundation/Foundation.h>


const UInt32 SiteProfileStorePresentVersion;
const UInt32 SiteProfileStoreApplicationID;


@interface BrowsPersona : NSObject

+ (instancetype)named:(NSString *)profileName;
+ (NSURL *)mainProfileFolder;

@property (readonly) NSString *name;


#pragma mark Cookie Data Source

- (NSArray *)cookies;
- (void)removeAllCookies;
- (void)removeAllCookiesForHost:(NSString *)host;
- (void)removeExpiredCookies;
- (void)setCookie:(NSHTTPCookie *)cookie;
- (NSArray *)cookiesForRequest:(NSURLRequest *)request;

@end
