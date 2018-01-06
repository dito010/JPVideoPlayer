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

static NSString * const kJPVideoPlayerCacheVideoPathDomain = @"/com.jpvideoplayer.www";
static NSString * const kJPVideoPlayerCacheVideoPathForTemporaryFileNewVersion = @"/temporaryFile";
static NSString * const kJPVideoPlayerCacheVideoPathForFullFileNewVersion = @"/fullFile";
static NSString *const kJPVideoPlayerCacheModelKey = @"com.jpvideoplayer.cache.model.www";
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

+ (NSString *)videoCacheModelsSavePathForKey:(NSString *)key {
    NSParameterAssert(key);
    if (!key) {
        return nil;
    }
    
    return [[JPVideoPlayerCachePathManager videoCacheTemporaryPathForKey:key] stringByAppendingPathComponent:kJPVideoPlayerCacheModelKey];
}

+(nullable NSString *)videoCacheTemporaryPathForKey:(NSString * _Nonnull)key{
    NSParameterAssert(key);
    if (!key) {
        return nil;
    }
    
    NSString *path = [self newVideoCachePathForAllTemporaryFile];
    path = [path stringByAppendingPathComponent:[JPVideoPlayerCache.sharedCache cacheFileNameForKey:key]];
    NSFileManager *fileManager = [NSFileManager defaultManager];
    if (![fileManager fileExistsAtPath:path]) {
        [fileManager createDirectoryAtPath:path withIntermediateDirectories:YES attributes:nil error:nil];
    }
    return path;
}

+(nullable NSString *)videoCacheFullPathForKey:(NSString * _Nonnull)key{
    NSParameterAssert(key);
    if (!key) {
        return nil;
    }
    
    NSString *path = [self newVideoCachePathForAllFullFile];
    NSString *fileName = [[JPVideoPlayerCache.sharedCache cacheFileNameForKey:key] stringByAppendingString:@".mp4"];
    path = [path stringByAppendingPathComponent:fileName];
    return path;
}


#pragma mark - Private

+(nonnull NSString *)newGetFilePathWithAppendingString:(nonnull NSString *)apdStr {
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSString *path = [NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES).lastObject stringByAppendingPathComponent:kJPVideoPlayerCacheVideoPathDomain];
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
    NSString *path = [NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES).lastObject stringByAppendingPathComponent:apdStr];
    
    if (![fileManager fileExistsAtPath:path]){
        [fileManager createDirectoryAtPath:path withIntermediateDirectories:YES attributes:nil error:nil];
    }
    
    return path;
}

@end
