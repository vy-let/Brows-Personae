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


const NSUInteger SiteProfileStorePresentVersion = 1;
const NSUInteger SiteProfileStoreApplicationID = 3503103293;  // irb> rand 2**32


@interface SiteProfile () {
    NSURL *diskLocation;
    NSString *name;
    FMDatabaseQueue *cookieJar;
    NSUInteger presentSessionID;
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
    
    BOOL looseDatabaseIntegrity =
    [self openDatabase];
    
    if (!looseDatabaseIntegrity)  return nil;
    
    return self;
}


- (void)dealloc {
    FMDatabaseQueue *cookieTin = cookieJar;
    NSLog(@"Should finalize cookie jar in %@", name);
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0), ^{
        NSLog(@"Will finalize cookie jar in %@", name);
        [cookieTin inDatabase:^(FMDatabase *db) {
            [db executeUpdate:@"vacuum"];
        }];
        [cookieTin close];
        NSLog(@"Did finalize cookie jar in %@", name);
    });
    
}



- (BOOL)openDatabase {
    cookieJar = [FMDatabaseQueue databaseQueueWithPath:[diskLocation path]];
    
    BOOL success =
    [self migrateCookieJarIfNecessary];
    
    if (!success)  return NO;
    
    
    return YES;
}

- (BOOL)migrateCookieJarIfNecessary {
    // Presently just check to see if db is empty and create tables.
    __block BOOL worked = YES;
    
    [cookieJar inDatabase:^(FMDatabase *db) {
        [db executeStatements:@"pragma encoding = \"UTF-8\";"
        "pragma journal_mode = WAL;"
        "pragma checkpoint_fullfsync = yes;"];
    }];
    
    [cookieJar inTransaction:^(FMDatabase *db, BOOL *rollback) {
        
        // Check to see if database is empty
        FMResultSet *nonEmptyAnswer = [db executeQuery:@"select count(*) from sqlite_master where type = 'table' and name = 'BrowsPersonæDataVersion'"];
        [nonEmptyAnswer next];  if ([nonEmptyAnswer intForColumnIndex:0] != 0) {
            
            // Non-empty. Check the version number
            FMResultSet *dataVersionAnswer = [db executeQuery:@"select version from BrowsPersonæDataVersion"];  [dataVersionAnswer next];
            
            if ([dataVersionAnswer intForColumnIndex:0] > SiteProfileStorePresentVersion) {
                // Too new
                NSLog(@"Using a version of the brows profile that's too new! Abort! Abort!");
                *rollback = YES; worked = NO;
                return;
                
            } else {
                // Version is good; OK to go.
                return;
            }
            
        }
        
        // Database needs initialization
        
        [db executeStatements:
         @"create table BrowsPersonæDataVersion (version integer);"
         "insert into BrowsPersonæDataVersion (version) values (1);"];
        
        [db executeStatements:
         @"create table Session ("
         "    id        integer primary key"
         "  , lastUsed  datetime"
         ");"];
        presentSessionID = [db lastInsertRowId];
        
        [db executeUpdate:
         @"create table Cookie ("
         "    id          integer primary key"
         "  , session     integer references Session (id) on delete cascade"
         // Critical attributes
         "  , path        text not null"
         "  , name        text not null"
         "  , value       text not null"
         "  , domain      text"  // or
         "  , originURL   text"
         "  , expiresDate text"  // or
         "  , maximumAge  integer"
         // Other attributes
         "  , comment     text"
         "  , commentURL  text"
         "  , secure      integer not null default 0"
         "  , sessionOnly integer not null default 0"
         "  , portList    text"
         "  , version     integer not null default 0"
         ")"];
        
        [db executeUpdate:
         @"create table HistoryItem ("
         "    id            integer primary key"
         "  , previousItem  integer references HistoryItem (id) on delete set null"
         "  , pageTitle     text not null"
         "  , pageURL       text not null"
         "  , visitedDate   text not null"
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








@end
