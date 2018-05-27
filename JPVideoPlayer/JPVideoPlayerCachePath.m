/*
 * This file is part of the JPVideoPlayer package.
 * (c) NewPan <13246884282@163.com>
 *
 * For the full copyright and license information, please view the LICENSE
 * file that was distributed with this source code.
 *
 * Click https://github.com/newyjp
 * or http://www.jianshu.com/users/e2f2d779c022/latest_articles to contact me.
 */

#import "JPVideoPlayerCachePath.h"
#import "JPVideoPlayerCache.h"

NSString * const JPVideoPlayerCacheVideoPathForTemporaryFile = @"/TemporaryFile";
NSString * const JPVideoPlayerCacheVideoPathForFullFile = @"/FullFile";

static NSString * const kJPVideoPlayerCacheVideoPathDomain = @"/com.jpvideoplayer.www";
static NSString * const kJPVideoPlayerCacheVideoFileExtension = @".mp4";
static NSString * const kJPVideoPlayerCacheVideoIndexFileExtension = @".index";
static NSString * const kJPVideoPlayerCacheVideoPlaybackRecordFileExtension = @".record";
@implementation JPVideoPlayerCachePath

#pragma mark - Public

+ (NSString *)videoCachePath {
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSString *path = [NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES).lastObject
            stringByAppendingPathComponent:kJPVideoPlayerCacheVideoPathDomain];
    if (![fileManager fileExistsAtPath:path]){
        [fileManager createDirectoryAtPath:path withIntermediateDirectories:YES attributes:nil error:nil];
    }
    return path;
}

+ (NSString *)videoCachePathForKey:(NSString *)key {
    NSParameterAssert(key);
    if (!key) {
        return nil;
    }
    NSString *videoCachePath = [self videoCachePath];
    NSParameterAssert(videoCachePath);
    NSString *filePath = [videoCachePath stringByAppendingPathComponent:[JPVideoPlayerCache.sharedCache cacheFileNameForKey:key]];
    NSParameterAssert(filePath);
    return filePath;
}

+ (NSString *)createVideoFileIfNeedThenFetchItForKey:(NSString *)key {
    NSString *filePath = [self videoCachePathForKey:key];
    if(!filePath){
        return nil;
    }
    NSFileManager *fileManager = [NSFileManager defaultManager];
    if (![fileManager fileExistsAtPath:filePath]) {
        [fileManager createFileAtPath:filePath contents:nil attributes:nil];
    }
    return filePath;
}

+ (NSString *)videoCacheIndexFilePathForKey:(NSString *)key {
    NSParameterAssert(key);
    if (!key) {
        return nil;
    }
    NSString *videoCachePath = [self videoCachePath];
    NSParameterAssert(videoCachePath);
    NSString *filePath = [videoCachePath stringByAppendingPathComponent:[JPVideoPlayerCache.sharedCache cacheFileNameForKey:key]];
    filePath = [filePath stringByAppendingString:kJPVideoPlayerCacheVideoIndexFileExtension];
    NSParameterAssert(filePath);
    return filePath;
}

+ (NSString *)createVideoIndexFileIfNeedThenFetchItForKey:(NSString *)key {
    NSString *filePath = [self videoCacheIndexFilePathForKey:key];
    if(!filePath){
        return nil;
    }
    NSFileManager *fileManager = [NSFileManager defaultManager];
    if (![fileManager fileExistsAtPath:filePath]) {
        [fileManager createFileAtPath:filePath contents:nil attributes:nil];
    }
    return filePath;
}

+ (NSString *)videoPlaybackRecordFilePath {
    NSString *filePath = [self videoCachePath];
    if(!filePath){
        return nil;
    }
    filePath = [filePath stringByAppendingPathComponent:kJPVideoPlayerCacheVideoPlaybackRecordFileExtension];
    NSFileManager *fileManager = [NSFileManager defaultManager];
    if (![fileManager fileExistsAtPath:filePath]) {
        [fileManager createFileAtPath:filePath contents:nil attributes:nil];
    }
    return filePath;
}

@end

@implementation JPVideoPlayerCachePath(Deprecated)

+ (NSString *)videoCacheTemporaryPathForKey:(NSString * _Nonnull)key{
    NSParameterAssert(key);
    if (!key) {
        return nil;
    }

    NSString *path = [self getFilePathWithAppendingString:JPVideoPlayerCacheVideoPathForTemporaryFile];
    path = [path stringByAppendingPathComponent:[JPVideoPlayerCache.sharedCache cacheFileNameForKey:key]];
    path = [path stringByAppendingString:kJPVideoPlayerCacheVideoFileExtension];
    NSFileManager *fileManager = [NSFileManager defaultManager];
    if (![fileManager fileExistsAtPath:path]) {
        [fileManager createFileAtPath:path contents:nil attributes:nil];
    }
    return path;
}

+ (NSString *)videoCacheFullPathForKey:(NSString * _Nonnull)key{
    NSParameterAssert(key);
    if (!key) {
        return nil;
    }

    NSString *path = [self getFilePathWithAppendingString:JPVideoPlayerCacheVideoPathForFullFile];
    NSString *fileName = [[JPVideoPlayerCache.sharedCache cacheFileNameForKey:key]
            stringByAppendingString:kJPVideoPlayerCacheVideoFileExtension];
    path = [path stringByAppendingPathComponent:fileName];
    return path;
}

+ (NSString *)videoCachePathForAllTemporaryFile{
    return [self getFilePathWithAppendingString:JPVideoPlayerCacheVideoPathForTemporaryFile];
}

+ (NSString *)videoCachePathForAllFullFile{
    return [self getFilePathWithAppendingString:JPVideoPlayerCacheVideoPathForFullFile];
}

+ (NSString *)getFilePathWithAppendingString:(nonnull NSString *)apdStr{
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSString *path = [NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES).lastObject
            stringByAppendingPathComponent:apdStr];
    if (![fileManager fileExistsAtPath:path]){
        [fileManager createDirectoryAtPath:path withIntermediateDirectories:YES attributes:nil error:nil];
    }
    return path;
}

@end
