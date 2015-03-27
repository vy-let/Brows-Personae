//
//  BrowsTabTableCellView.m
//  Brows Personæ
//
//  Created by Talus Baddley on 2015-1-22.
//  Copyright (c) 2015 Eightt. All rights reserved.
//

#import "BrowsTabTableCellView.h"
#import <ReactiveCocoa/ReactiveCocoa.h>
#import "BrowsTab.h"


@interface BrowsTabTableCellView () {
    NSTrackingArea *whyTheFuckDoIHaveToManuallyDealWithThisShitIn2015;
    dispatch_once_t racObservationsDidInit;
}

@end





@implementation BrowsTabTableCellView


+ (instancetype)measurementDummyView {
    static BrowsTabTableCellView *measurementTableCellView = nil;
    
    static dispatch_once_t gotADummy;
    dispatch_once(&gotADummy, ^{
        NSArray *topLevels;
        BOOL itWorked =
        [[[NSNib alloc] initWithNibNamed:@"TabCell" bundle:[NSBundle mainBundle]] instantiateWithOwner:self topLevelObjects:&topLevels];
        
        if (!itWorked)  return;
        
        for (id tlo in topLevels) {
            if ([tlo respondsToSelector:@selector(thumbnailView)]) {
                measurementTableCellView = tlo;
                break;
            }
        }
        
    });
    
    return measurementTableCellView;
    
}



- (void)awakeFromNib {
    [super awakeFromNib];
    
    dispatch_once(&racObservationsDidInit, ^{
        
        RACSignal *repTab = [RACObserve(self, objectValue)
                             filter:^BOOL(BrowsTab *applicableTab) {  return !!applicableTab;  }];
        
        RAC([self thumbnailView], image, [NSImage imageNamed:@"NSMultipleDocuments"]) = [repTab map:^id(BrowsTab *applicableTab) {
            return [applicableTab thumbnail];
        }];
        
        RAC([self faviconView], image, [NSImage imageNamed:@"NSNetwork"]) = [repTab map:^id(BrowsTab *applicableTab) {
            return [applicableTab favicon];
        }];
        
    });
    
}



- (void)updateTrackingAreas {
    [super updateTrackingAreas];
    
    if (whyTheFuckDoIHaveToManuallyDealWithThisShitIn2015) {
        [self removeTrackingArea:whyTheFuckDoIHaveToManuallyDealWithThisShitIn2015];
        whyTheFuckDoIHaveToManuallyDealWithThisShitIn2015 = nil;
    }
    
    whyTheFuckDoIHaveToManuallyDealWithThisShitIn2015 = [[NSTrackingArea alloc] initWithRect:[self bounds]
                                                                                     options:NSTrackingMouseEnteredAndExited | NSTrackingActiveInActiveApp
                                                                                       owner:self
                                                                                    userInfo:nil];
    [self addTrackingArea:whyTheFuckDoIHaveToManuallyDealWithThisShitIn2015];
    
}


- (void)mouseEntered:(NSEvent *)theEvent {
    [super mouseEntered:theEvent];
    [[self tabCloseButton] setHidden:NO];
    
}

- (void)mouseExited:(NSEvent *)theEvent {
    [super mouseExited:theEvent];
    [[self tabCloseButton] setHidden:YES];
}



- (BrowsTab *)representedTab {
    return [self objectValue];
}

- (void)setRepresentedTab:(BrowsTab *)representedTab {
    [self setObjectValue:representedTab];
}





@end
