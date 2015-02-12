//
//  Helpies.h
//  
//
//  Created by Talus Baddley on 2015-2-10.
//
//

#import <Cocoa/Cocoa.h>

BOOL isProbablyURLWithScheme(NSString *);
BOOL isProbablyNakedURL(NSString *);
BOOL isBasicallyEmpty(NSString *);
NSURL *searchEngineURLForQuery(NSString *);

