//
//  SiteProfile.m
//  Brows Personæ
//
//  Created by Violet Baddley on 2014-10-12.
//  Copyright (c) 2014 Eightt. All rights reserved.
//

#import "BrowsPersona.h"
#import <ReactiveCocoa/ReactiveCocoa.h>
#import <FMDB/FMDB.h>
#import "NSHTTPCookie+IGPropertyTesting.h"
#import <NSArray+Functional/NSArray+Functional.h>


const UInt32 SiteProfileStorePresentVersion = 1;
const UInt32 SiteProfileStoreApplicationID = 625418296;  // irb> rand 2**31


@interface BrowsPersona () {
    NSURL *diskLocation;
    NSString *name;
    NSString *rootHost;
    WKProcessPool *processPool;  dispatch_once_t didInitProcessPool;
    FMDatabaseQueue *cookieJar;
    u_int32_t presentSessionID;  // this type b/c of arc4random's behavior
    
    dispatch_queue_t backgroundCookieQueue;
    dispatch_once_t backgroundCookieSetup;
    dispatch_once_t webkitDataBackingSetup;
    WKWebsiteDataStore *wkWebkitDataBacking;
    RACSubject *cookieTouchPusher;  // Push arrays of cookies to update their last-used timestamps.
    NSMutableSet *cookiesNeedingTouching;
}

@end

@implementation BrowsPersona


static dispatch_queue_t profileSanity;
static NSMapTable *namedProfiles;


+ (void)initialize {
    profileSanity = dispatch_queue_create("SiteProfileSanityQueue", DISPATCH_QUEUE_SERIAL);
    namedProfiles = [NSMapTable strongToWeakObjectsMapTable];
}

+ (NSURL *)mainProfileFolder {
    static NSURL *profiles = nil;
    static dispatch_once_t foundMainProfileFolder;
    dispatch_once(&foundMainProfileFolder, ^{
        NSURL *applicationSupport = [[NSFileManager defaultManager] URLForDirectory:NSApplicationSupportDirectory
                                                                           inDomain:NSUserDomainMask
                                                                  appropriateForURL:nil
                                                                             create:YES
                                                                              error:NULL];
        if (!applicationSupport)
            @throw NSInternalInconsistencyException;
        
        profiles = [[applicationSupport URLByAppendingPathComponent:@"Brows Personæ" isDirectory:YES]
                    URLByAppendingPathComponent:@"Personæ" isDirectory:YES];
        [[NSFileManager defaultManager] createDirectoryAtURL:profiles
                                 withIntermediateDirectories:YES
                                                  attributes:nil
                                                       error:NULL];  // Will not fail.
        
    });
    
    return profiles;
    
}


+ (instancetype)named:(NSString *)profileName withRootHost:(NSString *)baseHost {
    __block id result;
    
    dispatch_sync(profileSanity, ^{
        result = [namedProfiles objectForKey:profileName];
        if (!result) {
            NSString *profileFilename = [NSString stringWithFormat:@"%@.browspersona", profileName];
            result = [[[self class] alloc] initAtURL:[[[self class] mainProfileFolder] URLByAppendingPathComponent:profileFilename]
                                            withName:profileName
                                            rootHost:baseHost];
            
            if (result)
                [namedProfiles setObject:result forKey:profileName];
        }
    });
    
    return result;
    
}


+ (instancetype)named:(NSString *)profileName {
    return [self named:profileName withRootHost:profileName];
}


+ (NSArray *)allLocalPersonæ {
    NSError *dirScanError = nil;
    NSArray *browspersonaFiles = [[[NSFileManager defaultManager] contentsOfDirectoryAtURL:[self mainProfileFolder]
                                                               includingPropertiesForKeys:@[]
                                                                                  options:0
                                                                                    error:&dirScanError]
                                  filterUsingBlock:^BOOL(NSURL *containedFile) {
                                      return [[containedFile pathExtension] isEqual:@"browspersona"];
                                  }];
    if (!browspersonaFiles) {
        NSLog(@"Couldn't scan for known brows personæ: %@", dirScanError);
        return @[];
    }
    
    return [[browspersonaFiles
             mapUsingBlock:^id(NSURL *browspersonaFile) {
                 BrowsPersona *persona = [self named:[[browspersonaFile URLByDeletingPathExtension] lastPathComponent]];
                 return persona ? persona : [NSNull null];
                 
             }] filterUsingBlock:^BOOL(id obj) {
                 return obj != [NSNull null];
             }];
    
}



- (instancetype)initAtURL:(NSURL *)file withName:(NSString *)profileName rootHost:(NSString *)host {
    if (!(self = [super init])) return nil;
    
    diskLocation = file;
    name = [profileName copy];
    rootHost = [host copy];
    presentSessionID = arc4random();
    backgroundCookieQueue = dispatch_queue_create(NULL, DISPATCH_QUEUE_SERIAL);
    
    BOOL looseDatabaseIntegrity =
    [self openDatabase];
    
    if (!looseDatabaseIntegrity)  return nil;
    
    return self;
}


- (void)dealloc {
    FMDatabaseQueue *cookieTin = cookieJar;
    //NSLog(@"Profile for %@ is being deallocated; db may vacuum shortly.", name);
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0), ^{
        if (arc4random_uniform(30) == 0)
            [cookieTin inDatabase:^(FMDatabase *db) {
                [db executeUpdate:@"vacuum"];
            }];
        [cookieTin close];
    });
    
}



- (WKWebsiteDataStore *)webkitDataBacking {
    dispatch_once(&webkitDataBackingSetup, ^{
        NSURL *baseURL = [[[self class] mainProfileFolder] URLByAppendingPathComponent:[self name] isDirectory:YES];
        wkWebkitDataBacking = [WKWebsiteDataStore ei_dataStoreWithBaseURL:baseURL];
    });
    
    return wkWebkitDataBacking;
    
}



- (BOOL)openDatabase {
    cookieJar = [FMDatabaseQueue databaseQueueWithPath:[diskLocation path]];
    //[cookieJar inDatabase:^(FMDatabase *db) {  [db setTraceExecution:YES];  }];
    
    BOOL success =
    [self migrateCookieJarIfNecessary];
    
    if (!success)  return NO;
    
    
    return YES;
}

- (BOOL)migrateCookieJarIfNecessary {
    // Presently just check to see if db is empty and create tables.
    __block BOOL worked = YES;
    
    [cookieJar inDatabase:^(FMDatabase *db) {
        [db executeStatements:@"pragma encoding = \"UTF-8\";"];
        [db executeStatements:@"pragma journal_mode = DELETE;"
         "pragma checkpoint_fullfsync = yes;"];
    }];
    
    [cookieJar inTransaction:^(FMDatabase *db, BOOL *rollback) {
        
        // Check to see if database is empty
        FMResultSet *nonEmptyAnswer = [db executeQuery:@"select count(*) from sqlite_master where type = 'table' and name = 'BrowsPersonæDataVersion'"];
        [nonEmptyAnswer next];  if ([nonEmptyAnswer intForColumnIndex:0] != 0) {
            [nonEmptyAnswer close];  nonEmptyAnswer = nil;
            
            // Non-empty. Check the version number
            FMResultSet *dataVersionAnswer = [db executeQuery:@"select version from BrowsPersonæDataVersion"];  [dataVersionAnswer next];
            
            if ([dataVersionAnswer intForColumnIndex:0] > SiteProfileStorePresentVersion) {
                // Too new
                NSLog(@"Using a version of the brows profile that's too new! Abort! Abort!");
                *rollback = YES; worked = NO;  [dataVersionAnswer close];  dataVersionAnswer = nil;
                return;
                
            } else {
                // Version is good; OK to go.
                [dataVersionAnswer close];  dataVersionAnswer = nil;
                return;
            }
            
        }
        
        [nonEmptyAnswer close];  nonEmptyAnswer = nil;
        
        // Database needs initialization
        
        // String substitution is OK here, because
        //   1. It's just an int,
        //   2. We know what it is, and
        //   3. We're coercing it to unsigned-32, which sqlite expects.
        [db executeUpdate:[NSString stringWithFormat:@"pragma application_id = %d", (UInt32)SiteProfileStoreApplicationID]];
        
        [db executeStatements:
         @"create table BrowsPersonæDataVersion (version integer);"
         "insert into BrowsPersonæDataVersion (version) values (1);"];
        
        [db executeStatements:
         @"create table Session ("
         "    id        integer primary key"
         "  , lastUsed  integer"
         ");"];
        
        [db executeUpdate:
         @"create table Cookie ("
         "    id          integer primary key"
         "  , session     integer references Session (id) on delete cascade"
         // Critical attributes
         "  , path        text not null"
         "  , name        text not null"
         "  , value       text not null"
         "  , domain      text not null"  // always available, v0 or v1
         "  , originURL   text"  // possible, in addition to domain (v1)
         "  , expiresDate integer"
         // Other attributes
         "  , comment     text"
         "  , commentURL  text"
         "  , secure      integer not null default 0"
         //"  , sessionOnly integer not null default 0"  // session not being null implies sessionOnly.
         "  , portList    text"
         "  , version     integer not null default 0"
         "  , lastUsed    integer not null"
         
         "  , unique (path, name, domain) )"];  // unique by standard design
        
//        [db executeUpdate:@""
//         " create table DomainFavicon (         "
//         "    id            integer primary key "
//         "  , domain        text not null       "
//         "  , favicon       blob                "
//         "  , unique (domain)         )"];
        
        [db executeUpdate:
         @"create table HistoryItem ("
         "    id            integer primary key"
         //"  , previousItem  integer references HistoryItem (id) on delete set null"
         "  , pageTitle     text not null"
         "  , pageURL       text not null"
         "  , visitedDate   integer not null"
//         "  , favicon       integer references DomainFavicon (id) on delete set null"
         "  , unique (pageURL)    "
         ")"];
        
        
    }];
    
    // Absolutely make sure foreign keys are turned on.
    if (worked)
        [cookieJar inDatabase:^(FMDatabase *db) {
            [db executeUpdate:@"pragma foreign_keys = on"];
        }];
    
    return worked;
    
}



- (NSString *)name {
    return name;
}

- (NSString *)rootHost {
    return rootHost;
}

- (WKProcessPool *)webProcessPool {
    dispatch_once(&didInitProcessPool, ^{
        processPool = [[WKProcessPool alloc] init];
    });
    
    return processPool;
    
}






#pragma mark Cookie Data Source



- (NSHTTPCookie *)cookieForCurrentResultInResultSet:(FMResultSet *)resultSet {
    NSMutableDictionary *cookieAttrs = [NSMutableDictionary dictionaryWithCapacity:13];
    
    if (![resultSet columnIsNull:@"session"] && [resultSet longForColumn:@"session"] != presentSessionID) {
        NSLog(@"Skipping stored cookie because its session does not match the present session.");
        return nil;
    }
    
    int cookieVersion = [resultSet intForColumn:@"version"];
    [cookieAttrs setObject:[NSString stringWithFormat:@"%d", cookieVersion] forKey:NSHTTPCookieVersion];
    
    [cookieAttrs setObject:[resultSet stringForColumn:@"path"] forKey:NSHTTPCookiePath];
    [cookieAttrs setObject:[resultSet stringForColumn:@"name"] forKey:NSHTTPCookieName];
    [cookieAttrs setObject:[resultSet stringForColumn:@"domain"] forKey:NSHTTPCookieDomain];
    [cookieAttrs setObject:[resultSet stringForColumn:@"value"] forKey:NSHTTPCookieValue];
    
    if (![resultSet columnIsNull:@"originURL"])
        [cookieAttrs setObject:[resultSet stringForColumn:@"originURL"]
                        forKey:NSHTTPCookieOriginURL];
    
    if (cookieVersion == 1 && ![resultSet columnIsNull:@"expiresDate"]) {
        NSDate *expiresDate = [NSDate dateWithTimeIntervalSince1970:[resultSet longLongIntForColumn:@"expiresDate"]];
        [cookieAttrs setObject:[NSString stringWithFormat:@"%lld", (long long int)[expiresDate timeIntervalSinceNow]]
                        forKey:NSHTTPCookieMaximumAge];
    }
    if (cookieVersion == 0 && ![resultSet columnIsNull:@"expiresDate"])
        [cookieAttrs setObject:[resultSet dateForColumn:@"expiresDate"]
                        forKey:NSHTTPCookieExpires];
    
    if (cookieVersion == 1 && ![resultSet columnIsNull:@"comment"])
        [cookieAttrs setObject:[resultSet stringForColumn:@"comment"]
                        forKey:NSHTTPCookieComment];
    if (cookieVersion == 1 && ![resultSet columnIsNull:@"commentURL"])
        [cookieAttrs setObject:[resultSet stringForColumn:@"commentURL"]
                        forKey:NSHTTPCookieCommentURL];
    
    if (![resultSet columnIsNull:@"portList"])
        [cookieAttrs setObject:[resultSet stringForColumn:@"portList"]
                        forKey:NSHTTPCookiePort];
    
    if ([resultSet boolForColumn:@"secure"])
        [cookieAttrs setObject:@YES forKey:NSHTTPCookieSecure];  // Specifying *any* value indicates YES.
    
    
    return [NSHTTPCookie cookieWithProperties:cookieAttrs];
    
}



- (NSArray *)cookies {
    NSMutableArray *cookies = [NSMutableArray array];
    
    [cookieJar inDatabase:^(FMDatabase *db) {
        FMResultSet *cookiePtr = [db executeQuery:@" select * from Cookie where session isnull or session = ? ", @(presentSessionID)];
        while ([cookiePtr next]) {
            NSHTTPCookie *cookie = [self cookieForCurrentResultInResultSet:cookiePtr];
            if (cookie)  [cookies addObject:cookie];
            
        }
        
        [cookiePtr close];
        
    }];
    
    return cookies;
}


- (NSArray *)cookiesForRequest:(NSURLRequest *)request {
    return [self cookiesForRequestAtURL:[request URL]];
    
}


- (NSArray *)cookiesForRequestAtURL:(NSURL *)url {
    // SQL-native solution proving to be too finickey for the time being.
    
    NSArray *applicableCookies = [[self cookies] filterUsingBlock:^BOOL(NSHTTPCookie *cookie) {
        return [cookie isForHost:[url host]] && [cookie isForPath:[url path]];
    }];
    
    [self touchCookies:applicableCookies];
    return applicableCookies;
    
}


- (void)touchCookies:(NSArray *)cookies {
    
    dispatch_once(&backgroundCookieSetup, ^{
        // Happens once per profile.
        
        cookiesNeedingTouching = [NSMutableSet set];
        
        //
        // Immediately collect all cookie updates, but hash out duplicates.
        cookieTouchPusher = [RACSubject subject];
        @weakify(backgroundCookieQueue, cookiesNeedingTouching, cookieJar)
        [cookieTouchPusher subscribeNext:^(NSArray *cookieIDs) {
            @strongify(backgroundCookieQueue)
            if (!backgroundCookieQueue) return;
            
            dispatch_async(backgroundCookieQueue, ^{
                @strongify(cookiesNeedingTouching)
                
                [cookiesNeedingTouching addObjectsFromArray:cookieIDs];
                
            });
            
        }];
        
        
        //
        // Delay the actual touching by five seconds, ignoring further update signals in the meantime.
        [[[cookieTouchPusher mapReplace:@YES] throttle:5.0] subscribeNext:^(id yyes) {
            @strongify(backgroundCookieQueue)
            if (!backgroundCookieQueue) return;
            NSInteger updateDate = (NSInteger)[[NSDate date] timeIntervalSince1970] - 5;  // Throttled to five seconds ago
            
            dispatch_async(backgroundCookieQueue, ^{
                @strongify(cookieJar, cookiesNeedingTouching)  if (!cookiesNeedingTouching) return;
                
                // Perform touch
                [cookieJar inTransaction:^(FMDatabase *db, BOOL *rollback) {
                    for (RACTuple *cookieID in cookiesNeedingTouching) {
                        NSString *name = [cookieID first];  NSString *domain = [cookieID second];  NSString *path = [cookieID third];
                        
                        [db executeUpdate:@""
                         " update Cookie set lastUsed = ?             "
                         " where name = ? and domain = ? and path = ? ",
                         @(updateDate), name, domain, path];
                        
                    }
                }];
                
                // Reset batch for next round
                [cookiesNeedingTouching removeAllObjects];
                
            });
            
        }];
        
        
    });
    
    
    
    [cookieTouchPusher sendNext:[cookies mapUsingBlock:^id(NSHTTPCookie *cookie) {
        return [RACTuple tupleWithObjects:[cookie name], [cookie domain], [cookie path], nil];
    }]];
    
    
}



- (void)removeAllCookies {
    NSLog(@"REMOVING ALL COOKIES FOR PROFILE “%@”", [self name]);
    [cookieJar inDatabase:^(FMDatabase *db) {
        [db executeUpdate:@"delete from Cookie"];
    }];
    
}


- (void)removeAllCookiesForHost:(NSString *)host {
    NSLog(@"REMOVING ALL COOKIES FOR HOST “%@” IN PROFILE “%@”", host, [self name]);
    NSArray *hostCookies = [self cookies];
    [cookieJar inTransaction:^(FMDatabase *db, BOOL *rollback) {
        
        [[hostCookies
          filterUsingBlock:^BOOL(NSHTTPCookie *cookie) {
              return [cookie isForHost:host];
              
          }] applyBlock:^(NSHTTPCookie *delCookie) {
              [db executeUpdate:@""
               " delete from Cookie                         "
               " where name = ? and domain = ? and path = ? ",
               [delCookie name], [delCookie domain], [delCookie path]];
              
          }];
        
    }];
    
}


- (void)removeCookieWithName:(NSString *)name domain:(NSString *)domain path:(NSString *)path {
    NSMutableDictionary *removalKeys = [@{} mutableCopy];
    if (name)    [removalKeys setObject:name   forKey:@"name"];
    if (domain)  [removalKeys setObject:domain forKey:@"domain"];
    if (path)    [removalKeys setObject:path   forKey:@"path"];
    
    NSMutableArray *conditions = [@[] mutableCopy];
    if (name)    [conditions addObject:@" name = :name "];
    if (domain)  [conditions addObject:@" domain = :domain "];
    if (path)    [conditions addObject:@" path = :path "];
    
    NSMutableString *deletor = [@" delete from Cookie " mutableCopy];
    if ([conditions count])
        [deletor appendFormat:@" where %@ ", [conditions componentsJoinedByString:@" and "]];
    
    [cookieJar inTransaction:^(FMDatabase *db, BOOL *rollback) {
        [db executeUpdate:deletor withParameterDictionary:removalKeys];
    }];
    
}


- (void)removeExpiredCookies {
    NSDate *expiry = [NSDate date];
    [cookieJar inDatabase:^(FMDatabase *db) {
        
        [db executeUpdate:@""
         " delete from  Cookie "
         "       where  expiresDate not null  and  expiresDate < ? ", expiry];
        
        NSNumber *aWeekAgo = @((NSUInteger)[[NSDate dateWithTimeIntervalSinceNow:(-7 * 86400)] timeIntervalSince1970]);
        [db executeUpdate:@""
         " delete from  Session      "
         "       where  lastUsed < ? ", aWeekAgo];
        
    }];
}


- (void)removeOverflowingCookiesFocusingOnDomain:(NSString *)host {
    [cookieJar inTransaction:^(FMDatabase *db, BOOL *rollback) {
        
        NSInteger maxDomainCookies = 30;
        NSInteger maxJarCookies = 500;
        
        //
        // First trim excessive domain-limited cookies.
        // Outer loop prevents edge-case infinite loops; but
        // should usually break out from the middle of the first or second pass.
        for (int overrun = 0; overrun < maxDomainCookies * 2; overrun++) {
            FMResultSet *domainCookies = [db executeQuery:@""
                                          " select  count(id)  "
                                          "   from  Cookie     "
                                          "  where  domain = ? ", host];
            [domainCookies next];
            long domainCookieCount = [domainCookies longForColumnIndex:0];
            [domainCookies close];
            
            if (domainCookieCount <= maxDomainCookies)
                break;  // Domain cookie count is good.
            
            NSLog(@"Too many cookies in domain %@, persona %@. Trimming out the last-used one.", host, [self name]);
            [db executeUpdate:@""
             " delete from  Cookie                  "
             "       where  domain = ?              "
             "         and  id in (                 "
             "                select id from Cookie "
             "                  where domain = ?    "
             "                order by lastUsed asc "
             "                limit 1               "
             "              )                       ", host, host];
            
        }
        
        //
        // Next trim excessive jar-limited cookies.
        // Same logic as above.
        for (int overrun = 0; overrun < maxJarCookies * 1000; overrun++) {
            FMResultSet *profileCookies = [db executeQuery:@""
                                           " select  count(id)  "
                                           "   from  Cookie     "];
            [profileCookies next];
            long profileCookieCount = [profileCookies longForColumnIndex:0];
            [profileCookies close];
            
            if (profileCookieCount <= maxJarCookies)
                break;  // Cookie count is good.
            
            // Cookie size is still too big.
            NSLog(@"Too many cookies in persona %@. Trimming out the last-used one.", [self name]);
            [db executeUpdate:@""
             " delete from  Cookie                  "
             "       where  id in (                 "
             "                select id from Cookie "
             "                order by lastUsed asc "
             "                limit 1               "
             "              )                       "];
            
        }
        
    }];
}



- (void)setCookies:(NSArray *)cookies forURL:(NSURL *)url mainDocumentURL:(NSURL *)mainDocumentURL {
    NSLog(@"\n\n\n\n\n OH NOES! USING THE OLD COOKIE MECHANISMS!\n\n\n\n\n");
    
    for (NSHTTPCookie *coookieeee in cookies) {
        if ([coookieeee isForHost:[url host]])
            [self setCookie:coookieeee];
        else
            NSLog(@"Rejecting cookie keyed (%@, %@, %@) because it doesn't match the source host %@."
                  ,[coookieeee name], [coookieeee domain], [coookieeee path]
                  ,[url host]);
        
    }
    
    // TODO Make this the designated cookie-setter, so we can do a single batch transaction.
    
}


- (void)setCookie:(NSHTTPCookie *)cookie {
    NSLog(@"\n\n\n\n\n OH NOES! USING THE OLD COOKIE MECHANISMS!\n\n\n\n\n");
    
    if ([[cookie value] length] + [[cookie name] length] + [[cookie path] length]
        + [[cookie domain] length] + [[cookie properties][NSHTTPCookieOriginURL] length]
        + [[cookie comment] length] + [[[cookie commentURL] absoluteString] length]       > 4096) {
        
        NSLog(@"Rejecting cookie for its length.");
        return;
    }
    
    [cookieJar inTransaction:^(FMDatabase *db, BOOL *rollback) {
        
        void (^whoopsie)(id) = ^(id error) {
            NSLog(@"DB Error setting cookie “%@”:\n%@", cookie, error);
            *rollback = YES;
        };
        
        BOOL success;
        
        //
        // Sometime soon, trim out old cookies
        // if the cookie jar grows too full:
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^{
            [self removeOverflowingCookiesFocusingOnDomain:[cookie domain]];
        });
        
        
        //
        // Attempt to do a simple update of the present session's last-used date.
        [db executeUpdate:@""
         " update  Session      "
         "    set  lastUsed = ? "
         "  where  id = ?       ", @((NSInteger)[[NSDate date] timeIntervalSince1970]), @(presentSessionID)];
        
        // If no change was actually made, the session probably doesn't exist (or it already has the present date…)
        // so insert it if necessary:
        if (![db changes]) {
            NSError *sessionUpdateError = nil;
            success = [db executeUpdate:@""
                       " insert  or ignore              "
                       "   into  Session (id, lastUsed) "
                       " values  (?, ?)                 "
                   withErrorAndBindings:&sessionUpdateError,  @(presentSessionID), [NSDate date]];
            
            if (!success)
                return whoopsie(sessionUpdateError);
            
        }
        
        
        // Insert the core cookie information:
        
        NSAssert(!![cookie domain], @"A COOKIE CAME IN WITHOUT A DOMAIN! EVERYBODY GO NUTS!");
        success = [db executeUpdate:@""
                   " insert  or replace "
                   "   into  Cookie ( session, path, name, value, domain, secure, version, lastUsed ) "
                   " values  ( :session, :path, :name, :value, :domain, :secure, :version, :lastUsed ) "
            withParameterDictionary:@{ @"session": [cookie isSessionOnly] ? @(presentSessionID) : [NSNull null]
                                       , @"path": [cookie path]
                                       , @"name": [cookie name]
                                       , @"value": [cookie value]
                                       , @"domain": [cookie domain]
                                       , @"secure": @([cookie isSecure])
                                       , @"version": @([cookie version])
                                       , @"lastUsed": @( (NSInteger)[[NSDate date] timeIntervalSince1970] )
                                       }];
        if (!success)
            return whoopsie([db lastError]);
        
        
        // Now update the auxilliary details:
        
        
        NSNumber *cookieID = @( [db lastInsertRowId] );
        NSDictionary *cookieProperties = [cookie properties];
        
        if ([cookie comment] &&
            ![db executeUpdate:@" update Cookie set comment = ? where id = ? ", [cookie comment], cookieID])
            return whoopsie([db lastError]);
        
        if ([cookie commentURL] &&
            ![db executeUpdate:@" update Cookie set commentURL = ? where id = ? ", [cookie commentURL], cookieID])
            return whoopsie([db lastError]);
        
        // If there's a time limit,
        // set the expiresDate if available; otherwise calculate it based on max-age:
        if (([cookie expiresDate] || cookieProperties[NSHTTPCookieMaximumAge]) &&
            ![db executeUpdate:@" update Cookie set expiresDate = ? where id = ? "
              ,[cookie expiresDate] ?
              @( (NSInteger)[[cookie expiresDate] timeIntervalSince1970] ) :
              @( (NSInteger)[(NSString *)cookieProperties[NSHTTPCookieMaximumAge] doubleValue] )
              , cookieID])
            return whoopsie([db lastError]);
        
        // If there's a max-age, set it directly:
        if (cookieProperties[NSHTTPCookieMaximumAge] &&
            ![db executeUpdate:@" update Cookie set maximumAge = ? where id = ? "
              , [(NSString *)cookieProperties[NSHTTPCookieMaximumAge] integerValue]
              , cookieID])
            return whoopsie([db lastError]);
        
        if (cookieProperties[NSHTTPCookieOriginURL] &&
            ![db executeUpdate:@" update Cookie set originURL = ? where id = ? ", cookieProperties[NSHTTPCookieOriginURL], cookieID])
            return whoopsie([db lastError]);
        
        if (cookieProperties[NSHTTPCookiePort] &&
            ![db executeUpdate:@" update Cookie set portList = ? where id = ? ", cookieProperties[NSHTTPCookiePort], cookieID])
            return whoopsie([db lastError]);
        
        
        
    }];
}







#pragma mark History Data Source




// Expects columns
// pageTitle, pageURL, visitedDate
- (NSArray *)_historyItemFromCurrentRowInResultSet:(FMResultSet *)row {
    NSString *pageTitle = [row stringForColumn:@"pageTitle"];
    NSString *pageURLString = [row stringForColumn:@"pageURL"];
    NSDate *visitedDate = [NSDate dateWithTimeIntervalSince1970:[row unsignedLongLongIntForColumn:@"visitedDate"]];
    
    // Threading! boo!
    //return [[WebHistoryItem alloc] initWithURLString:pageURLString title:pageTitle lastVisitedTimeInterval:[visitedDate timeIntervalSinceReferenceDate]];
    return @[pageURLString, pageTitle, visitedDate];
    
}


- (NSArray *)history {
    NSMutableArray *cum = [NSMutableArray array];
    [cookieJar inDatabase:^(FMDatabase *db) {
        FMResultSet *historyPtr = [db executeQuery:@""
                                   "   select  pageTitle, pageURL, visitedDate "
                                   "     from  HistoryItem "
                                   " order by  visitedDate asc "];  // Chronologically means oldest first
        
        while ([historyPtr next])
            [cum addObject:[self _historyItemFromCurrentRowInResultSet:historyPtr]];
        
    }];
    
    return cum;
    
}


- (NSArray *)historyBetweenDate:(NSDate *)startDate andDate:(NSDate *)endDate {
    NSUInteger startTime = (NSUInteger)[startDate timeIntervalSince1970];
    NSUInteger endTime = (NSUInteger)[endDate timeIntervalSince1970];
    
    NSMutableArray *cum = [NSMutableArray array];
    [cookieJar inDatabase:^(FMDatabase *db) {
        FMResultSet *historyPtr = [db executeQuery:@""
                                   "   select  pageTitle, pageURL, visitedDate "
                                   "     from  HistoryItem "
                                   "    where  visitedDate >= ? "
                                   "      and  visitedDate < ? "
                                   " order by  visitedDate asc ", @(startTime), @(endTime)];  // Chronologically; oldest first
        
        while ([historyPtr next])
            [cum addObject:[self _historyItemFromCurrentRowInResultSet:historyPtr]];
        
    }];
    
    return cum;
    
}


- (void)findHistoryItemsMatching:(NSString *)fuzzyPattern deliveringResultsToMainQueueByDoing:(void (^)(NSArray *results, BOOL *stop))resultsBlock {
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        
        NSArray *query = [self _lowercaseTokensInString:fuzzyPattern];
        
        [cookieJar inDatabase:^(FMDatabase *db) {
            FMResultSet *historyPtr = [db executeQuery:@""
                                       "   select  pageTitle, pageURL, visitedDate "
                                       "     from  HistoryItem "
                                       " order by  visitedDate desc "];  // We want the most recent (likely relevant) first, in this case.
            
            //
            // Collect <a number of> good results at a time.
            int bufCapacity = 5;
            NSMutableArray *rotatingResultsBuf = [NSMutableArray arrayWithCapacity:bufCapacity];
            __block BOOL shouldStop = NO;
            
            //
            // For each row...
            while ([historyPtr next]) {
                if (shouldStop)  break;  // Not threadsafe; just a boolean check, prob. won't set the printer on fire.
                
                NSString *pageTitle = [historyPtr stringForColumn:@"pageTitle"];
                NSString *pageURL = [historyPtr stringForColumn:@"pageURL"];
                
                NSUInteger matchQuality = ([self _matchScoreForCandidateTokens:[self _lowercaseTokensInString:pageTitle] againstQuery:query] +
                                           [self _matchScoreForCandidateTokens:[self _lowercaseTokensInString:pageURL]   againstQuery:query]   );
                if (!matchQuality)
                    continue;  // Ignore dud rows
                
                //
                // Collect this valid result:
                [rotatingResultsBuf addObject:@[ @(matchQuality), [self _historyItemFromCurrentRowInResultSet:historyPtr] ]];
                
                //
                // Once we've had a number of valid results, dispatch them off to the caller:
                if ([rotatingResultsBuf count] >= bufCapacity) {
                    NSArray *runningResults = [rotatingResultsBuf copy];
                    dispatch_async(dispatch_get_main_queue(), ^{
                        NSArray *webHistoryItemifiedResults = [runningResults mapUsingBlock:^id(NSArray *tuple) {
                            NSArray *webHistoryTuple = [tuple lastObject];
                            return @[[tuple firstObject], [[WebHistoryItem alloc] initWithURLString:webHistoryTuple[0]
                                                                                              title:webHistoryTuple[1]
                                                                            lastVisitedTimeInterval:[webHistoryTuple[2] timeIntervalSinceReferenceDate]]];
                        }];
                        resultsBlock(webHistoryItemifiedResults, &shouldStop);
                    });
                    
                    [rotatingResultsBuf removeAllObjects];
                    
                }
                
            }
            
            //
            // Send of the last trailing bits
            NSArray *lastResults = [rotatingResultsBuf copy];
            if ([lastResults count])
                dispatch_async(dispatch_get_main_queue(), ^{
                    NSArray *webHistoryItemifiedResults = [lastResults mapUsingBlock:^id(NSArray *tuple) {
                        NSArray *webHistoryTuple = [tuple lastObject];
                        return @[[tuple firstObject], [[WebHistoryItem alloc] initWithURLString:webHistoryTuple[0]
                                                                                          title:webHistoryTuple[1]
                                                                        lastVisitedTimeInterval:[webHistoryTuple[2] timeIntervalSinceReferenceDate]]];
                    }];
                    resultsBlock(webHistoryItemifiedResults, &shouldStop);
                });
            
            [historyPtr close];
            
        }];
        
    });
}


- (void)putHistoryItem:(WKBackForwardListItem *)item {
    NSString *urlString = [[item URL] absoluteString];
    NSString *title = [item title] ? [item title] : @"";
    NSUInteger visitedDate = (NSUInteger)[[NSDate date] timeIntervalSince1970];
    
    if (!urlString)
        return;
    
    [cookieJar inTransaction:^(FMDatabase *db, BOOL *rollback) {
        [db executeUpdate:@""
         " insert or replace into  HistoryItem (pageTitle, pageURL, visitedDate) "
         "                 values  (?, ?, ?) ", title, urlString, @(visitedDate)];
        
    }];
    
    if (arc4random_uniform(30) == 0)
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0), ^{
            [self _sweepHistoryItems];
        });
    
}


- (void)_sweepHistoryItems {
    NSUInteger oneYearAgo = (NSUInteger)[[NSDate dateWithTimeIntervalSinceNow:(-365.22 * 86400)] timeIntervalSince1970];
    
    [cookieJar inTransaction:^(FMDatabase *db, BOOL *rollback) {
        [db executeUpdate:@""
         " delete from  HistoryItem "
         "       where  visitedDate < ? ", @(oneYearAgo)];
        
    }];
    
}


- (void)deleteHistoryItemForURL:(NSURL *)url {
    [cookieJar inDatabase:^(FMDatabase *db) {
        [db executeUpdate:@""
         " delete from  HistoryItem "
         "       where  pageURL = ? ", [url absoluteString]];
    }];
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0), ^{
        [self _sweepHistoryItems];
    });
    
}



static NSCharacterSet *ei_wordBoundaryCharacters;
static dispatch_once_t ei_initWordBoundaries;
static const float ei_matchThreshold = 3/5.0;

- (NSArray *)_lowercaseTokensInString:(NSString *)input {
    dispatch_once(&ei_initWordBoundaries, ^{
        ei_wordBoundaryCharacters = [[NSCharacterSet alphanumericCharacterSet] invertedSet];
    });
    
    return [[[input componentsSeparatedByCharactersInSet:ei_wordBoundaryCharacters]
             filterUsingBlock:^BOOL(NSString *component) {
                 return !![component length];
             }] mapUsingBlock:^id(NSString *token) {
                 return [token lowercaseString];
             }];
    
}

- (NSUInteger)_matchScoreForCandidateTokens:(NSArray *)candidate againstQuery:(NSArray *)query {
    NSArray *lowercaseCandidate = [candidate mapUsingBlock:^id(NSString *tok) {  return [tok lowercaseString];  }];
    __block NSUInteger runningTotal = 0;
    
    NSArray *matchingParts = [[lowercaseCandidate mapUsingBlock:^id(NSString *candidateToken) {
        for (NSString *queryToken in query) {
            
            if ([candidateToken containsString:queryToken]) {
                if ([candidateToken hasPrefix:queryToken])
                    runningTotal++;             // +1 pt extra for prefix match
                
                return queryToken;
                
            }
            
        }
        return [NSNull null];
        
    }] filterUsingBlock:^BOOL(id stringOrNSNull) {
        return stringOrNSNull != [NSNull null];
    }];
    
    // Require a proportion of the query tokens to have been matched
    if ((float)[matchingParts count] / [query count] < ei_matchThreshold)
        return 0;
    
    runningTotal += [matchingParts count];      // +1 pt for each match above
    
    // TODO Account for candidates with duplicate tokens:
    if ([query isEqual:matchingParts])
        runningTotal += [query count];          // +1 pt for each token if match is in order
    
    return runningTotal;
    
}

















@end
