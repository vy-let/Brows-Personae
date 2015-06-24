//
//  SiteProfile.h
//  Brows Personæ
//
//  Created by Taldar Baddley on 2014-10-12.
//  Copyright (c) 2014 Eightt. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <WebKit/WebKit.h>

@class WebHistoryItem;


//const UInt32 SiteProfileStorePresentVersion;
//const UInt32 SiteProfileStoreApplicationID;


@interface BrowsPersona : NSObject

+ (instancetype)named:(NSString *)profileName withRootHost:(NSString *)baseHost;
+ (instancetype)named:(NSString *)profileName;
+ (NSArray *)allLocalPersonæ;
+ (NSURL *)mainProfileFolder;

@property (readonly) NSString *name;
@property (readonly) NSString *rootHost;

@property (readonly) WKWebsiteDataStore *webkitDataBacking;
@property (readonly) WKProcessPool *webProcessPool;


#pragma mark Cookie Data Source

- (NSArray *)cookies;
- (void)removeAllCookies;
- (void)removeAllCookiesForHost:(NSString *)host;
- (void)removeExpiredCookies;
- (void)removeCookieWithName:(NSString *)name domain:(NSString *)domain path:(NSString *)path;
- (void)setCookie:(NSHTTPCookie *)cookie;
- (void)setCookies:(NSArray *)cookies forURL:(NSURL *)URL mainDocumentURL:(NSURL *)mainDocumentURL;
- (NSArray *)cookiesForRequest:(NSURLRequest *)request;
- (NSArray *)cookiesForRequestAtURL:(NSURL *)url;

#pragma mark History Data Source

//
// An array of WebHistoryItems, arranged chronologically
- (NSArray *)history;

//
// An array of WebHistoryItems between startDate (inclusive) and endDate (exclusive),
// arranged chronologically. The time granularity of history items is one second.
- (NSArray *)historyBetweenDate:(NSDate *)startDate andDate:(NSDate *)endDate;

//
// Find all history items matching human input. When results are ready they're delivered
// to the given block on the specified queue.
// The results are an array of @[matchQuality, WebHistoryItem] tuples, in arbitrary order.
// (matchQuality is an integer NSNumber, higher = better.)
// The block may be called multiple times as new results are found.
// Bear in mind the block may be called long after you've finished needing results,
// and that the stop out-parameter is only a suggestion.
- (void)findHistoryItemsMatching:(NSString *)fuzzyPattern
deliveringResultsToMainQueueByDoing:(void (^)(NSArray *results, BOOL *stop))resultsBlock;

//
// Put a web history item into the Brows Persona.
// The receiver will take responsibility for duplicates and
// perform the necessary checks. You can never count on the object-
// identity of a WebHistoryItem being the same on the way into and
// out of a Brows Persona.
- (void)putHistoryItem:(WebHistoryItem *)item;

//
- (void)deleteHistoryItemForURL:(NSURL *)url;

@end
