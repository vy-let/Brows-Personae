//
//  PublicSuffixList.h
//  Brows Personæ
//
//  Created by Talus Baddley on 2015-2-27.
//  Copyright (c) 2015 Eightt. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface PublicSuffixList : NSObject

+ (instancetype)suffixList;

//
// Split a domain name into its @[private, public] parts.
// The intervening dot is omitted.
- (NSArray *)split:(NSString *)domain;

- (NSArray *)domainLabels:(NSString *)domain;

@end
