//
//  WebView+ScrollViewAccess.m
//  Brows Personæ
//
//  Created by Talus Baddley on 2015-2-11.
//  Copyright (c) 2015 Eightt. All rights reserved.
//

#import "WebView+ScrollViewAccess.h"

@implementation WebView (ScrollViewAccess)

- (NSScrollView *)ei_scrollView {
    // Thanks to Rob Keniger: http://stackoverflow.com/questions/6362876/webview-with-small-scroll-bars-how#answer-6366327
    return [[[[self mainFrame] frameView] documentView] enclosingScrollView];
}

@end
