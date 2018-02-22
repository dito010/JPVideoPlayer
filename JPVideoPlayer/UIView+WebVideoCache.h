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

typedef NS_ENUM(NSInteger, JPVideoPlayerVideoViewStatus) {
    JPVideoPlayerVideoViewStatusPortrait,
    JPVideoPlayerVideoViewStatusLandscape,
    JPVideoPlayerVideoViewStatusAnimating
};

NS_ASSUME_NONNULL_BEGIN

typedef void(^JPVideoPlayerScreenAnimationCompletion)(void);

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
 * Controls the progress view's frame on top or on bottom, by default it is on bottom.
 *
 * @return Return YES to take the progress view to top.
 */
- (BOOL)shouldProgressViewOnTop;

/**
 * Controls the color of the layer under video palyer. by default it is NO, means that the color of the layer is `clearColor`.
 *
 * @return YES to make the color of the layer be `blackColor`.
 */
- (BOOL)shouldDisplayBlackLayerBeforePlayStart;

/**
 * Notify the player status.
 *
 * @param playingStatus      The current playing status.
 */
- (void)playerStatusDidChanged:(JPVideoPlayerStatus)playerStatus;

/**
 * Notify the download progress value. this method will be called on main thread.
 * If the video is local or cached file, this method will be called once and the receive size equal to expected size,
 * if video is existed on web, this method will be called when the download progress value changed, else if some error happened,
 * this method will never be called.
 *
 * @param receivedSize        The current received data size.
 * @param expectedSize        The expected data size.
 * @param error               The error when download video data.
 */
- (void)downloadProgressDidChangeReceivedSize:(NSUInteger)receivedSize
                                 expectedSize:(NSUInteger)expectedSize
                                        error:(NSError *)error;

/**
 * Notify the playing progress value. this method will be called on main thread.
 *
 * @param elapsedSeconds     The current played seconds.
 * @param totalSeconds       The total seconds of this video for given url.
 */
- (void)playProgressDidChangeElapsedSeconds:(double)elapsedSeconds
                               totalSeconds:(double)totalSeconds;

@end

@interface UIView (WebVideoCache)<JPVideoPlayerManagerDelegate>

#pragma mark - Property

@property(nonatomic, nullable)id<JPVideoPlayerDelegate> jp_videoPlayerDelegate;

/**
 * View status.
 */
@property(nonatomic, readonly)JPVideoPlayerVideoViewStatus jp_viewStatus;

/**
 * Playing status of video player.
 */
@property(nonatomic, readonly)JPVideoPlayerStatus jp_playerStatus;

#pragma mark - Play Video Methods

/**
 * Play `video` with an `url` on the view, and play audio at the same time.
 *
 * The download is asynchronous and cached.
 *
 * The progress view will display when downloading, and will display indicator view when buffer empty.
 *
 * @param url The url for the video.
 */
- (void)jp_playVideoWithURL:(nullable NSURL *)url;

/**
 * Play `video` with an `url` on the view.
 *
 * The download is asynchronous and cached.
 *
 * The progress view will hidden when downloading, and will display indicator view when buffer empty.
 *
 * @param url The url for the video.
 */
- (void)jp_playVideoHiddenStatusViewWithURL:(nullable NSURL *)url;

/**
 * Play `video` with an `url` on the view.
 *
 * The download is asynchronous and cached.
 *
 * Not audio output of the player is muted. Only affects audio muting for the player instance and not for the device.
 *
 * The progress view will hidden when downloading, and will display indicator view when buffer empty.
 *
 * @param url The url for the video.
 */
- (void)jp_playVideoMutedHiddenStatusViewWithURL:(nullable NSURL *)url;

/**
 * Play `video` with an `url` on the view.
 *
 * The download is asynchronous and cached.
 *
 * The progress view will display when downloading, and will display indicator view when buffer empty.
 *
 * Not audio output of the player is muted. Only affects audio muting for the player instance and not for the device.
 *
 * @param url The url for the video.
 */
- (void)jp_playVideoMutedDisplayStatusViewWithURL:(nullable NSURL *)url;

/**
 * Play `video` with an `url` on the view.
 *
 * The download is asynchronous and cached.
 *
 * @param url            The url for the video.
 * @param options        The options to use when downloading the video. @see JPVideoPlayerOptions for the possible values.
 */
- (void)jp_playVideoWithURL:(nullable NSURL *)url
                    options:(JPVideoPlayerOptions)options;

#pragma mark - Play Control

/**
 * Call this method to stop play video.
 */
- (void)jp_stopPlay;

/**
 *  Call this method to pause play.
 */
- (void)jp_pause;

/**
 *  Call this method to resume play.
 */
- (void)jp_resume;

/**
 * Call this method to play or pause audio of current video.
 *
 * @param mute the audio status will change to.
 */
- (void)jp_setPlayerMute:(BOOL)mute;

/**
 * Call this method to get the audio statu for current player.
 *
 * @return the audio status for current player.
 */
- (BOOL)jp_playerIsMute;

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
                      completion:(JPVideoPlayerScreenAnimationCompletion _Nullable)completion;

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
                     completion:(JPVideoPlayerScreenAnimationCompletion _Nullable)completion;

@end

NS_ASSUME_NONNULL_END