//
//  EISimpleProgressIndicator.h
//  Brows Personæ
//
//  Created by Violet Baddley on 2015-8-7.
//  Copyright © 2015 Eightt. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface EISimpleProgressIndicator : NSView

@property (readwrite, nonatomic) CGFloat proportion;
@property (readwrite, nonatomic) CGFloat opacity;

@end
