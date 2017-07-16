/*
 * This file is part of the JPVideoPlayer package.
 * (c) NewPan <13246884282@163.com>
 *
 * For the full copyright and license information, please view the LICENSE
 * file that was distributed with this source code.
 *
 * Click https://github.com/Chris-Pan
 * or http://www.jianshu.com/users/e2f2d779c022/latest_articles to contact me.
 */


#import "JPVideoPlayerCachePathTool.h"
#import "JPVideoPlayerCache.h"

NSString * const JPVideoPlayerCacheVideoPathForTemporaryFile = @"/TemporaryFile";
NSString * const JPVideoPlayerCacheVideoPathForFullFile = @"/FullFile";

@implementation JPVideoPlayerCachePathTool

#pragma mark - Public

+(nonnull NSString *)videoCachePathForAllTemporaryFile{
    return [self getFilePathWithAppendingString:JPVideoPlayerCacheVideoPathForTemporaryFile];
}

+(nonnull NSString *)videoCachePathForAllFullFile{
    return [self getFilePathWithAppendingString:JPVideoPlayerCacheVideoPathForFullFile];
}

+(nonnull NSString *)videoCacheTemporaryPathForKey:(NSString * _Nonnull)key{
    NSString *path = [self videoCachePathForAllTemporaryFile];
    if (path.length!=0) {
        NSFileManager *fileManager = [NSFileManager defaultManager];
        path = [path stringByAppendingPathComponent:[[JPVideoPlayerCache sharedCache] cacheFileNameForKey:key]];
        if (![fileManager fileExistsAtPath:path]) {
            [fileManager createFileAtPath:path contents:nil attributes:nil];
            // For Test
            // printf("Create temporary file");
        }
    }
    return path;
}

+(nonnull NSString *)videoCacheFullPathForKey:(NSString * _Nonnull)key{
    NSString *path = [self videoCachePathForAllFullFile];
    path = [path stringByAppendingPathComponent:[[JPVideoPlayerCache sharedCache] cacheFileNameForKey:key]];
    return path;
}


#pragma mark - Private

+(nonnull NSString *)getFilePathWithAppendingString:(nonnull NSString *)apdStr{
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSString *path = [NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES).lastObject stringByAppendingString:apdStr];
    
    if (![fileManager fileExistsAtPath:path])
        [fileManager createDirectoryAtPath:path withIntermediateDirectories:YES attributes:nil error:nil];
    
    return path;
}

@end
