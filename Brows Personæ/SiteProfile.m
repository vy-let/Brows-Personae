//
//  SiteProfile.m
//  Brows Personæ
//
//  Created by Taldar Baddley on 2014-10-12.
//  Copyright (c) 2014 Eightt. All rights reserved.
//

#import "SiteProfile.h"
#import <ReactiveCocoa/ReactiveCocoa.h>
#import <FMDB/FMDB.h>
#import "NSHTTPCookie+IGPropertyTesting.h"
#import <NSArray+Functional/NSArray+Functional.h>


const UInt32 SiteProfileStorePresentVersion = 1;
const UInt32 SiteProfileStoreApplicationID = 625418296;  // irb> rand 2**31


@interface SiteProfile () {
    NSURL *diskLocation;
    NSString *name;
    FMDatabaseQueue *cookieJar;
    u_int32_t presentSessionID;  // this type b/c of arc4random's behavior
    
    dispatch_queue_t backgroundCookieQueue;
    dispatch_once_t backgroundCookieSetup;
    RACSubject *cookieTouchPusher;  // Push arrays of cookies to update their last-used timestamps.
    NSMutableSet *cookiesNeedingTouching;
}

@end

@implementation SiteProfile


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


+ (instancetype)named:(NSString *)profileName {
    __block id result;
    
    dispatch_sync(profileSanity, ^{
        result = [namedProfiles objectForKey:profileName];
        if (!result) {
            NSString *profileFilename = [NSString stringWithFormat:@"%@.browspersona", profileName];
            result = [[[self class] alloc] initAtURL:[[[self class] mainProfileFolder] URLByAppendingPathComponent:profileFilename]
                                            withName:profileName];
            
            if (result)
                [namedProfiles setObject:result forKey:profileName];
        }
    });
    
    return result;
    
}



- (instancetype)initAtURL:(NSURL *)file withName:(NSString *)profileName {
    if (!(self = [super init])) return nil;
    
    diskLocation = file;
    name = [profileName copy];
    presentSessionID = arc4random();
    backgroundCookieQueue = dispatch_queue_create(NULL, DISPATCH_QUEUE_SERIAL);
    
    BOOL looseDatabaseIntegrity =
    [self openDatabase];
    
    if (!looseDatabaseIntegrity)  return nil;
    
    return self;
}


- (void)dealloc {
    FMDatabaseQueue *cookieTin = cookieJar;
    NSLog(@"Profile for %@ is being deallocated; db will vacuum shortly.", name);
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0), ^{
        [cookieTin inDatabase:^(FMDatabase *db) {
            [db executeUpdate:@"vacuum"];
        }];
        [cookieTin close];
    });
    
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
        
        [db executeUpdate:
         @"create table HistoryItem ("
         "    id            integer primary key"
         "  , previousItem  integer references HistoryItem (id) on delete set null"
         "  , pageTitle     text not null"
         "  , pageURL       text not null"
         "  , visitedDate   integer not null"
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
    // SQL-native solution proving to be too finickey for the time being.
    
    NSArray *applicableCookies = [[self cookies] filterUsingBlock:^BOOL(NSHTTPCookie *cookie) {
        return [cookie isForRequest:request];
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
    [cookieJar inTransaction:^(FMDatabase *db, BOOL *rollback) {
        
        [[[self cookies]
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


- (void)removeExpiredCookies {
    NSDate *expiry = [NSDate date];
    [cookieJar inDatabase:^(FMDatabase *db) {
        
        [db executeUpdate:@""
         " delete from  Cookie "
         "       where  expiresDate not null  and  expiresDate < ? ", expiry];
        
    }];
}


- (void)setCookie:(NSHTTPCookie *)cookie {
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
//        NSError *cookieDelError = nil;
//        BOOL success = [db executeUpdate:@""
//                        " delete from  Cookie     "
//                        "       where  name = ?   "
//                        "         and  domain = ? "
//                        "         and  path = ?   "
//                    withErrorAndBindings:&cookieDelError,  [cookie name], [cookie domain], [cookie path]];
//        
//        if (!success)
//            return whoopsie(cookieDelError);
        
        
        // Sometime soon, trim out old cookies
        // if the cookie jar grows too full:
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            [cookieJar inDatabase:^(FMDatabase *db) {
                
                for (;;) {
                    FMResultSet *domainCookies = [db executeQuery:@""
                                                  " select  count(id)  "
                                                  "   from  Cookie     "
                                                  "  where  domain = ? ", [cookie domain]];
                    [domainCookies next];
                    long domainCookieCount = [domainCookies longForColumnIndex:0];
                    [domainCookies close];
                    
                    FMResultSet *profileCookies = [db executeQuery:@""
                                                  " select  count(id)  "
                                                  "   from  Cookie     "];
                    [profileCookies next];
                    long profileCookieCount = [profileCookies longForColumnIndex:0];
                    [profileCookies close];
                    
                    
                    if (domainCookieCount <= 30 && profileCookieCount <= 300)
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
















@end
