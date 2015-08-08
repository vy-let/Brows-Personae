//
//  WebCache.h
//  Brows Personæ
//
//  Created by Violet Baddley on 2015-2-12.
//  Copyright (c) 2015 Eightt. All rights reserved.
//

// WebCache is not publicly exposed,
// so re-declare it and the appropriate messages
// will find their way there at runtime.
// Thanks http://www.artandlogic.com/blog/2013/10/bypass-the-webkit-cache/

// (AppController disables the WebCache on did-finish-launch.)

@interface WebCache : NSObject

+ (void)empty;
+ (void)setDisabled:(BOOL)arg1;

@end

