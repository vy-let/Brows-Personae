//
//  NSAnimation+AnimateOverBlock.h
//  Brows Personæ
//
//  Created by Talus Baddley on 2015-8-7.
//  Copyright © 2015 Eightt. All rights reserved.
//

#import <Cocoa/Cocoa.h>

typedef void (^EIAnimationFrameHandler)(NSAnimationProgress progress);

@interface NSAnimation (AnimateOverBlock)

+ (NSAnimation *)ei_animationWithDuration:(NSTimeInterval)duration
                           animationCurve:(NSAnimationCurve)curve
                                overBlock:(EIAnimationFrameHandler)frameHandler;

@end
