//
//  BrowsTabTableCellView.m
//  Brows Personæ
//
//  Created by Talus Baddley on 2015-1-22.
//  Copyright (c) 2015 Eightt. All rights reserved.
//

#import "BrowsTabTableCellView.h"





@implementation BrowsTabTableCellView


+ (instancetype)measurementDummyView {
    static BrowsTabTableCellView *measurementTableCellView = nil;
    
    static dispatch_once_t gotADummy;
    dispatch_once(&gotADummy, ^{
        NSArray *topLevels;
        BOOL itWorked =
        [[[NSNib alloc] initWithNibNamed:@"TabCell" bundle:[NSBundle mainBundle]] instantiateWithOwner:self topLevelObjects:&topLevels];
        
        if (!itWorked) {NSLog(@"Failed to make a dummy tab cell!!!!!!"); return;};
        
        for (id tlo in topLevels) {
            if ([tlo respondsToSelector:@selector(thumbnailView)]) {
                measurementTableCellView = tlo;
                break;
            }
        }
        
        if (!measurementTableCellView)
            NSLog(@"Dummy tab cell nib didn't contain a BrowsTabTableCellView!!!!!!!!!!!!!!");
        
    });
    
    return measurementTableCellView;
    
}


@end
