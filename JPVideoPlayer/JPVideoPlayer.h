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
#import <AVFoundation/AVFoundation.h>
#import "JPVideoPlayerCompat.h"
#import "JPVideoPlayerProtocol.h"

NS_ASSUME_NONNULL_BEGIN

@class JPVideoPlayer,
       JPResourceLoadingRequestWebTask,
       JPVideoPlayerResourceLoader;

@protocol JPVideoPlayerInternalDelegate <NSObject>

@required
/**
 * This method will be called when the current instance receive new loading request.
 *
 * @param videoPlayer The current `JPVideoPlayer`.
 * @prama requestTask A abstract instance packageing the loading request.
 */
- (void)videoPlayer:(JPVideoPlayer *)videoPlayer
didReceiveLoadingRequestTask:(JPResourceLoadingRequestWebTask *)requestTask;

@optional
/**
 * Controls which video should automatic replay when the video is playing completed.
 *
 * @param videoPlayer   The current `JPVideoPlayer`.
 * @param videoURL      The url of the video to be play.
 *
 * @return Return NO to prevent replay for the video. If not implemented, YES is implied.
 */
- (BOOL)videoPlayer:(nonnull JPVideoPlayer *)videoPlayer
shouldAutoReplayVideoForURL:(nonnull NSURL *)videoURL;

/**
 * Notify the player status.
 *
 * @param videoPlayer   The current `JPVideoPlayer`.
 * @param playerStatus  The current player status.
 */
- (void)videoPlayer:(nonnull JPVideoPlayer *)videoPlayer
playerStatusDidChange:(JPVideoPlayerStatus)playerStatus;

/**
 * Notify the playing progress value. this method will be called on main thread.
 *
 * @param videoPlayer        The current `videoPlayer`.
 * @param elapsedSeconds     The current played seconds.
 * @param totalSeconds       The total seconds of this video for given url.
 */
- (void)videoPlayerPlayProgressDidChange:(nonnull JPVideoPlayer *)videoPlayer
                          elapsedSeconds:(double)elapsedSeconds
                            totalSeconds:(double)totalSeconds;

/**
 * Called on some error raise in player.
 *
 * @param videoPlayer The current instance.
 * @param error       The error.
 */
- (void)videoPlayer:(nonnull JPVideoPlayer *)videoPlayer
playFailedWithError:(NSError *)error;

@end

@interface JPVideoPlayerModel : NSObject<JPVideoPlayerPlaybackProtocol>

/**
 * The current player's layer.
 */
@property (nonatomic, strong, readonly, nullable) AVPlayerLayer *playerLayer;

/**
 * The player to play video.
 */
@property (nonatomic, strong, readonly, nullable) AVPlayer *player;

/**
 * The resourceLoader for the videoPlayer.
 */
@property (nonatomic, strong, readonly, nullable) JPVideoPlayerResourceLoader *resourceLoader;

/**
 * options
 */
@property (nonatomic, assign, readonly) JPVideoPlayerOptions playerOptions;

@end

@interface JPVideoPlayer : NSObject<JPVideoPlayerPlaybackProtocol>

@property (nonatomic, weak, nullable) id<JPVideoPlayerInternalDelegate> delegate;

@property (nonatomic, strong, readonly, nullable) JPVideoPlayerModel *playerModel;

@property (nonatomic, assign, readonly) JPVideoPlayerStatus playerStatus;

/**
 * Play the existed video file in disk.
 *
 * @param url                     The video url to play.
 * @param fullVideoCachePath      The full video file path in disk.
 * @param showLayer               The layer to show the video display layer.
 * @param configurationCompletion The block will be call when video player config finished. because initialize player is not synchronize,
 *                                 so other category method is disabled before config finished.
 *
 * @return token (@see JPPlayVideoManagerModel) that can be passed to -stopPlayVideo: to stop play.
 */
- (JPVideoPlayerModel *_Nullable)playExistedVideoWithURL:(NSURL *)url
                                      fullVideoCachePath:(NSString *)fullVideoCachePath
                                                 options:(JPVideoPlayerOptions)options
                                             showOnLayer:(CALayer *)showLayer
                                 configurationCompletion:(JPPlayVideoConfiguration)configurationCompletion;

/**
 * Play the not existed video from web.
 *
 * @param url                     The video url to play.
 * @param options                 The options to use when downloading the video. @see JPVideoPlayerOptions for the possible values.
 * @param showLayer               The view to show the video display layer.
 * @param configurationCompletion The block will be call when video player config finished. because initialize player is not synchronize,
 *                                 so other category method is disabled before config finished.
 *
 * @return token (@see JPPlayVideoManagerModel) that can be passed to -stopPlayVideo: to stop play.
 */
- (JPVideoPlayerModel *_Nullable)playVideoWithURL:(NSURL *)url
                                          options:(JPVideoPlayerOptions)options
                                        showLayer:(CALayer *)showLayer
                          configurationCompletion:(JPPlayVideoConfiguration)configurationCompletion;

/**
 * Call this method to resume play.
 *
 * @param showLayer               The view to show the video display layer.
 * @param options                 The options to use when downloading the video. @see JPVideoPlayerOptions for the possible values.
 * @param configurationCompletion The block will be call when video player config finished. because initialize player is not synchronize,
 *                                 so other category method is disabled before config finished.
 */
- (void)resumePlayWithShowLayer:(CALayer *)showLayer
                        options:(JPVideoPlayerOptions)options
        configurationCompletion:(JPPlayVideoConfiguration)configurationCompletion;

/**
 * This method used to seek to record playback when hava record playback history.
 */
- (void)seekToTimeWhenRecordPlayback:(CMTime)time;

@end

NS_ASSUME_NONNULL_END
