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

#import <Foundation/Foundation.h>
#import "JPVideoPlayerCompat.h"

NS_ASSUME_NONNULL_BEGIN

@interface JPVideoPlayerCacheConfiguration : NSObject

/**
 * The maximum length of time to keep an video in the cache, in seconds
 */
@property (assign, nonatomic) NSInteger maxCacheAge;

/**
 * The maximum size of the cache, in bytes.
 * If the cache Beyond this value, it will delete the video file by the cache time automatic.
 */
@property (assign, nonatomic) NSUInteger maxCacheSize;

/**
 *  disable iCloud backup [defaults to YES]
 */
@property (assign, nonatomic) BOOL shouldDisableiCloud;

@end

typedef NS_ENUM(NSInteger, JPVideoPlayerCacheType)   {
    
    /**
     * The video wasn't available the JPVideoPlayer caches.
     */
    JPVideoPlayerCacheTypeNone,

    /**
     * The video was obtained on the disk cache.
     */
    JPVideoPlayerCacheTypeExisted,

    /**
     * A location source.
     */
    JPVideoPlayerCacheTypeLocation
};

typedef void(^JPVideoPlayerCacheQueryCompletion)(NSString * _Nullable videoPath, JPVideoPlayerCacheType cacheType);

typedef void(^JPVideoPlayerCheckCacheCompletion)(BOOL isInDiskCache);

typedef void(^JPVideoPlayerCalculateSizeCompletion)(NSUInteger fileCount, NSUInteger totalSize);

/**
 * JPVideoPlayerCache maintains a disk cache. Disk cache write operations are performed
 * asynchronous so it doesn’t add unnecessary latency to the UI.
 */
@interface JPVideoPlayerCache : NSObject

#pragma mark - Singleton and initialization

/**
 *  Cache Config object - storing all kind of settings.
 */
@property (nonatomic, readonly) JPVideoPlayerCacheConfiguration *cacheConfiguration;

/**
 * Init with given cacheConfig.
 *
 * @see `JPVideoPlayerCacheConfig`.
 */
- (instancetype)initWithCacheConfiguration:(JPVideoPlayerCacheConfiguration * _Nullable)cacheConfiguration NS_DESIGNATED_INITIALIZER;

/**
 * Returns global shared cache instance.
 *
 * @return JPVideoPlayerCache global instance.
 */
+ (instancetype)sharedCache;

# pragma mark - Query and Retrieve Options
/**
 * Async check if video exists in disk cache already (does not load the video).
 *
 * @param key             The key describing the url.
 * @param completion      The block to be executed when the check is done.
 * @note the completion block will be always executed on the main queue.
 */
- (void)diskVideoExistsWithKey:(NSString *)key
                    completion:(JPVideoPlayerCheckCacheCompletion _Nullable)completion;

/**
 * Operation that queries the cache asynchronously and call the completion when done.
 *
 * @param key        The unique key used to store the wanted video.
 * @param completion The completion block. Will not get called if the operation is cancelled.
 */
- (void)queryCacheOperationForKey:(NSString *)key
                       completion:(JPVideoPlayerCacheQueryCompletion _Nullable)completion;

/**
 * Async check if video exists in disk cache already (does not load the video).
 *
 * @param path The path need to check in disk.
 *
 * @return If the file is existed for given video path, return YES, return NO, otherwise.
 */
- (BOOL)diskVideoExistsOnPath:(NSString *)path;

# pragma mark - Clear Cache Events

/**
 * Remove the video data from disk cache asynchronously
 *
 * @param key         The unique video cache key.
 * @param completion  A block that should be executed after the video has been removed (optional).
 */
- (void)removeVideoCacheForKey:(NSString *)key
                   completion:(dispatch_block_t _Nullable)completion;

/**
 * Async remove all expired cached video from disk. Non-blocking method - returns immediately.
 *
 * @param completion A block that should be executed after cache expiration completes (optional)
 */
- (void)deleteOldFilesOnCompletion:(dispatch_block_t _Nullable)completion;

/**
 * Async clear all disk cached videos. Non-blocking method - returns immediately.
 *
 * @param completion    A block that should be executed after cache expiration completes (optional).
 */
- (void)clearDiskOnCompletion:(dispatch_block_t _Nullable)completion;

/**
 * Async clear videos cache in disk on version 2.x.
 *
 * @param completion A block that should be executed after cache expiration completes (optional).
 */
- (void)clearVideoCacheOnVersion2OnCompletion:(dispatch_block_t _Nullable)completion;

# pragma mark - Cache Info

/**
 * To check is have enough free size in disk to cache file with given size.
 *
 * @param fileSize  the need to cache size of file.
 *
 * @return if the disk have enough size to cache the given size file, return YES, return NO otherwise.
 */
- (BOOL)haveFreeSizeToCacheFileWithSize:(NSUInteger)fileSize;

/**
 * Get the free size of device.
 *
 * @return the free size of device.
 */
- (unsigned long long)getDiskFreeSize;

/**
 * Get the size used by the disk cache, synchronously.
 */
- (unsigned long long)getSize;

/**
 * Get the number of images in the disk cache, synchronously.
 */
- (NSUInteger)getDiskCount;

/**
 * Calculate the disk cache's size, asynchronously .
 */
- (void)calculateSizeOnCompletion:(JPVideoPlayerCalculateSizeCompletion _Nullable)completion;

# pragma mark - File Name

/**
 *  Generate the video file's name for given key.
 *
 *  @return the file's name.
 */
- (NSString *)cacheFileNameForKey:(NSString *)key;

@end

@interface JPVideoPlayerCache(Deprecated)

/**
 * Remove the video data from disk cache asynchronously
 *
 * @param key             The unique video cache key.
 * @param completion      A block that should be executed after the video has been removed (optional).
 */
- (void)removeFullCacheForKey:(NSString *)key
                   completion:(dispatch_block_t _Nullable)completion JPDEPRECATED_ATTRIBUTE("`removeFullCacheForKey:completion:` is deprecated on 3.0.")

/**
 * Clear the temporary cache video for given key.
 *
 * @param key        The unique flag for the given url in this framework.
 * @param completion A block that should be executed after the video has been removed (optional).
 */
- (void)removeTempCacheForKey:(NSString *)key
                   completion:(nullable dispatch_block_t)completion JPDEPRECATED_ATTRIBUTE("`removeTempCacheForKey:completion:` is deprecated on 3.0.")

/**
 * Async delete all temporary cached videos. Non-blocking method - returns immediately.
 * @param completion    A block that should be executed after cache expiration completes (optional).
 */
- (void)deleteAllTempCacheOnCompletion:(dispatch_block_t _Nullable)completion JPDEPRECATED_ATTRIBUTE("`deleteAllTempCacheOnCompletion:` is deprecated on 3.0.");

@end

NS_ASSUME_NONNULL_END