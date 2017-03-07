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
#import "UIView+PlayerStatusAndDownloadIndicator.h"

@interface UIView (WebVideoCache)

/**
 * Play `video` with an `url` on the view.
 *
 * The download is asynchronous and cached.
 *
 * @param url The url for the video.
 */
- (void)jp_playVideoWithURL:(nullable NSURL *)url;

/**
 * Play `video` with an `url` on the view.
 *
 * The download is asynchronous and cached.
 *
 * The progress view will display when downloading, and will display indicator view when buffer empty.
 *
 * @param url The url for the video.
 */
- (void)jp_playVideoDisplayStatusViewWithURL:(nullable NSURL *)url;

/**
 * Play `video` with an `url` on the view.
 *
 * The download is asynchronous and cached.
 *
 * Not audio output of the player is muted. Only affects audio muting for the player instance and not for the device
 *
 * @param url The url for the video.
 */
- (void)jp_playVideoMutedWithURL:(nullable NSURL *)url;

/**
 * Play `video` with an `url` on the view.
 *
 * The download is asynchronous and cached.
 *
 * The progress view will display when downloading, and will display indicator view when buffer empty.
 *
 * Not audio output of the player is muted. Only affects audio muting for the player instance and not for the device
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
 * @param operationKey   A string to be used as the operation key. If nil, will use the class name.
 * @param progressBlock  A block called while video is downloading.
 *                       @note the progress block is executed on a background queue.
 * @param completedBlock A block called when operation has been completed. This block has no return value 
 *   and takes the requested video temporary cache path as first parameter. In case of error the fullCacheVideoPath parameter
 *                       is nil and the second parameter may contain an NSError. The third parameter is a enum
 *                       indicating if the video was retrieved from the local cache or from the network.
 *                       The fourth parameter is the original image url.
 */
- (void)jp_playVideoWithURL:(nullable NSURL *)url
                           options:(JPVideoPlayerOptions)options
                      operationKey:(nullable NSString *)operationKey
                          progress:(nullable JPVideoPlayerDownloaderProgressBlock)progressBlock
                         completed:(nullable JPVideoPlayerCompletionBlock)completedBlock;

/**
 * Call this method to stop play video.
 */
-(void)stopPlay;

/**
 * Call this method to play or pause audio of current video.
 *
 * @param mute the audio status will change to.
 */
-(void)setPlayerMute:(BOOL)mute;

/**
 * Call this method to get the audio statu for current player.
 *
 * @return the audio status for current player.
 */
-(BOOL)playerIsMute;

@end
