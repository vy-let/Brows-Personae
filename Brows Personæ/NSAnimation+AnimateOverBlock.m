//
//  NSAnimation+AnimateOverBlock.m
//  Brows Personæ
//
//  Created by Talus Baddley on 2015-8-7.
//  Copyright © 2015 Eightt. All rights reserved.
//

#import "NSAnimation+AnimateOverBlock.h"



@interface EIBlockAnimation : NSAnimation

- (instancetype)initWithDuration:(NSTimeInterval)duration animationCurve:(NSAnimationCurve)animationCurve block:(EIAnimationFrameHandler)frameHandler;

@end

@implementation EIBlockAnimation {
    EIAnimationFrameHandler _frameHandler;
}

- (instancetype)initWithDuration:(NSTimeInterval)duration animationCurve:(NSAnimationCurve)animationCurve block:(EIAnimationFrameHandler)frameHandler {
    if (!(self = [super initWithDuration:duration animationCurve:animationCurve]))
        return nil;
    
    _frameHandler = [frameHandler copy];
    
    return self;
}

- (void)setCurrentProgress:(NSAnimationProgress)currentProgress {
    [super setCurrentProgress:currentProgress];
    
    if (_frameHandler)
        _frameHandler(currentProgress);
    
}

@end



@implementation NSAnimation (AnimateOverBlock)

+ (NSAnimation *)ei_animationWithDuration:(NSTimeInterval)duration animationCurve:(NSAnimationCurve)curve overBlock:(EIAnimationFrameHandler)frameHandler {
    return [[EIBlockAnimation alloc] initWithDuration:duration animationCurve:curve block:frameHandler];
}

@end
