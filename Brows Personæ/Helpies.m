//
//  Helpies.m
//  Brows Personæ
//
//  Created by Talus Baddley on 2015-2-10.
//  Copyright (c) 2015 Eightt. All rights reserved.
//

#import "Helpies.h"

static NSRegularExpression *urlDetector, *nakedDomainDetector;
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
    
};


BOOL isProbablyURLWithScheme(NSString *request) {
    dispatch_once(&haveURLDetectorsBeenSet, regexpInitialator);
    return [urlDetector numberOfMatchesInString:request
                                        options:NSMatchingAnchored
                                          range:NSMakeRange(0, [request length])]
            > 0;
    
}

BOOL isProbablyNakedURL(NSString *request) {
    dispatch_once(&haveURLDetectorsBeenSet, regexpInitialator);
    return [nakedDomainDetector numberOfMatchesInString:request
                                                options:NSMatchingAnchored
                                                  range:NSMakeRange(0, [request length])]
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

