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



- (void)awakeFromNib {
    [super awakeFromNib];
    
    dispatch_once(&racObservationsDidInit, ^{
        
        @weakify(self)
        [RACObserve(self, representedTab) subscribeNext:^(BrowsTab *applicableTab) {
            // Whenever the represented tab is set, subscribe to its thumbnails & favicons.
            
            BOOL (^whileApplicable)(id) = ^BOOL(id dontcare) {
                // Terminate all subscriptions which no longer refer to the represented tab.
                @strongify(self)
                return [self representedTab] == applicableTab;
            };
            
            RAC([self thumbnailView], image) = [[RACObserve(applicableTab, thumbnail)
                                                 startWith:[applicableTab thumbnail]]
                                                takeWhileBlock:whileApplicable];
            
            RAC([self faviconView], image) = [[RACObserve(applicableTab, favicon)
                                               startWith:[applicableTab favicon]]
                                              takeWhileBlock:whileApplicable];
            
            
            
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





@end
