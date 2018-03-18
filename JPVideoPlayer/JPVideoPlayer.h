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
#import <AVFoundation/AVFoundation.h>
#import "JPVideoPlayerCompat.h"

NS_ASSUME_NONNULL_BEGIN

@class JPVideoPlayer, JPResourceLoadingRequestWebTask;

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

@interface JPVideoPlayerModel : NSObject

/** 
 * The current playing url key.
 */
@property(nonatomic, strong, readonly, nonnull)NSString *playingKey;

/**
 * The current player's layer.
 */
@property(nonatomic, strong, readonly, nullable)AVPlayerLayer *currentPlayerLayer;

/**
 * The player to play video.
 */
@property(nonatomic, strong, readonly, nullable)AVPlayer *player;

@end

@interface JPVideoPlayer : NSObject

@property(nullable, nonatomic, weak)id<JPVideoPlayerInternalDelegate> delegate;

/**
 * The current play video item.
 */
@property(nonatomic, strong, readonly, nullable)JPVideoPlayerModel *currentPlayerModel;

# pragma mark - Play Video.

/**
 * Play the existed video file in disk.
 *
 * @param url                The video url to play.
 * @param fullVideoCachePath The full video file path in disk.
 * @param showLayer          The layer to show the video display layer.
 *
 * @return  token (@see JPPlayVideoManagerModel) that can be passed to -stopPlayVideo: to stop play.
 */
- (nullable JPVideoPlayerModel *)playExistedVideoWithURL:(NSURL *)url
                                      fullVideoCachePath:(NSString *)fullVideoCachePath
                                                 options:(JPVideoPlayerOptions)options
                                              showOnLayer:(CALayer *)showLayer;

/**
 * Play the not existed video from web.
 *
 * @param url                The video url to play.
 * @param options            The options to use when downloading the video. @see JPVideoPlayerOptions for the possible values.
 * @param showLayer          The view to show the video display layer.
 *
 * @return  token (@see JPPlayVideoManagerModel) that can be passed to -stopPlayVideo: to stop play.
 */
- (nullable JPVideoPlayerModel *)playVideoWithURL:(NSURL *)url
                                          options:(JPVideoPlayerOptions)options
                                        showLayer:(CALayer *)showLayer;


# pragma mark - Player Control Events

/** 
 * Call this method to control audio is play or not.
 *
 * @param mute the flag for audio status.
 */
- (void)setMute:(BOOL)mute;

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

@end

NS_ASSUME_NONNULL_END
