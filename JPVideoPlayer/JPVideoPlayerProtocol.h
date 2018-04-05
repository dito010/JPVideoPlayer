//
// Created by NewPan on 2018/3/6.
// Copyright (c) 2018 NewPan. All rights reserved.
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@protocol JPVideoPlayerProgressProtocol <NSObject>

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
 */
- (void)didFetchVideoFileLength:(NSUInteger)videoLength;

/**
 * This method will be called when received new video data from web.
 *
 * @param cacheRanges The ranges of video data cached in disk.
 */
- (void)cacheRangeDidChange:(NSArray<NSValue *> *)cacheRanges;

/**
 * This method will be called when play progress changed.
 *
 * @param elapsedSeconds The elapsed player time.
 * @param totalSeconds   The length of the video.
 */
- (void)playProgressDidChangeElapsedSeconds:(NSTimeInterval)elapsedSeconds
                               totalSeconds:(NSTimeInterval)totalSeconds;

@end

@protocol JPVideoPlayerBufferingProtocol<NSObject>

@optional

/**
 * This method will be called when player buffering.
 */
- (void)didStartBuffering;

/**
 * This method will be called when player finish buffering and start play.
 */
- (void)didFinishBuffering;

@end

NS_ASSUME_NONNULL_END
