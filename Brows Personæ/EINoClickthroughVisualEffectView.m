//
//  EINoClickthroughVisualEffectView.m
//  Brows Personæ
//
//  Created by Talus Baddley on 2015-6-25.
//  Copyright (c) 2015 Eightt. All rights reserved.
//

#import "EINoClickthroughVisualEffectView.h"

@implementation EINoClickthroughVisualEffectView

- (void)mouseDown:(NSEvent *)theEvent {
    // Yep. Nope. Don't do a damn thing.
}

- (BOOL)allowsVibrancy { return YES; }

@end
