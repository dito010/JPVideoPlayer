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

#import <UIKit/UIKit.h>
#import "JPVideoPlayerDownloader.h"
#import "JPVideoPlayerCache.h"
#import "JPVideoPlayer.h"

NS_ASSUME_NONNULL_BEGIN

@class JPVideoPlayerManager;

@protocol JPVideoPlayerManagerDelegate <NSObject>

@optional

/**
 * Controls which video should be downloaded when the video is not found in the cache.
 *
 * @param videoPlayerManager The current `JPVideoPlayerManager`.
 * @param videoURL           The url of the video to be downloaded.
 *
 * @return Return NO to prevent the downloading of the video on cache misses. If not implemented, YES is implied.
 */
- (BOOL)videoPlayerManager:(JPVideoPlayerManager *)videoPlayerManager
 shouldDownloadVideoForURL:(NSURL *)videoURL;

/**
 * Controls which video should automatic replay when the video is play completed.
 *
 * @param videoPlayerManager The current `JPVideoPlayerManager`.
 * @param videoURL           The url of the video to be play.
 *
 * @return Return NO to prevent replay for the video. If not implemented, YES is implied.
 */
- (BOOL)videoPlayerManager:(JPVideoPlayerManager *)videoPlayerManager
    shouldAutoReplayForURL:(NSURL *)videoURL;

/**
 * Notify the playing status.
 *
 * @param videoPlayerManager The current `JPVideoPlayerManager`.
 * @param playerStatus       The current playing status.
 */
- (void)videoPlayerManager:(JPVideoPlayerManager *)videoPlayerManager
    playerStatusDidChanged:(JPVideoPlayerStatus)playerStatus;

/**
 * Notify the video file length.
 *
 * @param videoPlayerManager The current `JPVideoPlayerManager`.
 * @param videoLength        The file length of video data.
 */
- (void)videoPlayerManager:(JPVideoPlayerManager *)videoPlayerManager
   didFetchVideoFileLength:(NSUInteger)videoLength;

/**
 * Notify the download progress value. this method will be called on main thread.
 * If the video is local or cached file, this method will be called once and the receive size equal to expected size,
 * If video is existed on web, this method will be called when the download progress value changed,
 * If some error happened, the error is no nil.
 *
 * @param videoPlayerManager  The current `JPVideoPlayerManager`.
 * @param cacheType           The video data cache type.
 * @param fragmentRanges      The fragment of video data that cached in disk.
 * @param expectedSize        The expected data size.
 * @param error               The error when download video data.
 */
- (void)videoPlayerManagerDownloadProgressDidChange:(JPVideoPlayerManager *)videoPlayerManager
                                          cacheType:(JPVideoPlayerCacheType)cacheType
                                     fragmentRanges:(NSArray<NSValue *> * _Nullable)fragmentRanges
                                       expectedSize:(NSUInteger)expectedSize
                                              error:(NSError *_Nullable)error;

/**
 * Notify the playing progress value. this method will be called on main thread.
 *
 * @param videoPlayerManager The current `JPVideoPlayerManager`.
 * @param elapsedSeconds     The current played seconds.
 * @param totalSeconds       The total seconds of this video for given url.
 * @param error              The error when playing video.
 */
- (void)videoPlayerManagerPlayProgressDidChange:(JPVideoPlayerManager *)videoPlayerManager
                                 elapsedSeconds:(double)elapsedSeconds
                                   totalSeconds:(double)totalSeconds
                                          error:(NSError *_Nullable)error;

@end

@interface JPVideoPlayerManager : NSObject

@property (weak, nonatomic, nullable) id <JPVideoPlayerManagerDelegate> delegate;

@property (strong, nonatomic, readonly, nullable) JPVideoPlayerCache *videoCache;

@property (strong, nonatomic, readonly, nullable) JPVideoPlayerDownloader *videoDownloader;

@property(nonatomic, strong, readonly) JPVideoPlayer *videoPlayer;

/*
 * url.
 */
@property(nonatomic, strong, readonly) NSURL *url;

/**
 * options
 */
@property(nonatomic, assign, readonly)JPVideoPlayerOptions playerOptions;

#pragma mark - Singleton and initialization

/**
 * Returns global `JPVideoPlayerManager` instance.
 *
 * @return `JPVideoPlayerManager` shared instance
 */
+ (nonnull instancetype)sharedManager;

/**
 * Set the log level. `JPLogLevelDebug` by default.
 *
 * @see `JPLogLevel`.
 *
 * @param logLevel The log level to control log type.
 */
+ (void)preferLogLevel:(JPLogLevel)logLevel;

/**
 * Allows to specify instance of cache and video downloader used with video manager.
 * @return new instance of `JPVideoPlayerManager` with specified cache and downloader.
 */
- (nonnull instancetype)initWithCache:(nonnull JPVideoPlayerCache *)cache downloader:(nonnull JPVideoPlayerDownloader *)downloader NS_DESIGNATED_INITIALIZER;


# pragma mark - Play Video Options

/**
 * Play the video for the given URL if not present in cache or return the cached version otherwise.
 
 * @param url             The URL of video.
 * @param showLayer       The view of video layer display on.
 * @param options         A flag to specify options to use for this request.
 */
- (void)playVideoWithURL:(NSURL *)url
             showOnLayer:(UIView *)showLayer
                 options:(JPVideoPlayerOptions)options;

/**
 * Cancels all download operations in the queue.
 */
- (void)cancelAllDownloads;

/**
 * Return the cache key for a given URL.
 */
- (NSString *_Nullable)cacheKeyForURL:(nullable NSURL *)url;


# pragma mark - Play Control

/**
 * Call this method to stop play video.
 */
- (void)stopPlay;

/**
 *  Call this method to pause play.
 */
- (void)pause;

/**
 *  Call this method to resume play.
 */
- (void)resume;

/**
 * Call this method to play or pause audio of current video.
 *
 * @param mute the audio status will change to.
 */
- (void)setPlayerMute:(BOOL)mute;

/**
 * Call this method to get the audio statu for current player.
 *
 * @return the audio status for current player.
 */
- (BOOL)playerIsMute;

@end

NS_ASSUME_NONNULL_END
