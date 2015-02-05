/*********************************************************************************
 
 © Copyright 2010, Isaac Greenspan
 
 Permission is hereby granted, free of charge, to any person
 obtaining a copy of this software and associated documentation
 files (the "Software"), to deal in the Software without
 restriction, including without limitation the rights to use,
 copy, modify, merge, publish, distribute, sublicense, and/or sell
 copies of the Software, and to permit persons to whom the
 Software is furnished to do so, subject to the following
 conditions:
 
 The above copyright notice and this permission notice shall be
 included in all copies or substantial portions of the Software.
 
 THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
 EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES
 OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
 NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT
 HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY,
 WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
 FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR
 OTHER DEALINGS IN THE SOFTWARE.
 
 *********************************************************************************/

//
//  IGIsolatedCookieWebView.m
//

#import "IGIsolatedCookieWebView.h"
#import "IGIsolatedCookieWebViewResourceLoadDelegate.h"

#pragma mark -
#pragma mark main class implementation

@implementation IGIsolatedCookieWebView

- (id)initWithFrame:(NSRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        // Initialization code here.
		[self awakeFromNib];
    }
    return self;
}

- (void)awakeFromNib
{
//	NSLog(@"=== awakeFromNib ===");
	isolatedCookieResourceLoadDelegate = [[IGIsolatedCookieWebViewResourceLoadDelegate alloc] init];
	[self setResourceLoadDelegate:isolatedCookieResourceLoadDelegate];
}

#if !__has_feature(objc_arc)
- (void)dealloc
{
	[isolatedCookieResourceLoadDelegate release];
	[super dealloc];
}
#endif

- (NSArray *)cookies
{
    return [(IGIsolatedCookieWebViewResourceLoadDelegate *)[self resourceLoadDelegate] cookies];
}

- (void)injectCookie:(NSHTTPCookie *)cookie
{
	[(IGIsolatedCookieWebViewResourceLoadDelegate *)[self resourceLoadDelegate] setCookie:cookie];
}

- (void)removeAllCookies
{
    [(IGIsolatedCookieWebViewResourceLoadDelegate *)[self resourceLoadDelegate] removeAllCookies];
}

- (void)removeAllCookiesForHost:(NSString *)host
{
    [(IGIsolatedCookieWebViewResourceLoadDelegate *)[self resourceLoadDelegate] removeAllCookiesForHost:host];
}

@end

