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

// Category exploded by Talus Baddley out from IGIsolatedCookieWebView.m
// to publish the private interface and aid in future customizations.

#import "NSHTTPCookie+IGPropertyTesting.h"


@implementation NSHTTPCookie (IGPropertyTesting)

- (BOOL)isExpired
{
    return [[self expiresDate] timeIntervalSinceNow] < 0;
}

- (BOOL)isForHost:(NSString *)host
{
    return ([[self domain] isEqualToString:host]
            || ([[self domain] hasPrefix:@"."]
                && [[NSString stringWithFormat:@".%@",host] hasSuffix:[self domain]])
            );
}

- (BOOL)isForPath:(NSString *)path;
{
    return (path
            && [path hasPrefix:[self path]]
            );
}

- (BOOL)isForRequest:(NSURLRequest *)request
{
    return [self isForRequestAtURL:[request URL]];
}

- (BOOL)isForRequestAtURL:(NSURL *)url {
    return (![self isExpired]
            && [self isForHost:[url host]]
            && [self isForPath:[url path]]
            );
}

- (BOOL)isEqual:(id)object
{
    return ([object isKindOfClass:[self class]]
            && [[self name] isEqualToString:[object name]]
            && [[self domain] isEqualToString:[object domain]]
            && [[self path] isEqualToString:[object path]]
            );
}

@end


