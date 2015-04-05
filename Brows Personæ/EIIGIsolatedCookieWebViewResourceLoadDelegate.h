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

#import <Cocoa/Cocoa.h>
#import <WebKit/WebKit.h>

@class BrowsPersona;

#pragma mark -
#pragma mark private resourceLoadDelegate class interface

@interface EIIGIsolatedCookieWebViewResourceLoadDelegate : NSObject {
    
}

- (EIIGIsolatedCookieWebViewResourceLoadDelegate *)init;

- (NSURLRequest *)webView:(WebView *)sender
                 resource:(id)identifier
          willSendRequest:(NSURLRequest *)request
         redirectResponse:(NSURLResponse *)redirectResponse
           fromDataSource:(WebDataSource *)dataSource;

- (void)webView:(WebView *)sender
       resource:(id)identifier
didReceiveResponse:(NSURLResponse *)response
 fromDataSource:(WebDataSource *)dataSource;

- (NSArray *)cookies;

- (void)setCookies:(NSArray *)cookies forURL:(NSURL *)URL mainDocumentURL:(NSURL *)mainDocumentURL;
- (void)setCookie:(NSHTTPCookie *)cookie;
- (NSArray *)getCookieArrayForRequest:(NSURLRequest *)request;

- (void)removeAllCookies;
- (void)removeAllCookiesForHost:(NSString *)host;
- (void)removeExpiredCookies;

@property (nonatomic, weak) BrowsPersona *browsPersona;

@end


