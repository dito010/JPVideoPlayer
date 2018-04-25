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

#import "JPVideoPlayerProtocol.h"

@class JPVideoPlayerControlProgressView,
       JPVideoPlayerControlView;

NS_ASSUME_NONNULL_BEGIN

UIKIT_EXTERN NSString *JPVideoPlayerControlProgressViewUserDidStartDragNotification;
UIKIT_EXTERN NSString *JPVideoPlayerControlProgressViewUserDidEndDragNotification;
@interface JPVideoPlayerControlProgressView : UIView<JPVideoPlayerControlProgressProtocol>

@property (nonatomic, strong, readonly) NSArray<NSValue *> *rangesValue;

@property (nonatomic, assign, readonly) NSUInteger fileLength;

@property (nonatomic, assign, readonly) NSTimeInterval totalSeconds;

@property (nonatomic, assign, readonly) NSTimeInterval elapsedSeconds;

@property (nonatomic, weak, readonly, nullable) UIView *playerView;

@property (nonatomic, strong, readonly) UISlider *dragSlider;

@property (nonatomic, strong, readonly) UIView *cachedProgressView;

@property (nonatomic, strong, readonly) UIProgressView *trackProgressView;

@end

@interface JPVideoPlayerControlBar : UIView<JPVideoPlayerProtocol>

@property (nonatomic, strong, readonly) UIButton *playButton;

@property (nonatomic, strong, readonly) UIView<JPVideoPlayerControlProgressProtocol> *progressView;

@property (nonatomic, strong, readonly) UILabel *timeLabel;

@property (nonatomic, strong, readonly) UIButton *landscapeButton;

- (instancetype)initWithProgressView:(UIView<JPVideoPlayerControlProgressProtocol> *_Nullable)progressView NS_DESIGNATED_INITIALIZER;

@end

@interface JPVideoPlayerControlView : UIView<JPVideoPlayerProtocol>

@property (nonatomic, strong, readonly) UIView<JPVideoPlayerProtocol> *controlBar;

@property (nonatomic, strong, readonly) UIImage *blurImage;

/**
 * A designated initializer.
 *
 * @param controlBar The view abide by the `JPVideoPlayerProgressProtocol`.
 * @param blurImage  A image on back of controlBar.
 *
 * @return The current instance.
 */
- (instancetype)initWithControlBar:(UIView<JPVideoPlayerProtocol> *_Nullable)controlBar
                         blurImage:(UIImage *_Nullable)blurImage NS_DESIGNATED_INITIALIZER;

@end

UIKIT_EXTERN const CGFloat JPVideoPlayerProgressViewElementHeight;
@interface JPVideoPlayerProgressView : UIView<JPVideoPlayerProtocol>

@property (nonatomic, strong, readonly) NSArray<NSValue *> *rangesValue;

@property (nonatomic, assign, readonly) NSUInteger fileLength;

@property (nonatomic, assign, readonly) NSTimeInterval totalSeconds;

@property (nonatomic, assign, readonly) NSTimeInterval elapsedSeconds;

@property (nonatomic, strong, readonly) UIProgressView *trackProgressView;

@property (nonatomic, strong, readonly) UIView *cachedProgressView;

@property (nonatomic, strong, readonly) UIProgressView *elapsedProgressView;

@end

@interface JPVideoPlayerBufferingIndicator : UIView<JPVideoPlayerBufferingProtocol>

@property (nonatomic, strong, readonly)UIActivityIndicatorView *activityIndicator;

@property (nonatomic, strong, readonly)UIVisualEffectView *blurView;

@property (nonatomic, assign, readonly, getter=isAnimating)BOOL animating;

@end

@interface JPVideoPlayerView : UIView

@property (nonatomic, strong, readonly) CALayer *videoContainerLayer;

@property (nonatomic, strong, readonly) UIImageView *placeHolderView;

@property (nonatomic, strong, readonly) UIView *controlContainerView;

@property (nonatomic, strong, readonly) UIView *progressContainerView;

@property (nonatomic, strong, readonly) UIView *bufferingIndicatorContainerView;

@property (nonatomic, strong, readonly) UIView *userInteractionContainerView;

@property (nonatomic, assign, readonly) BOOL autoHide;

- (instancetype)initWithAutoHide:(BOOL)autoHide;

@end

NS_ASSUME_NONNULL_END
