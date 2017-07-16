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
