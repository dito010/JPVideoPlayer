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

@class JPVideoPlayerProgressView;

@interface UIView (PlayerStatusAndDownloadIndicator)

/**
 * The view of video layer display on.
 */
@property(nonatomic, readonly, nullable)UIView *jp_videoLayerView;

/**
 * The background layer for video layer.
 */
@property(nonatomic, readonly, nullable)CALayer *jp_backgroundLayer;

/**
 *  The indicator view to add progress view and activity view.
 */
@property(nonatomic, readonly, nullable)UIView *jp_indicatorView;

/**
 * The download progress value.
 */
@property(nonatomic, readonly)CGFloat jp_downloadProgressValue;

/**
 * The playing progress value.
 */
@property(nonatomic, readonly)CGFloat jp_playingProgressValue;

/**
 * Call this method to custom the dowload indicator color of progress view(@optional).
 *
 * @param color a `UIColor` instance to custom the dowload indicator progress view color.
 */
- (void)jp_perfersDownloadProgressViewColor:(UIColor * _Nonnull)color;

/**
 * Call this method to custom the playing indicator color of progress view(@optional).
 *
 * @param color a `UIColor` instance to custom the playing indicator progress view color.
 */
- (void)jp_perfersPlayingProgressViewColor:(UIColor * _Nonnull)color;

@end
