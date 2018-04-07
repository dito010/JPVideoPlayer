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
#import "JPVideoPlayerManager.h"
#import "JPVideoPlayerSupportUtils.h"
#import "JPVideoPlayerProtocol.h"

NS_ASSUME_NONNULL_BEGIN

@protocol JPVideoPlayerDelegate <NSObject>

@optional

/** 
 * Controls which video should be downloaded when the video is not found in the cache.
 *
 * @param   videoURL the url of the video to be download.
 *
 * @return Return NO to prevent the downloading of the video on cache misses. If not implemented, YES is implied.
 */
- (BOOL)shouldDownloadVideoForURL:(nonnull NSURL *)videoURL;

/**
 * Controls which video should automatic replay when the video is play completed.
 *
 * @param videoURL  the url of the video to be play.
 *
 * @return Return NO to prevent replay for the video. If not implemented, YES is implied.
 */
- (BOOL)shouldAutoReplayForURL:(nonnull NSURL *)videoURL;

/**
 * Controls the background color of the video layer before player really start play video.
 *  by default it is NO, means that the color of the layer is `clearColor`.
 *
 * @return Return YES to make the background color of the video layer be `blackColor`.
 */
- (BOOL)shouldShowBlackBackgroundBeforePlaybackStart;

/**
 * Notify the player status.
 *
 * @param playerStatus      The current playing status.
 */
- (void)playerStatusDidChanged:(JPVideoPlayerStatus)playerStatus;

/**
 * Called when application will resign active.
 *
 * @param videoURL The url of the video to be play.
 */
- (BOOL)shouldPausePlaybackWhenApplicationWillResignActiveForURL:(NSURL *)videoURL;

/**
 * Called when application did enter background.
 *
 * @param videoURL The url of the video to be play.
 */
- (BOOL)shouldPausePlaybackWhenApplicationDidEnterBackgroundForURL:(NSURL *)videoURL;

/**
 * Called only when application become active from `Control Center`,
 *  `Notification Center`, `pop UIAlert`, `double click Home-Button`.
 *
 * @param videoURL The url of the video to be play.
 */
- (BOOL)shouldResumePlaybackWhenApplicationDidBecomeActiveFromResignActiveForURL:(NSURL *)videoURL;

/**
 * Called only when application become active from `Share to other application`,
 *  `Enter background`, `Lock screen`.
 *
 * @param videoURL The url of the video to be play.
 */
- (BOOL)shouldResumePlaybackWhenApplicationDidBecomeActiveFromBackgroundForURL:(NSURL *)videoURL;

@end

@interface UIView (WebVideoCache)<JPVideoPlayerManagerDelegate>

#pragma mark - Property

@property (nonatomic, readonly) JPVideoPlayViewInterfaceOrientation jp_viewInterfaceOrientation;

@property (nonatomic, readonly) JPVideoPlayerStatus jp_playerStatus;

@property (nonatomic, readonly, nullable) UIView<JPVideoPlayerProtocol> *jp_progressView;

@property (nonatomic, readonly, nullable) UIView<JPVideoPlayerProtocol> *jp_controlView;

@property (nonatomic, readonly, nullable) UIView<JPVideoPlayerBufferingProtocol> *jp_bufferingIndicator;

@property (nonatomic, nullable) id<JPVideoPlayerDelegate> jp_videoPlayerDelegate;

#pragma mark - Play Video Methods

/**
 * Play `video` with an `url` on the view, and play audio at the same time.
 *
 * The download is asynchronous and cached.
 *
 * @param url The url for the video.
 */
- (void)jp_playVideoWithURL:(NSURL *)url;

/**
 * Play `video` mute with an `url` on the view.
 *
 * The download is asynchronous and cached.
 *
 * @param url                The url for the video.
 * @param bufferingIndicator The view show buffering animation when player buffering, should compliance with the `JPVideoPlayerBufferingProtocol`,
 *                            it will display default bufferingIndicator if pass nil in. @see `JPVideoPlayerBufferingIndicator`.
 * @param progressView       The view to display the download and play progress, should compliance with the `JPVideoPlayerProgressProtocol`,
 *                            it will display default progressView if pass nil, @see `JPVideoPlayerProgressView`.
 */
- (void)jp_playVideoMuteWithURL:(NSURL *)url
             bufferingIndicator:(UIView<JPVideoPlayerBufferingProtocol> *_Nullable)bufferingIndicator
                   progressView:(UIView<JPVideoPlayerProtocol> *_Nullable)progressView;

/**
 * Play `video` mute with an `url` on the view.
 *
 * The download is asynchronous and cached.
 *
 * @param url                 The url for the video.
 * @param bufferingIndicator  The view show buffering animation when player buffering, should compliance with the `JPVideoPlayerBufferingProtocol`,
 *                             it will display default bufferingIndicator if pass nil in. @see `JPVideoPlayerBufferingIndicator`.
 * @param progressView        The view to display the download and play progress, should compliance with the `JPVideoPlayerProgressProtocol`,
 *                             it will display default progressView if pass nil, @see `JPVideoPlayerProgressView`.
 * @param configFinishedBlock The block will be call when video player config finished. because initialize player is not synchronize,
 *                             so other category method is disabled before config finished.
 */
- (void)jp_playVideoMuteWithURL:(NSURL *)url
             bufferingIndicator:(UIView<JPVideoPlayerBufferingProtocol> *_Nullable)bufferingIndicator
                   progressView:(UIView<JPVideoPlayerProtocol> *_Nullable)progressView
            configFinishedBlock:(JPPlayVideoConfigFinishedBlock _Nullable)configFinishedBlock;

/**
 * Play `video` with an `url` on the view, and play audio at the same time.
 *
 * The download is asynchronous and cached.
 *
 * The control view will display, and display indicator view when buffer empty.
 *
 * @param url                The url for the video.
 * @param bufferingIndicator The view show buffering animation when player buffering, should compliance with the `JPVideoPlayerBufferingProtocol`,
 *                            it will display default bufferingIndicator if pass nil in. @see `JPVideoPlayerBufferingIndicator`.
 * @param controlView        The view to display the download and play progress, should compliance with the `JPVideoPlayerProgressProtocol`,
 *                            it will display default controlView if pass nil, @see `JPVideoPlayerControlView`.
 * @param progressView       The view to display the download and play progress, should compliance with the `JPVideoPlayerProgressProtocol`,
 *                            it will display default progressView if pass nil, @see `JPVideoPlayerProgressView`.
 */
- (void)jp_playVideoWithURL:(NSURL *)url
         bufferingIndicator:(UIView<JPVideoPlayerBufferingProtocol> *_Nullable)bufferingIndicator
                controlView:(UIView<JPVideoPlayerProtocol> *_Nullable)controlView
               progressView:(UIView<JPVideoPlayerProtocol> *_Nullable)progressView;

/**
 * Play `video` with an `url` on the view, and play audio at the same time.
 *
 * The download is asynchronous and cached.
 *
 * The control view will display, and display indicator view when buffer empty.
 *
 * @param url                 The url for the video.
 * @param bufferingIndicator  The view show buffering animation when player buffering, should compliance with the `JPVideoPlayerBufferingProtocol`,
 *                             it will display default bufferingIndicator if pass nil in. @see `JPVideoPlayerBufferingIndicator`.
 * @param controlView         The view to display the download and play progress, should compliance with the `JPVideoPlayerProgressProtocol`,
 *                             it will display default controlView if pass nil, @see `JPVideoPlayerControlView`.
 * @param progressView        The view to display the download and play progress, should compliance with the `JPVideoPlayerProgressProtocol`,
 *                             it will display default progressView if pass nil, @see `JPVideoPlayerProgressView`.
 * @param configFinishedBlock The block will be call when video player config finished. because initialize player is not synchronize,
 *                             so other category method is disabled before config finished.
 */
- (void)jp_playVideoWithURL:(NSURL *)url
         bufferingIndicator:(UIView<JPVideoPlayerBufferingProtocol> *_Nullable)bufferingIndicator
                controlView:(UIView<JPVideoPlayerProtocol> *_Nullable)controlView
               progressView:(UIView<JPVideoPlayerProtocol> *_Nullable)progressView
        configFinishedBlock:(JPPlayVideoConfigFinishedBlock _Nullable)configFinishedBlock;

/**
 * Play `video` with an `url` on the view.
 *
 * The download is asynchronous and cached.
 *
 * @param url                 The url for the video.
 * @param options             The options to use when downloading the video. @see JPVideoPlayerOptions for the possible values.
 * @param configFinishedBlock The block will be call when video player config finished. because initialize player is not synchronize,
 *                             so other category method is disabled before config finished.
 */
- (void)jp_playVideoWithURL:(NSURL *)url
                    options:(JPVideoPlayerOptions)options
        configFinishedBlock:(JPPlayVideoConfigFinishedBlock)configFinishedBlock;

#pragma mark - Playback Control

/**
 * The current playback rate.
 */
@property(nonatomic) float jp_rate;

/**
 * A Boolean value that indicates whether the audio output of the player is muted.
 */
@property(nonatomic) BOOL jp_muted;

/**
 * The audio playback volume for the player, ranging from 0.0 through 1.0 on a linear scale.
 */
@property(nonatomic) float jp_volume;

/**
* Moves the playback cursor.
*
* @param time The time where seek to.
*/
- (void)jp_seekToTime:(CMTime)time;

/**
 *  Call this method to pause playback.
 */
- (void)jp_pause;

/**
 *  Call this method to resume playback.
 */
- (void)jp_resume;

/**
 * @return Returns the current time of the current player item.
 */
- (CMTime)jp_currentTime;

/**
 * Call this method to stop play video.
 */
- (void)jp_stopPlay;

#pragma mark - Landscape Or Portrait Control

/**
 * Call this method to enter full screen.
 */
- (void)jp_gotoLandscape;

/**
 * Call this method to enter full screen.
 *
 * @param animated   need landscape animation or not.
 * @param completion call back when landscape finished.
 */
- (void)jp_gotoLandscapeAnimated:(BOOL)animated
                      completion:(dispatch_block_t _Nullable)completion;

/**
 * Call this method to exit full screen.
 */
- (void)jp_gotoPortrait;

/**
 * Call this method to exit full screen.
 *
 * @param animated   need portrait animation or not.
 * @param completion call back when portrait finished.
 */
- (void)jp_gotoPortraitAnimated:(BOOL)animated
                     completion:(dispatch_block_t _Nullable)completion;

@end

NS_ASSUME_NONNULL_END
