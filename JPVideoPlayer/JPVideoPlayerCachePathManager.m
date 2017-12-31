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


#import "JPVideoPlayerCachePathManager.h"
#import "JPVideoPlayerCache.h"

NSString * const JPVideoPlayerCacheVideoPathForTemporaryFile = @"/TemporaryFile";
NSString * const JPVideoPlayerCacheVideoPathForFullFile = @"/FullFile";

NSString * const kJPVideoPlayerCacheVideoPathDomain = @"/com.jpvideoplayer.www";
NSString * const kJPVideoPlayerCacheVideoPathForTemporaryFileNewVersion = @"/temporaryFile";
NSString * const kJPVideoPlayerCacheVideoPathForFullFileNewVersion = @"/fullFile";

@implementation JPVideoPlayerCachePathManager

#pragma mark - Public

+(nonnull NSString *)videoCachePathForAllTemporaryFile{
    return [self getFilePathWithAppendingString:JPVideoPlayerCacheVideoPathForTemporaryFile];
}

+(nonnull NSString *)videoCachePathForAllFullFile{
    return [self getFilePathWithAppendingString:JPVideoPlayerCacheVideoPathForFullFile];
}

+ (NSString *)newVideoCachePathForAllFullFile {
    return [self newGetFilePathWithAppendingString:kJPVideoPlayerCacheVideoPathForFullFileNewVersion];
}

+ (NSString *)newVideoCachePathForAllTemporaryFile {
    return [self newGetFilePathWithAppendingString:kJPVideoPlayerCacheVideoPathForTemporaryFileNewVersion];
}

+(nonnull NSString *)videoCacheTemporaryPathForKey:(NSString * _Nonnull)key{
    NSString *path = [self newVideoCachePathForAllTemporaryFile];
    path = [path stringByAppendingPathComponent:[JPVideoPlayerCache.sharedCache cacheFileNameForKey:key]];
    NSFileManager *fileManager = [NSFileManager defaultManager];
    if (![fileManager fileExistsAtPath:path]) {
        [fileManager createDirectoryAtPath:path withIntermediateDirectories:YES attributes:nil error:nil];
    }
    return path;
}

+(nonnull NSString *)videoCacheFullPathForKey:(NSString * _Nonnull)key{
    NSString *path = [self newVideoCachePathForAllFullFile];
    path = [path stringByAppendingPathComponent:[JPVideoPlayerCache.sharedCache cacheFileNameForKey:key]];
    return path;
}


#pragma mark - Private

+(nonnull NSString *)newGetFilePathWithAppendingString:(nonnull NSString *)apdStr {
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSString *path = [NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES).lastObject stringByAppendingString:kJPVideoPlayerCacheVideoPathDomain];
    if (![fileManager fileExistsAtPath:path]){
        [fileManager createDirectoryAtPath:path withIntermediateDirectories:YES attributes:nil error:nil];
    }
    
    path = [path stringByAppendingString:apdStr];
    if (![fileManager fileExistsAtPath:path]){
        [fileManager createDirectoryAtPath:path withIntermediateDirectories:YES attributes:nil error:nil];
    }
    
    return path;
}

+(nonnull NSString *)getFilePathWithAppendingString:(nonnull NSString *)apdStr{
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSString *path = [NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES).lastObject stringByAppendingString:apdStr];
    
    if (![fileManager fileExistsAtPath:path]){
        [fileManager createDirectoryAtPath:path withIntermediateDirectories:YES attributes:nil error:nil];
    }
    
    return path;
}

@end
