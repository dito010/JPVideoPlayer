// JRSwizzle.h semver:1.1.0
//   Copyright (c) 2007-2016 Jonathan 'Wolf' Rentzsch: http://rentzsch.com
//   Some rights reserved: http://opensource.org/licenses/mit
//   https://github.com/rentzsch/jrswizzle

#import <Foundation/Foundation.h>

@interface NSObject (JRSwizzle)

+ (BOOL)jp_swizzleMethod:(SEL)origSel_ withMethod:(SEL)altSel_ error:(NSError**)error_;
+ (BOOL)jp_swizzleClassMethod:(SEL)origSel_ withClassMethod:(SEL)altSel_ error:(NSError**)error_;

@end
