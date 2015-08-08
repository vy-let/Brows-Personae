//
//  EISimpleProgressIndicator.m
//  Brows Personæ
//
//  Created by Violet Baddley on 2015-8-7.
//  Copyright © 2015 Eightt. All rights reserved.
//

#import "EISimpleProgressIndicator.h"

@implementation EISimpleProgressIndicator {
    CGFloat _proportion;
    CGFloat _opacity;
}

- (void)drawRect:(NSRect)dirtyRect {
    [super drawRect:dirtyRect];
    
    NSRect myBounds = [self bounds];
    CGFloat myWidth = myBounds.size.width;
    CGFloat effectiveWidth = _proportion * myWidth;
    
    NSRect drawBounds = myBounds;
    drawBounds.size.width = effectiveWidth;
    
    [[[NSColor alternateSelectedControlColor] colorWithAlphaComponent:_opacity] set];
    NSRectFill(drawBounds);
    
}

- (CGFloat)proportion { return _proportion; }
- (void)setProportion:(CGFloat)prop {
    if (prop < 0)       prop = 0;
    else if (prop > 1)  prop = 1;
    
    _proportion = prop;
    [self setNeedsDisplay:YES];
    
}

- (CGFloat)opacity { return _opacity; }
- (void)setOpacity:(CGFloat)opaq {
    if (opaq < 0)       opaq = 0;
    else if (opaq > 1)  opaq = 1;
    
    _opacity = opaq;
    [self setNeedsDisplay:YES];
    
}

@end
