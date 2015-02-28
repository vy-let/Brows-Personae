//
//  PublicSuffixList.m
//  Brows Personæ
//
//  Created by Talus Baddley on 2015-2-27.
//  Copyright (c) 2015 Eightt. All rights reserved.
//

#import "PublicSuffixList.h"
#import <NSString+Ruby/NSString+Ruby.h>
#import <NSArray+Functional/NSArray+Functional.h>



@interface PublicSuffixList () {
    NSMutableDictionary *publicSuffixes;
    NSMutableDictionary *publicTrees;
    NSMutableDictionary *privateExceptions;
}
- (instancetype)initSecretly;
@end

@implementation PublicSuffixList

#pragma mark Singleton

static PublicSuffixList *ei_PSLSingleton = nil;
static dispatch_once_t ei_didMakePSLSingleton;
static dispatch_block_t ei_mkPSLSingleton = ^{
    ei_PSLSingleton = [[PublicSuffixList alloc] initSecretly];
};

- (instancetype)initSecretly {
    if (!(self = [super init])) return nil;
    
    [self loadRules];
    
    return self;
}

- (instancetype)init {
    return nil;
}

+ (instancetype)suffixList {
    dispatch_once(&ei_didMakePSLSingleton, ei_mkPSLSingleton);
    return ei_PSLSingleton;
}



#pragma mark Parsing



- (void)loadRules {
    NSString *pslFile = [[NSString alloc] initWithContentsOfURL:[[NSBundle mainBundle] URLForResource:@"PSL" withExtension:@"txt"]
                                                       encoding:NSUTF8StringEncoding
                                                          error:NULL];
    
    // Take each non-empty line up to the first whitespace or //comment indication
    NSArray *protoRules = [[pslFile componentsSeparatedByString:@"\n"] mapUsingBlock:^id(NSString *line) {
        NSString *preComment = [[line partition:@"//"] objectAtIndex:0];
        return [[preComment partition:@"\\s+"] objectAtIndex:0];
    }];
    
    id (^prefixTrimmer)(NSString *protoRule) = ^id(NSString *rule) { return [rule substringFromIndex:1]; };
    
    NSArray *publicSuffixRules = [protoRules filterUsingBlock:^BOOL(NSString *protoRule) {
        return [protoRule length] && ![protoRule hasPrefix:@"!"] && ![protoRule hasPrefix:@"*"];
    }];
    
    NSArray *publicTreeRules = [[protoRules filterUsingBlock:^BOOL(NSString *protoRule) {
        return [protoRule hasPrefix:@"*"];
    }] mapUsingBlock:prefixTrimmer];
    
    NSArray *privateExceptionRules = [[protoRules filterUsingBlock:^BOOL(NSString *protoRule) {
        return [protoRule hasPrefix:@"!"];
    }] mapUsingBlock:prefixTrimmer];
    
    
    NSNumber *placeholder = @YES;
    
    __block void (^putComponentsUnderDictionary)(NSArray *, NSMutableDictionary *);
    putComponentsUnderDictionary = ^(NSArray *components, NSMutableDictionary *tree) {
        NSString *lastComponent = [components lastObject];
        NSArray *rest = [components subarrayWithRange:NSMakeRange(0, [components count] - 1)];
        if (!lastComponent) return;  // Safety valve
        
        id node = [tree objectForKey:lastComponent];
        
        // If lastComponent not in the tree, add it.
        if (!node) {
            node = placeholder;
            [tree setObject:placeholder forKey:lastComponent];
        }
        
        // Is there more to go?
        if ([rest count]) {
            
            // Swap a leaf with a branch, if necessary:
            if (![node respondsToSelector:@selector(setObject:forKey:)]) {
                node = [NSMutableDictionary dictionary];
                [tree setObject:node forKey:lastComponent];
            }
            
            NSMutableDictionary *subtree = node;
            putComponentsUnderDictionary(rest, subtree);
            
        }
        
    };
    
    
    publicSuffixes = [NSMutableDictionary dictionary];
    publicTrees = [NSMutableDictionary dictionary];
    privateExceptions = [NSMutableDictionary dictionary];
    [publicSuffixRules applyBlock:^(NSString *rule) {
        NSArray *components = [rule componentsSeparatedByString:@"."];
        putComponentsUnderDictionary(components, publicSuffixes);
    }];
    [publicTreeRules applyBlock:^(NSString *rule) {
        NSArray *components = [rule componentsSeparatedByString:@"."];
        putComponentsUnderDictionary(components, publicTrees);
    }];
    [privateExceptionRules applyBlock:^(NSString *rule) {
        NSArray *components = [rule componentsSeparatedByString:@"."];
        putComponentsUnderDictionary(components, privateExceptions);
    }];
    
    
    NSLog(@"PSL\nsuffixes %@\ntrees %@\nexceptions %@", publicSuffixes, publicTrees, privateExceptions);
    
    
}



#pragma mark Splitting



- (NSArray *)split:(NSString *)domain {
    return nil;
}


- (NSArray *)domainLabels:(NSString *)domain {
    return [domain componentsSeparatedByString:@"."];
}




@end
