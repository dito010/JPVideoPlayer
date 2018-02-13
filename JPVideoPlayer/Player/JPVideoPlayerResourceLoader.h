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
#import <AVFoundation/AVFoundation.h>

@class JPVideoPlayerResourceLoader;

NS_ASSUME_NONNULL_BEGIN

@protocol JPVideoPlayerResourceLoaderDelegate<NSObject>

@optional

/**
 * Request range did change.
 *
 * @prama resourceLoader     the current resource loader for videoURLAsset.
 * @prama requestRangeString the request range string.
 */
- (void)resourceLoader:(JPVideoPlayerResourceLoader *)resourceLoader
 requestRangeDidChange:(NSString *)requestRangeString;

@end

@interface JPVideoPlayerResourceLoader : NSObject<AVAssetResourceLoaderDelegate>

/*
 * delegate.
 */
@property(nonatomic, weak) id<JPVideoPlayerResourceLoaderDelegate> delegate;

/**
 * Call this method to make this instance to handle video data for videoplayer.
 *
 * @param tempCacheVideoPath The cache video data temporary cache path in disk.
 * @param expectedSize         The video data total length.
 * @param receivedSize       The video data cached in disk.
 */
- (void)didReceivedDataCacheInDiskByTempPath:(NSString * _Nonnull)tempCacheVideoPath
                         videoFileExceptSize:(NSUInteger)expectedSize
                       videoFileReceivedSize:(NSUInteger)receivedSize;

/**
 * Call this method to change the video path from temporary path to full path.
 *
 * @param fullVideoCachePath the full video file path in disk.
 */
- (void)didCachedVideoDataFinishedFromWebFullVideoCachePath:(NSString * _Nullable)fullVideoCachePath;

@end

NS_ASSUME_NONNULL_END
