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
#import <AVFoundation/AVFoundation.h>

@class JPVideoPlayerResourceLoader,
       JPResourceLoadingRequestWebTask,
       JPVideoPlayerCacheFile;

NS_ASSUME_NONNULL_BEGIN

@protocol JPVideoPlayerResourceLoaderDelegate<NSObject>

@required

/**
 * This method will be called when the current instance receive new loading request.
 *
 * @prama resourceLoader     The current resource loader for videoURLAsset.
 * @prama requestTask        A abstract instance packaging the loading request.
 */
- (void)resourceLoader:(JPVideoPlayerResourceLoader *)resourceLoader
didReceiveLoadingRequestTask:(JPResourceLoadingRequestWebTask *)requestTask;

@end

@interface JPVideoPlayerResourceLoader : NSObject<AVAssetResourceLoaderDelegate>

@property (nonatomic, weak, nullable) id<JPVideoPlayerResourceLoaderDelegate> delegate;

/// The url custom passed in.
@property (nonatomic, strong, readonly) NSURL *customURL;

/// The cache file take responsibility for save video data to disk and read cached video from disk.
@property (nonatomic, strong, readonly) JPVideoPlayerCacheFile *cacheFile;

/// The sync queue to dispatch all internal tasks.
@property(nonatomic, strong, readonly) dispatch_queue_t syncQueue;

- (instancetype)init NS_UNAVAILABLE;

+ (instancetype)new NS_UNAVAILABLE;

/**
 * Convenience method to fetch instance of this class.
 *
 * @param customURL The url custom passed in.
 * @param cacheFile The cache file take responsibility for save video data to disk and read cached video from disk.
 * @param syncQueue The sync queue to dispatch all internal tasks.
 *
 * @return A instance of this class.
 */
+ (instancetype)resourceLoaderWithCustomURL:(NSURL *)customURL
                                  cacheFile:(JPVideoPlayerCacheFile *)cacheFile
                                  syncQueue:(dispatch_queue_t)syncQueue;

/**
 * Designated initializer method.
 *
 * @param customURL The url custom passed in.
 * @param cacheFile The cache file take responsibility for save video data to disk and read cached video from disk.
 * @param syncQueue The sync queue to dispatch all internal tasks.
 *
 * @return A instance of this class.
 */
- (instancetype)initWithCustomURL:(NSURL *)customURL
                        cacheFile:(JPVideoPlayerCacheFile *)cacheFile
                        syncQueue:(dispatch_queue_t)syncQueue NS_DESIGNATED_INITIALIZER;

@end

NS_ASSUME_NONNULL_END
