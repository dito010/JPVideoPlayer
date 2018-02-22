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

#import <Foundation/Foundation.h>
#import "JPVideoPlayerCompat.h"

@interface JPVideoPlayerCacheConfig : NSObject

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

@class JPVideoPlayerCacheConfig;

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSInteger, JPVideoPlayerCacheType) {
    
    /**
     * The video wasn't available the JPVideoPlayer caches, but was downloaded from the web.
     */
    JPVideoPlayerCacheTypeNone,
    
    /**
     * The video was obtained from the disk cache.
     */
    JPVideoPlayerCacheTypeDisk,
    
    /**
     * The video was obtained from local file.
     */
    JPVideoPlayerCacheTypeLocation,
    
    /**
     * The video was from web.
     */
    JPVideoPlayerCacheTypeWeb
};

typedef void(^JPVideoPlayerCacheQueryCompletion)(NSString * _Nullable videoPath, JPVideoPlayerCacheType cacheType);

typedef void(^JPVideoPlayerCheckCacheCompletion)(BOOL isInDiskCache);

typedef void(^JPVideoPlayerCalculateSizeCompletion)(NSUInteger fileCount, NSUInteger totalSize);

typedef void(^JPStoreDataCompletion)(NSString *key,
                                        NSUInteger storedSize,
                                        NSString * _Nullable tempVideoCachePath,
                                        NSString * _Nullable fullVideoCachePath,
                                        NSError * _Nullable error);

typedef void(^JPStoreExpectedSizeCompletion)(NSString *key,
                                             NSUInteger expectedSize,
                                             NSError * _Nullable error);

/**
 * JPVideoPlayerCache maintains a disk cache. Disk cache write operations are performed
 * asynchronous so it doesn’t add unnecessary latency to the UI.
 */
@interface JPVideoPlayerCache : NSObject

#pragma mark - Singleton and initialization

/**
 *  Cache Config object - storing all kind of settings.
 */
@property (nonatomic, nonnull, readonly)JPVideoPlayerCacheConfig *config;

/**
 * Init with given cacheConfig.
 *
 * @see `JPVideoPlayerCacheConfig`.
 */
- (instancetype)initWithCacheConfig:(JPVideoPlayerCacheConfig * _Nullable)cacheConfig NS_DESIGNATED_INITIALIZER;

/**
 * Returns global shared cache instance.
 *
 * @return JPVideoPlayerCache global instance.
 */
+ (nonnull instancetype)sharedCache;


# pragma mark - Store Video Options

/**
 * Store expected size for given key.
 *
 * @param expectedSize The length of data.
 * @param key          The unique video cache key, usually it's video absolute URL
 * @param completion   A block executed after the operation is finished.
 */
- (void)storeExpectedSize:(NSUInteger)expectedSize
                   forKey:(nullable NSString *)key
               completion:(JPStoreExpectedSizeCompletion)completion;

/**
 * Asynchronously store a piece of video data into disk for the given key.
 *
 * @param videoData       The video data as returned by the server, it is a piece of full video file.
 * @param expectedSize    The length of data.
 * @param key             The unique video cache key, usually it's video absolute URL
 * @param completionBlock A block executed after the operation is finished.
 */
- (void)storeVideoData:(nullable NSData *)videoData
          expectedSize:(NSUInteger)expectedSize
                forKey:(nullable NSString *)key
            completion:(nullable JPStoreDataCompletion)completionBlock;

/**
 * Reset cache when store data finished.
 */
- (void)reset;


# pragma mark - Query and Retrieve Options
/**
 * Async check if video exists in disk cache already (does not load the video).
 *
 * @param key             the key describing the url.
 * @param completionBlock the block to be executed when the check is done.
 * @note the completion block will be always executed on the main queue.
 */
- (void)diskVideoExistsWithKey:(nullable NSString *)key completion:(nullable JPVideoPlayerCheckCacheCompletion)completionBlock;

/**
 * Operation that queries the cache asynchronously and call the completion when done.
 *
 * @param key       The unique key used to store the wanted video.
 * @param doneBlock The completion block. Will not get called if the operation is cancelled.
 *
 * @return a NSOperation instance containing the cache options.
 */
- (nullable NSOperation *)queryCacheOperationForKey:(nullable NSString *)key done:(nullable JPVideoPlayerCacheQueryCompletion)doneBlock;

/**
 * Async check if video exists in disk cache already (does not load the video).
 *
 * @param fullVideoCachePath the path need to check in disk.
 *
 * @return if the file is existed for given video path, return YES, return NO, otherwise.
 */
- (BOOL)diskVideoExistsWithPath:(NSString * _Nullable)fullVideoCachePath;


# pragma mark - Clear Cache Events

/**
 * Remove the video data from disk cache asynchronously
 *
 * @param key             The unique video cache key.
 * @param completion      A block that should be executed after the video has been removed (optional).
 */
- (void)removeFullCacheForKey:(nullable NSString *)key withCompletion:(nullable dispatch_block_t)completion;

/**
 * Clear the temporary cache video for given key.
 *
 * @param key  The unique flag for the given url in this framework.
 * @param completion      A block that should be executed after the video has been removed (optional).
 */
- (void)removeTempCacheForKey:(NSString * _Nonnull)key withCompletion:(nullable dispatch_block_t)completion;

/**
 * Async remove all expired cached video from disk. Non-blocking method - returns immediately.
 *
 * @param completionBlock A block that should be executed after cache expiration completes (optional)
 */
- (void)deleteOldFilesWithCompletionBlock:(nullable dispatch_block_t)completionBlock;

/**
 * Async delete all temporary cached videos. Non-blocking method - returns immediately.
 * @param completion    A block that should be executed after cache expiration completes (optional).
 */
- (void)deleteAllTempCacheOnCompletion:(nullable dispatch_block_t)completion;

/**
 * Async clear all disk cached videos. Non-blocking method - returns immediately.
 * @param completion    A block that should be executed after cache expiration completes (optional).
 */
- (void)clearDiskOnCompletion:(nullable dispatch_block_t)completion;


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
- (void)calculateSizeWithCompletionBlock:(nullable JPVideoPlayerCalculateSizeCompletion)completionBlock;

# pragma mark - File Name

/**
 *  Generate the video file's name for given key.
 *
 *  @return the file's name.
 */
- (nullable NSString *)cacheFileNameForKey:(nullable NSString *)key;

@end

NS_ASSUME_NONNULL_END
