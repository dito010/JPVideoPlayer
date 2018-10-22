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
#import "JPVideoPlayerCompat.h"
#import <AVFoundation/AVFoundation.h>

NS_ASSUME_NONNULL_BEGIN

@protocol JPVideoPlayerLayoutProtocol<NSObject>

@required
/**
 * This method called when need layout subviews, suggest you layout subviews in this method.
 *
 * @param constrainedRect       The bounds of superview.
 * @param nearestViewController The nearest `UIViewController` of view in view tree,
 *                               it be use to fetch `safeAreaInsets` to help layout subviews.
 * @param interfaceOrientation  The current interface orientation of view.
 */
- (void)layoutThatFits:(CGRect)constrainedRect
nearestViewControllerInViewTree:(UIViewController *_Nullable)nearestViewController
        interfaceOrientation:(JPVideoPlayViewInterfaceOrientation)interfaceOrientation;

@end

@protocol JPVideoPlayerProtocol<JPVideoPlayerLayoutProtocol>

@optional
/**
 * This method will be called when the view as a subview be add to a view.
 *
 * @note User can hold this view to control player, but remember that do not retain this view, suggest to
 * weak hold this view.
 *
 * @param view The view to control player.
 */
- (void)viewWillAddToSuperView:(UIView *)view;

/**
 * This method will be call when the view be reuse in `UITableView`,
 * you need reset progress value in this method for good user experience.
 */
- (void)viewWillPrepareToReuse;

/**
 * This method will be called when the downloader fetched the file length or read from disk.
 *
 * @warning This method may be call repeatedly when download a video.
 *
 * @param videoLength The video file length.
 * @param videoURL    The URL of video.
 */
- (void)didFetchVideoFileLength:(NSUInteger)videoLength
                    videoURL:(NSURL *)videoURL;

/**
 * This method will be called when received new video data from web.
 *
 * @param cacheRanges The ranges of video data cached in disk.
 * @param videoURL    The URL of video.
 */
- (void)cacheRangeDidChange:(NSArray<NSValue *> *)cacheRanges
                   videoURL:(NSURL *)videoURL;

/**
 * This method will be called when play progress changed.
 *
 * @param elapsedSeconds The elapsed player time.
 * @param totalSeconds   The length of the video.
 * @param videoURL       The URL of video.
 */
- (void)playProgressDidChangeElapsedSeconds:(NSTimeInterval)elapsedSeconds
                               totalSeconds:(NSTimeInterval)totalSeconds
                                   videoURL:(NSURL *)videoURL;

/**
 * This method will be called when video player status did change.
 *
 * @param playerStatus The player status.
 * @param videoURL     The URL of video.
 */
- (void)videoPlayerStatusDidChange:(JPVideoPlayerStatus)playerStatus
                          videoURL:(NSURL *)videoURL;

/**
 * This method will be called when the interfaceOrientation of player was changed.
 *
 * @param interfaceOrientation The interfaceOrientation of player.
 * @param videoURL             The URL of video.
 */
- (void)videoPlayerInterfaceOrientationDidChange:(JPVideoPlayViewInterfaceOrientation)interfaceOrientation
                                        videoURL:(NSURL *)videoURL;

@end

@protocol JPVideoPlayerControlProgressProtocol<JPVideoPlayerProtocol>

/**
 * Control progress must implement this method, and implement
 *
 * @code
 *      [self willChangeValueForKey:@"userDragging"];
 *      _userDragging = userDragging;
 *      [self didChangeValueForKey:@"userDragging"];
 *@endcode
 */
@property(nonatomic) BOOL userDragging;

/**
 * Control progress must implement this method, and implement
 *
 * @code
 *      [self willChangeValueForKey:@"userDragTimeInterval"];
 *      _userDragTimeInterval = userDragTimeInterval;
 *      [self didChangeValueForKey:@"userDragTimeInterval"];
 *@endcode
 */
@property(nonatomic) NSTimeInterval userDragTimeInterval;

@end

@protocol JPVideoPlayerBufferingProtocol<JPVideoPlayerLayoutProtocol>

@optional
/**
 * This method will be called when player buffering.
 *
 * @param videoURL    The URL of video.
 */
- (void)didStartBufferingVideoURL:(NSURL *)videoURL;

/**
 * This method will be called when player finish buffering and start play.
 *
 * @param videoURL    The URL of video.
 */
- (void)didFinishBufferingVideoURL:(NSURL *)videoURL;

@end

@protocol JPVideoPlayerPlaybackProtocol<NSObject>

@required
/**
 * The current playback rate.
 */
@property(nonatomic) float rate;

/**
 * A Boolean value that indicates whether the audio output of the player is muted.
 */
@property(nonatomic) BOOL muted;

/**
 * The audio playback volume for the player, ranging from 0.0 through 1.0 on a linear scale.
 */
@property(nonatomic) float volume;

/**
* Moves the playback cursor.
*
* @param time The time where seek to.
*/
- (void)seekToTime:(CMTime)time;

/**
 * Fetch the elapsed seconds of player.
 */
- (NSTimeInterval)elapsedSeconds;

/**
 * Fetch the total seconds of player.
 */
- (NSTimeInterval)totalSeconds;

/**
 *  Call this method to pause playback.
 */
- (void)pause;

/**
 *  Call this method to resume playback.
 */
- (void)resume;

/**
 * @return Returns the current time of the current player item.
 */
- (CMTime)currentTime;

/**
 * Call this method to stop play video.
 */
- (void)stopPlay;

@end

NS_ASSUME_NONNULL_END
