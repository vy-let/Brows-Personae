//
//  PublicSuffixList.m
//  Brows Personæ
//
//  Created by Talus Baddley on 2015-2-27.
//  Copyright (c) 2015 Eightt. All rights reserved.
//

#import "PublicSuffixList.h"
#import <ReactiveCocoa/ReactiveCocoa.h>
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
    NSDate *startDate = [NSDate date];
    
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
    
    __block __weak void (^pcud)(NSArray *, NSMutableDictionary *);
    void (^putComponentsUnderDictionary)(NSArray *, NSMutableDictionary *) = ^(NSArray *components, NSMutableDictionary *tree) {
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
            pcud(rest, subtree);
            
        }
        
    };
    pcud = putComponentsUnderDictionary;
    
    
    publicSuffixes = [NSMutableDictionary dictionary];
    publicTrees = [NSMutableDictionary dictionary];
    privateExceptions = [NSMutableDictionary dictionary];
    [publicSuffixRules applyBlock:^(NSString *rule) {
        NSArray *components = [self domainLabels:rule];
        putComponentsUnderDictionary(components, publicSuffixes);
    }];
    [publicTreeRules applyBlock:^(NSString *rule) {
        // Omit the empty first component of glob-tree rules:
        NSArray *components = [[self domainLabels:rule] filterUsingBlock:^BOOL(NSString *roole) { return !![roole length]; }];
        putComponentsUnderDictionary(components, publicTrees);
    }];
    [privateExceptionRules applyBlock:^(NSString *rule) {
        NSArray *components = [self domainLabels:rule];
        putComponentsUnderDictionary(components, privateExceptions);
    }];
    
    
    
    NSLog(@"Loaded PSL rules in %f seconds.", -[startDate timeIntervalSinceNow]);
    
    // Uncomment to debug HI sluggishness:
    // NSLog(@"Waiting 3 seconds for dramatic effect..."); sleep(3);
    
    
}



#pragma mark Splitting



- (NSArray *)partition:(NSString *)domain {
    if (!domain)  domain = @"";  // A nil domain would cause a nil-in-array exception below.
    
    __block NSInteger (^idmc)(NSArray *, id);
    __block id matchingRuleComponent;
    NSInteger (^indexOfDeepestMatchingComponent)(NSArray *, id) = ^NSInteger(NSArray *components, id ruleParent) {
        
        if (![components count]) {
            matchingRuleComponent = ruleParent;
            return 0;  // Whole shebang is a public match
        }
        
        NSString *lastComponent = [components lastObject];
        NSArray *rest = [components subarrayWithRange:NSMakeRange(0, [components count] - 1)];
        
        if (![ruleParent respondsToSelector:@selector(objectForKey:)]) {
            matchingRuleComponent = ruleParent;
            return [components count];  // End of match
        }
        
        id rule = [ruleParent objectForKey:lastComponent];
        if (!rule) {
            matchingRuleComponent = ruleParent;
            return [components count];  // End of match
        }
        
        return idmc(rest, rule);
        
    };
    idmc = indexOfDeepestMatchingComponent;
    
    NSArray *domainComponents = [self domainLabels:domain];
    
    NSInteger shallowestPrivateIdex = indexOfDeepestMatchingComponent(domainComponents, privateExceptions) + 1;
    NSInteger publicTreeIdex = indexOfDeepestMatchingComponent(domainComponents, publicTrees);
    id publicMatchingComponent = matchingRuleComponent;
    
    NSInteger publicHeadIdex = indexOfDeepestMatchingComponent(domainComponents, publicSuffixes);
    
    NSInteger splitSpot = publicHeadIdex;
    
    if (shallowestPrivateIdex < splitSpot)
        splitSpot = shallowestPrivateIdex;
    if ([publicMatchingComponent isEqual:@1] && publicTreeIdex < shallowestPrivateIdex)
        splitSpot = 0;  // Public w/o exception => all public
    
    
    return [@[[domainComponents subarrayWithRange:NSMakeRange(0,         splitSpot)],
              [domainComponents subarrayWithRange:NSMakeRange(splitSpot, [domainComponents count] - splitSpot)]
              ]
            mapUsingBlock:^id(NSArray *components) { return [components componentsJoinedByString:@"."]; }];
}



- (BOOL)domainHasPublicSuffix:(NSString *)domain {
    return !![[[self partition:domain] lastObject] length];
}

- (BOOL)URLHasPublicSuffix:(NSURL *)url {
    return [self domainHasPublicSuffix:[url host]];
}


- (NSArray *)domainLabels:(NSString *)domain {
    return [domain componentsSeparatedByString:@"."];
}




@end
