//
//  Helpies.h
//  
//
//  Created by Violet Baddley on 2015-2-10.
//
//

#import <Cocoa/Cocoa.h>

NSURL *urlForLocation(NSString *location, BOOL *protocolInferred, BOOL *isSearch);

BOOL isProbablyURLWithScheme(NSString *);
BOOL isProbablyNakedURL(NSString *);
BOOL isBasicallyEmpty(NSString *);
NSURL *searchEngineURLForQuery(NSString *);

