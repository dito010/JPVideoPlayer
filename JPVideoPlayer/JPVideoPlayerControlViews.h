//
//  JPVideoPlayerControlViews.h
//  JPVideoPlayerDemo
//
//  Created by NewPan on 2018/2/20.
//  Copyright © 2018年 NewPan. All rights reserved.
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface JPVideoPlayerProgressView : UIView

/**
 * The download progress value.
 */
@property(nonatomic, assign, readonly)CGFloat downloadProgressValue;

/**
 * The playing progress value.
 */
@property(nonatomic, assign, readonly)CGFloat playingProgressValue;

/**
 * Refresh download progress by pass the progress value.
 *
 * @param downloadProgress the progress value, this value must between 0 and 1.
 */
- (void)setDownloadProgress:(CGFloat)downloadProgress;

/**
 * Refresh playing progress by pass the progress value.
 *
 * @param playingProgress the progress value, this value must between 0 and 1.
 */
- (void)setPlayingProgress:(CGFloat)playingProgress;

/**
 * Call this method to custom the dowload indicator color of progress view(@optional).
 *
 * @param color a `UIColor` instance to custom the dowload indicator progress view color.
 */
- (void)perfersDownloadProgressViewColor:(UIColor * _Nonnull)color;

/**
 * Call this method to custom the playing indicator color of progress view(@optional).
 *
 * @param color a `UIColor` instance to custom the playing indicator progress view color.
 */
- (void)perfersPlayingProgressViewColor:(UIColor * _Nonnull)color;

/**
 * Call this method to refresh the progress view frame.
 */
- (void)refreshProgressViewForScreenEvents;

@end

UIKIT_EXTERN CGFloat const JPVideoPlayerActivityIndicatorWH;

@interface JPVideoPlayerActivityIndicator : UIView

- (void)startAnimating;

- (void)stopAnimating;

@end

NS_ASSUME_NONNULL_END
