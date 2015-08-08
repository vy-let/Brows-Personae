//
//  BrowsTabState.h
//  Brows Personæ
//
//  Created by Violet Baddley on 2015-6-28.
//  Copyright © 2015 Eightt. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface BrowsTabState : NSObject

- (instancetype)initWithCanGoBackward:(BOOL)canB
                         canGoForward:(BOOL)canF
                             location:(NSString *)loc
                         isEditingLoc:(BOOL)ed
                            isLoading:(BOOL)load
                      loadingProgress:(double)progrefs
                                title:(NSString *)tit
                             isSecure:(BOOL)sec;

+ (BrowsTabState *)nilState;

// OK imma be lazy and let the compiler do its evil shit.
@property (nonatomic, readonly) BOOL canGoBackward;
@property (nonatomic, readonly) BOOL canGoForward;
@property (nonatomic, readonly) NSString *location;
@property (nonatomic, readonly, getter=isEditingLocation) BOOL editingLocation;
@property (nonatomic, readonly, getter=isLoading) BOOL loading;
@property (nonatomic, readonly) double loadingProgress;
@property (nonatomic, readonly) NSString *title;
@property (nonatomic, readonly, getter=isSecure) BOOL secure;

@end
