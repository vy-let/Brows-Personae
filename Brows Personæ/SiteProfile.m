//
//  SiteProfile.m
//  Brows Personæ
//
//  Created by Taldar Baddley on 2014-10-12.
//  Copyright (c) 2014 Eightt. All rights reserved.
//

#import "SiteProfile.h"

@interface SiteProfile () {
    NSURL *diskLocation;
    NSString *name;
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
        
        profiles = [applicationSupport URLByAppendingPathComponent:@"Profiles" isDirectory:YES];
        
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
            
            [namedProfiles setObject:result forKey:profileName];
        }
    });
    
    return result;
    
}



- (instancetype)initAtURL:(NSURL *)file withName:(NSString *)profileName {
    if (!(self = [super init])) return nil;
    
    diskLocation = file;
    name = [profileName copy];
    
    return self;
}



- (NSString *)name {
    return name;
}








@end
