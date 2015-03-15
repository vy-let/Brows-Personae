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

// Class exploded by Talus Baddley out from IGIsolatedCookieWebView.m
// to publish the private interface and aid in future customizations.

#import "EIIGIsolatedCookieWebViewResourceLoadDelegate.h"
#import "NSHTTPCookie+IGPropertyTesting.h"
#import "SiteProfile.h"

#pragma mark -
#pragma mark private resourceLoadDelegate class implementation

@implementation EIIGIsolatedCookieWebViewResourceLoadDelegate

- (EIIGIsolatedCookieWebViewResourceLoadDelegate *)init
{
    self = [super init];
    if (self) {
        cookieStore = [[NSMutableArray alloc] init];
    }
    return self;
}

#if !__has_feature(objc_arc)
- (void)dealloc {
    [cookieStore release];
    [super dealloc];
}
#endif

- (void)pullCookiesFromResponse:(NSURLResponse *)response
{
    if ([response respondsToSelector:@selector(allHeaderFields)]) {
        NSDictionary *allHeaders = [(NSHTTPURLResponse *)response allHeaderFields];
        NSArray *cookies = [NSHTTPCookie cookiesWithResponseHeaderFields:allHeaders
                                                                  forURL:[response URL]];
        for (NSHTTPCookie *aCookie in cookies) {
            [self setCookie:aCookie];
        }
        //		NSLog(@"%d %@",[(NSHTTPURLResponse *)response statusCode],[[response URL] absoluteURL]);
    }
}

- (NSURLRequest *)webView:(WebView *)sender
                 resource:(id)identifier
          willSendRequest:(NSURLRequest *)request
         redirectResponse:(NSURLResponse *)redirectResponse
           fromDataSource:(WebDataSource *)dataSource
{
    if (redirectResponse) [self pullCookiesFromResponse:redirectResponse];
    NSMutableURLRequest *newRequest = [NSMutableURLRequest requestWithURL:[request URL]
                                                              cachePolicy:[request cachePolicy]
                                                          timeoutInterval:[request timeoutInterval]];
    [newRequest setAllHTTPHeaderFields:[request allHTTPHeaderFields]];
    if ([request HTTPBodyStream]) {
        [newRequest setHTTPBodyStream:[request HTTPBodyStream]];
    } else {
        [newRequest setHTTPBody:[request HTTPBody]];
    }
    [newRequest setHTTPMethod:[request HTTPMethod]];
    [newRequest setHTTPShouldHandleCookies:NO];
    [newRequest setMainDocumentURL:[request mainDocumentURL]];
    NSArray *newCookies = [self getCookieArrayForRequest:request];
    if (newCookies
        && ([newCookies count] > 0)) {
        //		NSLog(@"cookies being sent to %@: %@",
        //			  [[request URL] absoluteURL],
        //			  [NSHTTPCookie requestHeaderFieldsWithCookies:newCookies]);
        NSMutableDictionary *newAllHeaders = [NSMutableDictionary dictionaryWithDictionary:[request allHTTPHeaderFields]];
        [newAllHeaders addEntriesFromDictionary:[NSHTTPCookie requestHeaderFieldsWithCookies:newCookies]];
        [newRequest setAllHTTPHeaderFields:[NSDictionary dictionaryWithDictionary:newAllHeaders]];
    }
    return newRequest;
}

- (void)webView:(WebView *)sender
       resource:(id)identifier
didReceiveResponse:(NSURLResponse *)response
 fromDataSource:(WebDataSource *)dataSource
{
    [self pullCookiesFromResponse:response];
}

- (NSArray *)cookies
{
    NSLog(@"FETCHING ALL COOKIES.\nCookie store has %@\nand DB has %@", cookieStore, [[self siteProfile] cookies]);
#if __has_feature(objc_arc)
    return [cookieStore copy];
#else
    return [[cookieStore copy] autorelease];
#endif
}

- (void) removeAllCookies
{
    [cookieStore removeAllObjects];
    [[self siteProfile] removeAllCookies];
}

- (void)removeAllCookiesForHost:(NSString *)host
{
    for (NSHTTPCookie *aCookie in [NSArray arrayWithArray:cookieStore]) {
        if ([aCookie isForHost:host]) {
            [cookieStore removeObject:aCookie];
        }
    }
    [[self siteProfile] removeAllCookiesForHost:host];
}

- (void)removeExpiredCookies
{
    for (NSHTTPCookie *aCookie in [NSArray arrayWithArray:cookieStore]) {
        if ([aCookie isExpired]) {
            [cookieStore removeObject:aCookie];
        }
    }
    [[self siteProfile] removeExpiredCookies];
}

- (void)setCookie:(NSHTTPCookie *)cookie
{
    //	NSLog(@"should be setting cookie with name '%@' and value '%@' for URL '%@'",
    //		  [cookie name], [cookie value], [url absoluteString]);
    if (cookie) {
        [cookieStore removeObject:cookie];
        [cookieStore addObject:cookie];
    }
    [[self siteProfile] setCookie:cookie];
    [self removeExpiredCookies];
}

- (NSArray *)getCookieArrayForRequest:(NSURLRequest *)request
{
    NSMutableArray *cookiesToSend = [NSMutableArray array];
    for (NSHTTPCookie *aCookie in cookieStore) {
        if ([aCookie isForRequest:request]) {
            [cookiesToSend addObject:aCookie];
        }
    }
    NSLog(@"FETCHING COOKIES FOR REQUEST.\nCookie store has %@\nand DB has %@", cookiesToSend, [[self siteProfile] cookiesForRequest:request]);
    return [NSArray arrayWithArray:cookiesToSend];
}

@end