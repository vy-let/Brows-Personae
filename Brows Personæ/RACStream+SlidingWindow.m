//
//  RACStream+SlidingWindow.m
//  Brows Personæ
//
//  Created by Talus Baddley on 2015-2-25.
//  Copyright (c) 2015 Eightt. All rights reserved.
//

#import "RACStream+SlidingWindow.h"

@implementation RACStream (SlidingWindow)

- (instancetype)slidingWindowSized:(NSUInteger)size {
    return [self slidingWindowSized:size minimumCount:0];
}

- (instancetype)slidingWindowSized:(NSUInteger)size minimumCount:(NSUInteger)minCount {
    return [[self
             scanWithStart:@[] reduce:^id(NSArray *running, id next) {
                 NSRange sliceRange = ([running count] >= size ?
                                       NSMakeRange(1, size) :
                                       NSMakeRange(0, [running count] + 1)
                                       );
                 
                 return [[running arrayByAddingObject:next] subarrayWithRange:sliceRange];
                 
             }]
            filter:^BOOL(NSArray *window) {
                return [window count] >= minCount;
            }];
}

- (instancetype)nilPaddedSlidingWindowSized:(NSUInteger)size {
    return [self nilPaddedSlidingWindowSized:size minimumCount:0];
}

- (instancetype)nilPaddedSlidingWindowSized:(NSUInteger)size minimumCount:(NSUInteger)minCount {
    return [[self slidingWindowSized:size minimumCount:minCount]
            map:^id(NSArray *flexWindow) {
                
                NSInteger sizeDiff = size - [flexWindow count];
                NSMutableArray *buf = [NSMutableArray arrayWithCapacity:size];
                for (NSUInteger fuckingManualIteration = 0; fuckingManualIteration < sizeDiff; fuckingManualIteration++) {
                    [buf addObject:[RACTupleNil tupleNil]];
                }
                // Or, as you'd say in Ruby, Array.new(sizeDiff, nil)
                
                [buf addObjectsFromArray:flexWindow];
                return [RACTuple tupleWithObjectsFromArray:buf];
                
            }];
}

@end
