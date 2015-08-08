//
//  Helpies.m
//  Brows Personæ
//
//  Created by Violet Baddley on 2015-2-10.
//  Copyright (c) 2015 Eightt. All rights reserved.
//

#import "Helpies.h"
#import "PublicSuffixList.h"

static NSRegularExpression *urlDetector, *nakedDomainDetector, *justWhitespaceDetector;
static dispatch_once_t haveURLDetectorsBeenSet;
static dispatch_block_t regexpInitialator = ^{
    // This is John Gruber’s global URL detector, anchored to match against the entire string only.
    // See https://gist.github.com/gruber/249502
    urlDetector = [[NSRegularExpression alloc] initWithPattern:@"^(?:[a-z][\\w-]+:(?:/{1,3}|[a-z0-9%])|www\\d{0,3}[.]|[a-z0-9.\\-]+[.][a-z]{2,4}/)(?:[^\\s()<>]+|\\(([^\\s()<>]+|(\\([^\\s()<>]+\\)))*\\))+(?:\\(([^\\s()<>]+|(\\([^\\s()<>]+\\)))*\\)|[^\\s`!()\\[\\]{};:'\".,<>?«»“”‘’])$"
                                                       options:NSRegularExpressionCaseInsensitive
                                                         error:NULL];
    
    // This is a modified sub-match of Gruber’s web-URL detector (the second, simplified part that omits the scheme check).
    // Anchored to match the entire string only, and matches 2..13 word characters as a TLD instead of matching a fixed list.
    // See https://gist.github.com/gruber/8891611
    nakedDomainDetector = [[NSRegularExpression alloc] initWithPattern:@"^(?:(?<!@)[a-z0-9]+(?:[.\\-][a-z0-9]+)*[.](?:\\w{2,13})\\b/?(?!@))$"
                                                               options:NSRegularExpressionCaseInsensitive
                                                                 error:NULL];
    
    justWhitespaceDetector = [[NSRegularExpression alloc] initWithPattern:@"^\\s+$"
                                                                  options:0
                                                                    error:NULL];
    
};




NSURL *urlForLocation(NSString *location, BOOL *protocolInferred, BOOL *isSearch) {
    
    void (^setOutparams)(BOOL, BOOL) = ^(BOOL protocolWasInf, BOOL wasSearch) {
        if (protocolInferred)
            *protocolInferred = protocolWasInf;
        if (isSearch)
            *isSearch = wasSearch;
    };
    
    if (isBasicallyEmpty(location)) {
        setOutparams(NO, NO);
        return nil;
    }
    
    
    if (isProbablyURLWithScheme(location)) {
        setOutparams(NO, NO);
        return [NSURL URLWithString:location];
        
    } else if (isProbablyNakedURL(location)) {
        setOutparams(YES, NO);
        return [NSURL URLWithString:[@"http://" stringByAppendingString:location]];
        
    } else {
        // If it's not a URL-looking thing, or if it's not actually parseable as a URL,
        // either way, take it to be a search.
        setOutparams(NO, YES);
        return searchEngineURLForQuery(location);

    }
    
}





BOOL isProbablyURLWithScheme(NSString *request) {
    dispatch_once(&haveURLDetectorsBeenSet, regexpInitialator);
    if ([urlDetector numberOfMatchesInString:request
                                     options:NSMatchingAnchored
                                       range:NSMakeRange(0, [request length])]
        > 0) {
        
        // Probably, so check for a known public suffix:
        return [[PublicSuffixList suffixList] URLHasPublicSuffix:[NSURL URLWithString:request]];
        
    }
    
    return NO;
    
}

BOOL isProbablyNakedURL(NSString *request) {
    dispatch_once(&haveURLDetectorsBeenSet, regexpInitialator);
    if ([nakedDomainDetector numberOfMatchesInString:request
                                             options:NSMatchingAnchored
                                               range:NSMakeRange(0, [request length])]
        > 0) {
        
        // Probably, so check for a known public suffix:
        NSURL *requestURL = [NSURL URLWithString:[@"http://" stringByAppendingString:request]];
        return [[PublicSuffixList suffixList] URLHasPublicSuffix:requestURL];
        
    }
    
    return NO;
    
}

BOOL isBasicallyEmpty(NSString *ipnuts) {
    dispatch_once(&haveURLDetectorsBeenSet, regexpInitialator);
    return [ipnuts length] < 1 ||
        [justWhitespaceDetector numberOfMatchesInString:ipnuts
                                                options:NSMatchingAnchored
                                                  range:NSMakeRange(0, [ipnuts length])]
            > 0;
    
}

NSURL *searchEngineURLForQuery(NSString *query) {
    // TODO check this
    // TODO support dynamic search engine replacement
    return [NSURL URLWithString:
            [NSString stringWithFormat:@"https://www.google.com/search?client=safari&rls=en&q=%@&ie=UTF-8&oe=UTF-8",
             [query stringByAddingPercentEncodingWithAllowedCharacters:[NSCharacterSet URLQueryAllowedCharacterSet]]
             ]
            ];
}

