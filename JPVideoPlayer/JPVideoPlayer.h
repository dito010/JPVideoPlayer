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
#import "JPVideoPlayerManager.h"

NS_ASSUME_NONNULL_BEGIN

UIKIT_EXTERN CGFloat const JPVideoPlayerLayerFrameY;

@interface JPVideoPlayerModel : NSObject

/** 
 * The current playing url key.
 */
@property(nonatomic, strong, readonly, nonnull)NSString *playingKey;

/**
 * The current player's layer.
 */
@property(nonatomic, strong, readonly, nullable)AVPlayerLayer *currentPlayerLayer;

@end

@class JPVideoPlayer;

@protocol JPVideoPlayerInternalDelegate <NSObject>

@optional

/**
 * Controls which video should automatic replay when the video is playing completed.
 *
 * @param videoPlayer   the current `JPVideoPlayer`.
 * @param videoURL      the url of the video to be play.
 *
 * @return Return NO to prevent replay for the video. If not implemented, YES is implied.
 */
- (BOOL)videoPlayer:(nonnull JPVideoPlayer *)videoPlayer shouldAutoReplayVideoForURL:(nonnull NSURL *)videoURL;

/**
 * Notify the player status.
 *
 * @param videoPlayer   the current `JPVideoPlayer`.
 * @param playingStatus the current playing status.
 */
- (void)videoPlayer:(nonnull JPVideoPlayer *)videoPlayer playStatusDidChange:(JPVideoPlayerStatus)playingStatus;

/**
 * Called on the request range of player did change.
 *
 * @param videoPlayer        the current `JPVideoPlayer`.
 * @param requestRangeString the current request range of player.
 */
- (void)videoPlayer:(nonnull JPVideoPlayer *)videoPlayer playerRequestRangeDidChange:(NSString *)requestRangeString;

@end

typedef void(^JPPlayVideoManagerErrorBlock)(NSError * _Nullable error);

typedef void(^JPPlayVideoManagerPlayProgressBlock)(double currentSeconds, double totalSeconds);

@interface JPVideoPlayer : NSObject

@property(nullable, nonatomic, weak)id<JPVideoPlayerInternalDelegate> delegate;

/**
 * Singleton method, returns the shared instance.
 *
 * @return global shared instance of play video Manager class.
 */
+ (nonnull instancetype)sharedManager;

/**
 * The current play video item.
 */
@property(nonatomic, strong, readonly, nullable)JPVideoPlayerModel *currentVideoPlayerModel;


# pragma mark - Play video existed in disk.

/**
 * Play the existed video file in disk.
 *
 * @param url                the video url to play.
 * @param fullVideoCachePath the full video file path in disk.
 * @param showView           the view to show the video display layer.
 * @param progress           the playing progress of video player.
 * @param error              the error for 'fullVideoCachePath' and 'showLayer'.
 *
 * @return  token (@see JPPlayVideoManagerModel) that can be passed to -stopPlayVideo: to stop play.
 */
- (nullable JPVideoPlayerModel *)playExistedVideoWithURL:(NSURL * _Nullable)url
                                           fullVideoCachePath:(NSString * _Nullable)fullVideoCachePath
                                                      options:(JPVideoPlayerOptions)options
                                                   showOnView:(UIView * _Nullable)showView
                                                     progress:(JPPlayVideoManagerPlayProgressBlock _Nullable )progress
                                                        error:(nullable JPPlayVideoManagerErrorBlock)error;


# pragma mark - Play video from Web.

/**
 * Play the not existed video file from web.
 *
 * @param url                the video url to play.
 * @param tempVideoCachePath the temporary video file path in disk.
 * @param options            the options to use when downloading the video. @see JPVideoPlayerOptions for the possible values.
 * @param showView           the view to show the video display layer.
 * @param progress           the playing progress of video player.
 * @param error              the error for 'fullVideoCachePath' and 'showLayer'.
 *
 * @return  token (@see JPPlayVideoManagerModel) that can be passed to -stopPlayVideo: to stop play.
 */
- (nullable JPVideoPlayerModel *)playVideoWithURL:(NSURL * _Nullable)url
                                    tempVideoCachePath:(NSString * _Nullable)tempVideoCachePath
                                               options:(JPVideoPlayerOptions)options
                                   videoFileExceptSize:(NSUInteger)exceptSize
                                 videoFileReceivedSize:(NSUInteger)receivedSize
                                            showOnView:(UIView * _Nullable)showView
                                              progress:(JPPlayVideoManagerPlayProgressBlock _Nullable)progress
                                                 error:(nullable JPPlayVideoManagerErrorBlock)error;

/**
 * Play the not existed video from web.
 *
 * @param url                the video url to play.
 * @param options            the options to use when downloading the video. @see JPVideoPlayerOptions for the possible values.
 * @param showView           the view to show the video display layer.
 * @param progress           the playing progress of video player.
 * @param error              the error for 'fullVideoCachePath' and 'showLayer'.
 *
 * @return  token (@see JPPlayVideoManagerModel) that can be passed to -stopPlayVideo: to stop play.
 */
- (nullable JPVideoPlayerModel *)playVideoWithURL:(NSURL * _Nullable)url
                                               options:(JPVideoPlayerOptions)options
                                            showOnView:(UIView * _Nullable)showView
                                              progress:(JPPlayVideoManagerPlayProgressBlock _Nullable)progress
                                                 error:(nullable JPPlayVideoManagerErrorBlock)error;

/**
 * Call this method to make this instance to handle video data for player.
 *
 * @param tempCacheVideoPath The cache video data temporary cache path in disk.
 * @param expectedSize       The video data total length.
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
