//
//  BrowsTabState.m
//  Brows Personæ
//
//  Created by Violet Baddley on 2015-6-28.
//  Copyright © 2015 Eightt. All rights reserved.
//

#import "BrowsTabState.h"

@interface BrowsTabState ()

@property (nonatomic, readwrite) BOOL canGoBackward;
@property (nonatomic, readwrite) BOOL canGoForward;
@property (nonatomic, readwrite) NSString *location;
@property (nonatomic, readwrite, getter=isEditingLocation) BOOL editingLocation;
@property (nonatomic, readwrite, getter=isLoading) BOOL loading;
@property (nonatomic, readwrite) double loadingProgress;
@property (nonatomic, readwrite) NSString *title;
@property (nonatomic, readwrite, getter=isSecure) BOOL secure;

@end



@implementation BrowsTabState

- (instancetype)initWithCanGoBackward:(BOOL)canB
                         canGoForward:(BOOL)canF
                             location:(NSString *)loc
                         isEditingLoc:(BOOL)ed
                            isLoading:(BOOL)load
                      loadingProgress:(double)progrefs
                                title:(NSString *)tit
                             isSecure:(BOOL)sec {
    
    if (!(self = [super init]))  return nil;
    
    [self setCanGoBackward:canB];
    [self setCanGoForward:canF];
    [self setLocation:loc];
    [self setEditingLocation:ed];
    [self setLoading:load];
    [self setLoadingProgress:progrefs];
    [self setTitle:tit];
    [self setSecure:sec];
    
    return self;
    
}

+ (BrowsTabState *)nilState {
    static BrowsTabState *ei_nilState;
    static dispatch_once_t ei_didInitNilState;
    dispatch_once(&ei_didInitNilState, ^{
        ei_nilState = [[self alloc] initWithCanGoBackward:NO
                                             canGoForward:NO
                                                 location:@""
                                             isEditingLoc:NO
                                                isLoading:NO
                                          loadingProgress:0
                                                    title:@""
                                                 isSecure:NO];
    });
    
    return ei_nilState;
    
}

- (BOOL)isEqual:(id)object {
    return ([object isKindOfClass:[BrowsTabState class]] &&
            [self canGoBackward] == [object canGoBackward] &&
            [self canGoForward] == [object canGoForward] &&
            [[self location] isEqual:[object location]] &&
            [self isEditingLocation] == [object isEditingLocation] &&
            [self isLoading] == [object isLoading] &&
            [self loadingProgress] == [object loadingProgress] &&
            [[self title] isEqual:[object title]] &&
            [self isSecure] == [object isSecure]
            );
}

- (NSUInteger)hash {
    NSAssert(sizeof(NSUInteger) == sizeof(double), @"Pointer magic which only works on 64-bit systems!");
    
    NSUInteger progressBits = * ((NSUInteger *)&_loadingProgress);
    NSUInteger lilBits = (_canGoBackward |
                          _canGoForward << 1 |
                          _editingLocation << 2 |
                          _loading << 3 |
                          _secure << 4
                          );
    
    return lilBits ^ progressBits ^ [_location hash] ^ [_title hash];
    
}

@end
