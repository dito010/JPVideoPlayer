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

@interface JPVideoPlayerControlBar : UIView

@property (nonatomic, strong, readonly) UIButton *playButton;

@property (nonatomic, strong, readonly) JPVideoPlayerProgressView *progressView;

@property (nonatomic, strong, readonly) UILabel *timeLabel;

@property (nonatomic, strong, readonly) UIButton *landscapeButton;

@end

@protocol JPVideoPlayerControlViewDelegate<NSObject>

@optional

- (void)controlViewDidClickPlay:(JPVideoPlayerControlView *)controlView;

- (void)controlViewDidClickLandscape:(JPVideoPlayerControlView *)controlView;

- (void)controlView:(JPVideoPlayerControlView *)controlView
      didSeekToTime:(NSTimeInterval)seekTimeInterval;

@end
// TODO: 做到 progressView, 接下来封装一个 progressView, 然后到播放分类中实现
@interface JPVideoPlayerControlView : UIView<JPVideoPlayerProtocol>

@property (nonatomic, strong) UIColor *elapsedProgressColor;

@property (nonatomic, strong) UIColor *progressBackgroundColor;

@property (nonatomic, strong) UIColor *cachedProgressColor;

@property (nonatomic, strong, readonly) JPVideoPlayerControlBar *controlBar;

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
