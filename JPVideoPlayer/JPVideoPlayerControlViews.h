//
//  JPVideoPlayerControlViews.h
//  JPVideoPlayerDemo
//
//  Created by NewPan on 2018/2/20.
//  Copyright © 2018年 NewPan. All rights reserved.
//

#import "JPVideoPlayerProtocol.h"

@class JPVideoPlayerProgressView, JPVideoPlayerControlView;

NS_ASSUME_NONNULL_BEGIN
// TODO: 3.26 接下来处理拖动宽度越界 bug, 以及把 JPVideoPlayerControlBar 更加方便外界使用, 还有拖动缓存进度更新错误, .
@interface JPVideoPlayerControlBar : UIView<JPVideoPlayerProtocol>

@property (nonatomic, strong, readonly) UIButton *playButton;

@property (nonatomic, strong, readonly) JPVideoPlayerProgressView *progressView;

@property (nonatomic, strong, readonly) UILabel *timeLabel;

@property (nonatomic, strong, readonly) UIButton *landscapeButton;

@end

// TODO: 做到 progressView, 接下来封装一个 progressView, 然后到播放分类中实现
@interface JPVideoPlayerControlView : UIView<JPVideoPlayerProtocol>

@property (nonatomic, strong) UIColor *elapsedProgressColor;

@property (nonatomic, strong) UIColor *progressBackgroundColor;

@property (nonatomic, strong) UIColor *cachedProgressColor;

@property (nonatomic, strong, readonly) JPVideoPlayerControlBar *controlBar;

@property (nonatomic, strong, readonly) UIImage *blurImage;

/**
 * A designated initializer.
 *
 * @param controlBar The view abide by the `JPVideoPlayerProtocol`.
 * @param blurImage  A image on back of controlBar.
 *
 * @return The current instance.
 */
- (instancetype)initWithControlBar:(UIView<JPVideoPlayerProtocol> *_Nullable)controlBar
                         blurImage:(UIImage *_Nullable)blurImage NS_DESIGNATED_INITIALIZER;

@end

@interface JPVideoPlayerView : UIView

@property (nonatomic, strong, readonly) UIView *videoContainerLayer;

@property (nonatomic, strong, readonly) UIView *controlContainerView;

@end

UIKIT_EXTERN CGFloat const JPVideoPlayerActivityIndicatorWH;

@interface JPVideoPlayerActivityIndicator : UIView

- (void)startAnimating;

- (void)stopAnimating;

@end

NS_ASSUME_NONNULL_END
