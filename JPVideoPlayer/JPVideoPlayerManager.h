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

#import <UIKit/UIKit.h>
#import "JPVideoPlayerDownloader.h"
#import "JPVideoPlayerCache.h"
#import "JPVideoPlayer.h"
#import "JPVideoPlayerProtocol.h"

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

/**
 * Called when application will resign active.
 *
 * @param videoPlayerManager The current `JPVideoPlayerManager`.
 * @param videoURL           The url of the video to be play.
 */
- (BOOL)videoPlayerManager:(JPVideoPlayerManager *)videoPlayerManager
shouldPausePlaybackWhenApplicationWillResignActiveForURL:(NSURL *)videoURL;

/**
 * Called when application did enter background.
 *
 * @param videoPlayerManager The current `JPVideoPlayerManager`.
 * @param videoURL           The url of the video to be play.
 */
- (BOOL)videoPlayerManager:(JPVideoPlayerManager *)videoPlayerManager
shouldPausePlaybackWhenApplicationDidEnterBackgroundForURL:(NSURL *)videoURL;

/**
 * Called only when application become active from `Control Center`,
 *  `Notification Center`, `pop UIAlert`, `double click Home-Button`.
 *
 * @param videoPlayerManager The current `JPVideoPlayerManager`.
 * @param videoURL           The url of the video to be play.
 */
- (BOOL)videoPlayerManager:(JPVideoPlayerManager *)videoPlayerManager
shouldResumePlaybackWhenApplicationDidBecomeActiveFromResignActiveForURL:(NSURL *)videoURL;

/**
 * Called only when application become active from `Share to other application`,
 *  `Enter background`, `Lock screen`.
 *
 * @param videoPlayerManager The current `JPVideoPlayerManager`.
 * @param videoURL           The url of the video to be play.
 */
- (BOOL)videoPlayerManager:(JPVideoPlayerManager *)videoPlayerManager
shouldResumePlaybackWhenApplicationDidBecomeActiveFromBackgroundForURL:(NSURL *)videoURL;

/**
 * Called when call resume play but can not resume play.
 *
 * @param videoPlayerManager The current `JPVideoPlayerManager`.
 * @param videoURL           The url of the video to be play.
 */
- (BOOL)videoPlayerManager:(JPVideoPlayerManager *)videoPlayerManager
shouldTranslateIntoPlayVideoFromResumePlayForURL:(NSURL *)videoURL;

/**
 * Called when receive audio session interruption notification.
 *
 * @param videoPlayerManager The current `JPVideoPlayerManager`.
 * @param videoURL           The url of the video to be play.
 */
- (BOOL)videoPlayerManager:(JPVideoPlayerManager *)videoPlayerManager
shouldPausePlaybackWhenReceiveAudioSessionInterruptionNotificationForURL:(NSURL *)videoURL;

/**
 * Provide custom audio session category to play video.
 *
 * @param videoPlayerManager The current `JPVideoPlayerManager`.
 *
 * @return The prefer audio session category.
 */
- (NSString *)videoPlayerManagerPreferAudioSessionCategory:(JPVideoPlayerManager *)videoPlayerManager;

/**
 * Called when play a already played video.
 *
 * @param videoPlayerManager The current `JPVideoPlayerManager`.
 * @param videoURL           The url of the video to be play.
 * @param elapsedSeconds     The elapsed seconds last playback recorded.
 */
- (BOOL)videoPlayerManager:(JPVideoPlayerManager *)videoPlayerManager
shouldResumePlaybackFromPlaybackRecordForURL:(NSURL *)videoURL
            elapsedSeconds:(NSTimeInterval)elapsedSeconds;

@end

@interface JPVideoPlayerManagerModel : NSObject

@property (nonatomic, strong, readonly) NSURL *videoURL;

@property (nonatomic, assign) JPVideoPlayerCacheType cacheType;

@property (nonatomic, assign) NSUInteger fileLength;

/**
 * The fragment of video data that cached in disk.
 */
@property (nonatomic, strong, readonly, nullable) NSArray<NSValue *> *fragmentRanges;

@end

@interface JPVideoPlayerManager : NSObject<JPVideoPlayerPlaybackProtocol>

@property (weak, nonatomic, nullable) id <JPVideoPlayerManagerDelegate> delegate;

@property (strong, nonatomic, readonly, nullable) JPVideoPlayerCache *videoCache;

@property (strong, nonatomic, readonly, nullable) JPVideoPlayerDownloader *videoDownloader;

@property (nonatomic, strong, readonly) JPVideoPlayerManagerModel *managerModel;

@property (nonatomic, strong, readonly) JPVideoPlayer *videoPlayer;

#pragma mark - Singleton and Initialization

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
- (nonnull instancetype)initWithCache:(nonnull JPVideoPlayerCache *)cache
                           downloader:(nonnull JPVideoPlayerDownloader *)downloader NS_DESIGNATED_INITIALIZER;


# pragma mark - Play Video

/**
 * Play the video for the given URL.
 
 * @param url                     The URL of video.
 * @param showLayer               The layer of video layer display on.
 * @param options                 A flag to specify options to use for this request.
 * @param configurationCompletion The block will be call when video player config finished. because initialize player is not synchronize,
 *                                 so other category method is disabled before config finished.
 */
- (void)playVideoWithURL:(NSURL *)url
             showOnLayer:(CALayer *)showLayer
                 options:(JPVideoPlayerOptions)options
 configurationCompletion:(JPPlayVideoConfiguration)configurationCompletion;

/**
 * Resume video play for the given URL.

 * @param url                     The URL of video.
 * @param showLayer               The layer of video layer display on.
 * @param options                 A flag to specify options to use for this request.
 * @param configurationCompletion The block will be call when video player config finished. because initialize player is not synchronize,
 *                                 so other category method is disabled before config finished.
 */
- (void)resumePlayWithURL:(NSURL *)url
              showOnLayer:(CALayer *)showLayer
                  options:(JPVideoPlayerOptions)options
  configurationCompletion:(JPPlayVideoConfiguration)configurationCompletion;

/**
 * Return the cache key for a given URL.
 */
- (NSString *_Nullable)cacheKeyForURL:(NSURL *)url;

#pragma mark - Version

/**
 * Return the version of SDK;
 */
- (NSString *)SDKVersion;

@end

NS_ASSUME_NONNULL_END
