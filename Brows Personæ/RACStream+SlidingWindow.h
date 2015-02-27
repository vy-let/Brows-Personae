//
//  RACStream+SlidingWindow.h
//  Brows Personæ
//
//  Created by Talus Baddley on 2015-2-25.
//  Copyright (c) 2015 Eightt. All rights reserved.
//

#import <ReactiveCocoa/ReactiveCocoa.h>

@interface RACStream (SlidingWindow)

- (instancetype)slidingWindowSized:(NSUInteger)size;
- (instancetype)slidingWindowSized:(NSUInteger)size minimumCount:(NSUInteger)minCount;
- (instancetype)nilPaddedSlidingWindowSized:(NSUInteger)size;
- (instancetype)nilPaddedSlidingWindowSized:(NSUInteger)size minimumCount:(NSUInteger)minCount;

@end
