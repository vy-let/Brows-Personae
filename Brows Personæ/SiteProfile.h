//
//  SiteProfile.h
//  Brows Personæ
//
//  Created by Taldar Baddley on 2014-10-12.
//  Copyright (c) 2014 Eightt. All rights reserved.
//

#import <Foundation/Foundation.h>


const NSUInteger SiteProfileStorePresentVersion;
const NSUInteger SiteProfileStoreApplicationID;


@interface SiteProfile : NSObject

+ (instancetype)named:(NSString *)profileName;
+ (NSURL *)mainProfileFolder;

@property (readonly) NSString *name;

@end
