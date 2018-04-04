//
//  JPVideoPlayerControlViews.m
//  JPVideoPlayerDemo
//
//  Created by NewPan on 2018/2/20.
//  Copyright © 2018年 NewPan. All rights reserved.
//

#import "JPVideoPlayerControlViews.h"
#import "JPVideoPlayerCompat.h"
#import "UIView+WebVideoCache.h"

@interface JPVideoPlayerProgressView()

@property (nonatomic, strong) UIImageView *controlHandlerImageView;

@property (nonatomic, strong) UIView *backgroundView;

@property (nonatomic, strong) NSArray<NSValue *> *rangesValue;

@property(nonatomic, assign) NSUInteger fileLength;

@property(nonatomic, assign) NSTimeInterval totalSeconds;

@property(nonatomic, assign) NSTimeInterval elapsedSeconds;

@property (nonatomic, strong) UIView *elapsedProgressView;

@property (nonatomic, strong) UIView *cachedProgressView;

@property(nonatomic, assign) BOOL userDragging;

@property (nonatomic, weak) UIView *playerView;

@end

static const CGFloat kJPVideoPlayerProgressViewWidth = 20;
static const CGFloat kJPVideoPlayerProgressBackgroundViewHeight = 2;
NSString *JPVideoPlayerProgressViewUserDidStartDragNotification = @"com.jpvideoplayer.progressview.user.drag.start.www";
NSString *JPVideoPlayerProgressViewUserDidEndDragNotification = @"com.jpvideoplayer.progressview.user.drag.end.www";;
@implementation JPVideoPlayerProgressView

- (instancetype)init {
    self = [super init];
    if (self) {
        [self setup];
    }
    return self;
}

- (void)setFrame:(CGRect)frame {
    [super setFrame:frame];

    CGSize referenceSize = self.bounds.size;
    self.controlHandlerImageView.frame = CGRectMake(0, 0, kJPVideoPlayerProgressViewWidth, kJPVideoPlayerProgressViewWidth);
    self.backgroundView.frame = CGRectMake(kJPVideoPlayerProgressViewWidth * 0.5,
            (referenceSize.height - kJPVideoPlayerProgressBackgroundViewHeight) * 0.5,
            referenceSize.width - kJPVideoPlayerProgressViewWidth,
            kJPVideoPlayerProgressBackgroundViewHeight);
    self.elapsedProgressView.frame = CGRectMake(0, 0, 0, kJPVideoPlayerProgressBackgroundViewHeight);
    [self updateCacheProgressViewIfNeed];
    [self playProgressDidChangeElapsedSeconds:self.elapsedSeconds
                                 totalSeconds:self.totalSeconds];
}


#pragma mark - JPVideoPlayerControlProtocol

- (void)viewWillAddToSuperView:(UIView *)view {
    self.playerView = view;
}

- (void)cacheRangeDidChange:(NSArray<NSValue *> *)cacheRanges {
    _rangesValue = cacheRanges;
    [self updateCacheProgressViewIfNeed];
}

- (void)playProgressDidChangeElapsedSeconds:(NSTimeInterval)elapsedSeconds
                               totalSeconds:(NSTimeInterval)totalSeconds {
    if(self.userDragging){
        return;
    }

    CGFloat controlHandleViewOriginX = (self.bounds.size.width - kJPVideoPlayerProgressViewWidth) * (elapsedSeconds / totalSeconds);
    [self updateElapsedProgressAndHandlerViewWithControlHandleViewOriginX:controlHandleViewOriginX];
    self.totalSeconds = totalSeconds;
    self.elapsedSeconds = elapsedSeconds;
}

- (void)didFetchVideoFileLength:(NSUInteger)videoLength {
    self.fileLength = videoLength;
}


#pragma mark - Private

- (void)setup {
    self.backgroundView = ({
        UIView *view = [UIView new];
        [self addSubview:view];

        view;
    });

    self.cachedProgressView = ({
        UIView *view = [UIView new];
        [self.backgroundView addSubview:view];

        view;
    });

    self.elapsedProgressView = ({
        UIView *view = [UIView new];
        [self.backgroundView addSubview:view];

        view;
    });

    self.controlHandlerImageView = ({
        UIImageView *view = [UIImageView new];
        view.userInteractionEnabled = YES;
        view.image = [UIImage imageNamed:@"JPVideoPlayer.bundle/jp_videoplayer_progress_handler"];
        [self addSubview:view];

        view;
    });

    UIPanGestureRecognizer *recognizer = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(panGestureDidChange:)];
    [self.controlHandlerImageView addGestureRecognizer:recognizer];
}

- (void)panGestureDidChange:(UIPanGestureRecognizer *)panGestureRecognizer {
    CGPoint transPoint = [panGestureRecognizer translationInView:panGestureRecognizer.view];
    CGFloat offsetX = transPoint.x;
    CGRect frame = panGestureRecognizer.view.frame;
    frame.origin.x += offsetX;
    [self updateElapsedProgressAndHandlerViewWithControlHandleViewOriginX:frame.origin.x];
    [self callTimeChangeDelegateMethod];
    [panGestureRecognizer setTranslation:CGPointZero inView:panGestureRecognizer.view];

    switch(panGestureRecognizer.state){
        case UIGestureRecognizerStateBegan:
            self.userDragging = YES;
            [NSNotificationCenter.defaultCenter postNotificationName:JPVideoPlayerProgressViewUserDidStartDragNotification object:self];
            break;

        case UIGestureRecognizerStateEnded:
            self.userDragging = NO;
            [self userDidFinishDrag];
            [NSNotificationCenter.defaultCenter postNotificationName:JPVideoPlayerProgressViewUserDidEndDragNotification object:self];
            break;

        default:
            break;
    }
}

- (void)callTimeChangeDelegateMethod {
    if (self.delegate && [self.delegate respondsToSelector:@selector(progressView:userDidDragToTime:totalSeconds:)]) {
        [self.delegate progressView:self
                  userDidDragToTime:[self fetchElapsedProgressRatio] * self.totalSeconds
                       totalSeconds:self.totalSeconds];
    }
}

- (void)updateElapsedProgressAndHandlerViewWithControlHandleViewOriginX:(CGFloat)controlHandleViewOriginX {
    CGRect frame = self.controlHandlerImageView.frame;
    CGFloat handlerWidth = frame.size.width;
    frame.origin.x = controlHandleViewOriginX;
    frame.origin.x = MAX(0, frame.origin.x);
    frame.origin.x = MIN((self.bounds.size.width - handlerWidth), frame.origin.x);
    self.controlHandlerImageView.frame = frame;
    CGRect elapsedFrame = self.elapsedProgressView.frame;
    elapsedFrame.size.width = frame.origin.x;
    self.elapsedProgressView.frame = elapsedFrame;
}

- (void)userDidFinishDrag {
    NSParameterAssert(!self.userDragging);
    if(!self.totalSeconds){
        return;
    }
    [self updateCacheProgressViewIfNeed];
    [self.playerView jp_seekToTime:CMTimeMakeWithSeconds([self fetchElapsedTimeInterval], 1000)];
}

- (void)updateCacheProgressViewIfNeed {
    [self displayCacheProgressViewIfNeed];
}

- (void)removeCacheProgressViewIfNeed {
    if(self.cachedProgressView.superview){
        [self.cachedProgressView removeFromSuperview];
    }
}

- (void)displayCacheProgressViewIfNeed {
    if(self.userDragging || !self.rangesValue.count){
        return;
    }

    [self removeCacheProgressViewIfNeed];
    NSRange targetRange = JPInvalidRange;
    NSUInteger dragStartLocation = [self fetchDragStartLocation];
    if(self.rangesValue.count == 1){
        if(JPValidFileRange([self.rangesValue.firstObject rangeValue])){
            targetRange = [self.rangesValue.firstObject rangeValue];
        }
    }
    else {
        // find the range that the closest to dragStartLocation.
        for(NSValue *value in self.rangesValue){
            NSRange range = [value rangeValue];
            NSUInteger distance = NSUIntegerMax;
            if(JPValidFileRange(range)){
                if(NSLocationInRange(dragStartLocation, range)){
                    targetRange = range;
                    break;
                }
                else {
                    NSUInteger deltaDistance = abs(range.location - dragStartLocation);
                    deltaDistance = abs(NSMaxRange(range) - dragStartLocation) < deltaDistance ?: deltaDistance;
                    if(deltaDistance < distance){
                       distance = deltaDistance;
                       targetRange = range;
                    }
                }
            }
        }
    }

    if(!JPValidFileRange(targetRange)){
        return;
    }
    CGFloat cacheProgressViewOriginX = targetRange.location * self.backgroundView.bounds.size.width / self.fileLength;
    CGFloat cacheProgressViewWidth = targetRange.length * self.backgroundView.bounds.size.width / self.fileLength;
    self.cachedProgressView.frame = CGRectMake(cacheProgressViewOriginX, 0, cacheProgressViewWidth, self.backgroundView.bounds.size.height);
    [self.backgroundView insertSubview:self.cachedProgressView belowSubview:self.elapsedProgressView];
}

- (NSUInteger)fetchDragStartLocation {
    return self.fileLength * [self fetchElapsedProgressRatio];
}

- (NSTimeInterval)fetchElapsedTimeInterval {
    return [self fetchElapsedProgressRatio] * self.totalSeconds;
}

- (CGFloat)fetchElapsedProgressRatio {
    CGFloat totalDragWidth = self.bounds.size.width - kJPVideoPlayerProgressViewWidth;
    // the view do not finish layout yet.
    if(totalDragWidth == 0){
        totalDragWidth = 1;
    }
    CGFloat delta = self.elapsedProgressView.frame.size.width / totalDragWidth;
    delta = MIN(delta, 1);
    delta = MAX(0, delta);
    return delta;
}

@end

@interface JPVideoPlayerControlBar()<JPVideoPlayerProtocol, JPVideoPlayerProgressViewDelegate>

@property (nonatomic, strong) UIButton *playButton;

@property (nonatomic, strong) JPVideoPlayerProgressView *progressView;

@property (nonatomic, strong) UILabel *timeLabel;

@property (nonatomic, strong) UIButton *landscapeButton;

@property (nonatomic, weak) UIView *playerView;

@end

@implementation JPVideoPlayerControlBar

- (instancetype)initWithProgressView:(UIView <JPVideoPlayerProtocol> *_Nullable)progressView {
    self = [super init];
    if (self) {
        _progressView = progressView;
        [self setup];
    }
    return self;
}

- (instancetype)init {
    NSAssert(NO, @"Please use given method to initialize this class.");
    return [self initWithProgressView:nil];
}

- (void)setFrame:(CGRect)frame {
    [super setFrame:frame];
    self.playButton.frame = CGRectMake(16, 10, 18, 18);
    self.landscapeButton.frame = CGRectMake(frame.size.width - 34, 10, 18, 18);
    self.timeLabel.frame = CGRectMake(self.landscapeButton.frame.origin.x - 86, 10, 72, 16);
    CGFloat progressViewWidth = self.timeLabel.frame.origin.x - self.playButton.frame.origin.x - self.playButton.frame.size.width - 12;
    self.progressView.frame = CGRectMake(40, 9, progressViewWidth, 20);
}

- (void)progressView:(JPVideoPlayerProgressView *)progressView
   userDidDragToTime:(NSTimeInterval)timeInterval
        totalSeconds:(NSTimeInterval)totalSeconds {
    [self updateTimeLabelWithElapsedSeconds:timeInterval totalSeconds:totalSeconds];
}


#pragma mark - JPVideoPlayerControlProtocol

- (void)viewWillAddToSuperView:(UIView *)view {
    self.playerView = view;
    [self updateTimeLabelWithElapsedSeconds:0 totalSeconds:0];
    [self.progressView viewWillAddToSuperView:view];
}

- (void)cacheRangeDidChange:(NSArray<NSValue *> *)cacheRanges {
    [self.progressView cacheRangeDidChange:cacheRanges];
}

- (void)playProgressDidChangeElapsedSeconds:(NSTimeInterval)elapsedSeconds
                               totalSeconds:(NSTimeInterval)totalSeconds {
    if(!self.progressView.userDragging){
        [self updateTimeLabelWithElapsedSeconds:elapsedSeconds totalSeconds:totalSeconds];
    }
    [self.progressView playProgressDidChangeElapsedSeconds:elapsedSeconds
                                              totalSeconds:totalSeconds];
}

- (void)didFetchVideoFileLength:(NSUInteger)videoLength {
    [self.progressView didFetchVideoFileLength:videoLength];
}


#pragma mark - Private

- (void)updateTimeLabelWithElapsedSeconds:(NSTimeInterval)elapsedSeconds
                             totalSeconds:(NSTimeInterval)totalSeconds {
    NSString *elapsedString = [self convertSecondsToTimeString:elapsedSeconds];
    NSString *totalString = [self convertSecondsToTimeString:totalSeconds];
    self.timeLabel.attributedText = [[NSAttributedString alloc] initWithString:[NSString stringWithFormat:@"%@/%@", elapsedString, totalString]
                                                                    attributes:@{
                                                                            NSFontAttributeName : [UIFont systemFontOfSize:10],
                                                                            NSForegroundColorAttributeName : [UIColor whiteColor]
                                                                    }];
}

- (NSString *)convertSecondsToTimeString:(NSTimeInterval)seconds {
    NSUInteger minute = (NSUInteger)(seconds / 60);
    NSUInteger second = (NSUInteger)((NSUInteger)seconds % 60);
    return [NSString stringWithFormat:@"%02ld:%02ld", minute, second];
}

- (void)playButtonDidClick:(UIButton *)button {
    button.selected = !button.selected;
    BOOL isPlay = self.playerView.jp_playerStatus == JPVideoPlayerStatusBuffering ||
            self.playerView.jp_playerStatus == JPVideoPlayerStatusPlaying;
    isPlay ? [self.playerView jp_pause] : [self.playerView jp_resume];
}

- (void)landscapeButtonDidClick:(UIButton *)button {
    self.playerView.jp_viewStatus == JPVideoPlayerVideoViewStatusPortrait ? [self.playerView jp_gotoLandscape] : [self.playerView jp_gotoPortrait];
}

- (void)setup {
    self.backgroundColor = [UIColor clearColor];

    self.playButton = ({
        UIButton *button = [UIButton new];
        [button setImage:[UIImage imageNamed:@"JPVideoPlayer.bundle/jp_videoplayer_pause"] forState:UIControlStateNormal];
        [button setImage:[UIImage imageNamed:@"JPVideoPlayer.bundle/jp_videoplayer_play"] forState:UIControlStateSelected];
        [button addTarget:self action:@selector(playButtonDidClick:) forControlEvents:UIControlEventTouchUpInside];
        [self addSubview:button];

        button;
    });

    if(!self.progressView){
        self.progressView = ({
            JPVideoPlayerProgressView *view = [JPVideoPlayerProgressView new];
            view.delegate = self;
            [self addSubview:view];

            view;
        });
    }

    self.timeLabel = ({
        UILabel *label = [UILabel new];
        [self addSubview:label];

        label;
    });

    self.landscapeButton = ({
        UIButton *button = [UIButton new];
        [button setImage:[UIImage imageNamed:@"JPVideoPlayer.bundle/jp_videoplayer_landscape"] forState:UIControlStateNormal];
        [button addTarget:self action:@selector(landscapeButtonDidClick:) forControlEvents:UIControlEventTouchUpInside];
        [self addSubview:button];

        button;
    });
}

@end

@interface JPVideoPlayerControlView()

@property (nonatomic, strong) JPVideoPlayerControlBar *controlBar;

@property (nonatomic, strong) UIImageView *blurImageView;

@end

static const CGFloat kJPVideoPlayerControlBarHeight = 38;
@implementation JPVideoPlayerControlView

- (instancetype)initWithControlBar:(UIView <JPVideoPlayerProtocol> *)controlBar
                         blurImage:(UIImage *)blurImage {
    self = [super initWithFrame:CGRectZero];
    if(self){
        _controlBar = controlBar;
        _blurImage = blurImage;
        [self setup];
    }
    return self;
}

- (instancetype)init {
    NSAssert(NO, @"Please use given method to initialize this class.");
    return [self initWithControlBar:nil blurImage:nil];
}

- (void)setFrame:(CGRect)frame {
    [super setFrame:frame];
    self.blurImageView.frame = self.bounds;
    self.controlBar.frame = CGRectMake(0, self.bounds.size.height - kJPVideoPlayerControlBarHeight, self.bounds.size.width, kJPVideoPlayerControlBarHeight);
}


#pragma mark - JPVideoPlayerControlProtocol

- (void)viewWillAddToSuperView:(UIView *)view {
    [self.controlBar viewWillAddToSuperView:view];
}

- (void)cacheRangeDidChange:(NSArray<NSValue *> *)cacheRanges {
    [self.controlBar cacheRangeDidChange:cacheRanges];
}

- (void)playProgressDidChangeElapsedSeconds:(NSTimeInterval)elapsedSeconds
                               totalSeconds:(NSTimeInterval)totalSeconds {
    [self.controlBar playProgressDidChangeElapsedSeconds:elapsedSeconds
                                            totalSeconds:totalSeconds];
}

- (void)didFetchVideoFileLength:(NSUInteger)videoLength {
    [self.controlBar didFetchVideoFileLength:videoLength];
}


#pragma mark - Setter

- (void)setElapsedProgressColor:(UIColor *)elapsedProgressColor {
    _elapsedProgressColor = elapsedProgressColor;
    self.controlBar.progressView.elapsedProgressView.backgroundColor = elapsedProgressColor;
}

- (void)setProgressBackgroundColor:(UIColor *)progressBackgroundColor {
    _progressBackgroundColor = progressBackgroundColor;
    self.controlBar.progressView.backgroundView.backgroundColor = progressBackgroundColor;
}

- (void)setCachedProgressColor:(UIColor *)cachedProgressColor {
    _cachedProgressColor = cachedProgressColor;
    self.controlBar.progressView.cachedProgressView.backgroundColor = cachedProgressColor;
}


#pragma mark - Private

- (void)setup {
    self.blurImageView = ({
        UIImageView *view = [UIImageView new];
        UIImage *blurImage = self.blurImage;
        if(!blurImage){
           blurImage = [UIImage imageNamed:@"JPVideoPlayer.bundle/jp_videoplayer_blur"];
        }
        view.image = blurImage;
        [self addSubview:view];

        view;
    });

    if(!self.controlBar){
        self.controlBar = ({
            JPVideoPlayerControlBar *bar = [[JPVideoPlayerControlBar alloc] initWithProgressView:nil];
            [self addSubview:bar];
            bar.progressView.backgroundView.backgroundColor = [UIColor colorWithWhite:1 alpha:0.2];
            bar.progressView.elapsedProgressView.backgroundColor = [UIColor colorWithRed:37.0/255 green:131.0/255 blue:232.0/255 alpha:1];
            bar.progressView.cachedProgressView.backgroundColor = [UIColor colorWithWhite:1 alpha:0.6];

            bar;
        });
    }
}

@end

@interface JPVideoPlayerView()

@property (nonatomic, strong) UIView *videoContainerView;

@property (nonatomic, strong) UIView *controlContainerView;

@property (nonatomic, strong) UIView *cacheIndicatorContainerView;

@property (nonatomic, strong) UIView *userInteractionContainerView;

@property (nonatomic, strong) NSTimer *timer;

@property(nonatomic, assign) BOOL isInterruptTimer;

@end

static const NSTimeInterval kJPControlViewAutoHiddenTimeInterval = 3;
@implementation JPVideoPlayerView

- (instancetype)init {
    self = [super init];
    if(self){
        [self setup];
    }
    return self;
}

- (void)setFrame:(CGRect)frame {
    [super setFrame:frame];
    self.videoContainerView.frame = self.bounds;
    self.controlContainerView.frame = self.bounds;
    self.cacheIndicatorContainerView.frame = self.bounds;
    self.userInteractionContainerView.frame = CGRectMake(0, 0, self.bounds.size.width, self.bounds.size.height - kJPVideoPlayerControlBarHeight);
    for(UIView *view in self.controlContainerView.subviews){
        view.frame = self.bounds;
    }
}

- (void)setBounds:(CGRect)bounds {
    [super setBounds:bounds];
    self.videoContainerView.frame = CGRectMake(self.videoContainerView.center.x - bounds.size.width * 0.5,
            self.videoContainerView.center.y - bounds.size.height * 0.5,
            bounds.size.width,
            bounds.size.height);
    self.controlContainerView.frame = CGRectMake(self.controlContainerView.center.x - bounds.size.width * 0.5,
            self.controlContainerView.center.y - bounds.size.height * 0.5,
            bounds.size.width,
            bounds.size.height);
    self.cacheIndicatorContainerView.frame = CGRectMake(self.cacheIndicatorContainerView.center.x - bounds.size.width * 0.5,
            self.cacheIndicatorContainerView.center.y - bounds.size.height * 0.5,
            bounds.size.width,
            bounds.size.height);
    self.userInteractionContainerView.frame = CGRectMake(self.userInteractionContainerView.center.x - bounds.size.width * 0.5,
            self.userInteractionContainerView.center.y - bounds.size.height * 0.5,
            bounds.size.width,
            bounds.size.height - kJPVideoPlayerControlBarHeight);
    for(UIView *view in self.controlContainerView.subviews){
        view.frame = CGRectMake(view.center.x - bounds.size.width * 0.5,
                view.center.y - bounds.size.height * 0.5,
                bounds.size.width,
                bounds.size.height);
    }
}

- (void)setCenter:(CGPoint)center {
    [super setCenter:center];
    self.videoContainerView.frame = CGRectMake(center.y - self.videoContainerView.bounds.size.width * 0.5,
            center.x - self.videoContainerView.bounds.size.height * 0.5,
            self.videoContainerView.bounds.size.width,
            self.videoContainerView.bounds.size.height);
    self.controlContainerView.frame = CGRectMake(center.y -  self.controlContainerView.bounds.size.width * 0.5,
            center.x -  self.controlContainerView.bounds.size.height * 0.5,
            self.controlContainerView.bounds.size.width,
            self.controlContainerView.bounds.size.height);
    self.cacheIndicatorContainerView.frame = CGRectMake(center.y -  self.cacheIndicatorContainerView.bounds.size.width * 0.5,
            center.x -  self.cacheIndicatorContainerView.bounds.size.height * 0.5,
            self.cacheIndicatorContainerView.bounds.size.width,
            self.cacheIndicatorContainerView.bounds.size.height);
    self.userInteractionContainerView.frame = CGRectMake(center.y -  self.userInteractionContainerView.bounds.size.width * 0.5,
            center.x -  self.userInteractionContainerView.bounds.size.height * 0.5,
            self.userInteractionContainerView.bounds.size.width,
            self.userInteractionContainerView.bounds.size.height - kJPVideoPlayerControlBarHeight);
    for(UIView *view in self.controlContainerView.subviews){
        view.frame = CGRectMake(center.y - view.bounds.size.width * 0.5,
                center.x - view.bounds.size.height * 0.5,
                view.bounds.size.width,
                view.bounds.size.height);
    }
}

- (CALayer *)videoContainerLayer {
    return self.videoContainerView.layer;
}

- (void)tapGestureDidTap {
    [UIView animateWithDuration:0.35
                          delay:0
                        options:UIViewAnimationCurveEaseOut
                     animations:^{
                         if(self.controlContainerView.alpha == 0){
                             self.controlContainerView.alpha = 1;
                             [self startTimer];
                         }
                         else {
                             self.controlContainerView.alpha = 0;
                             [self endTimer];
                         }

                     }
                     completion:^(BOOL finished) {

                     }];
}


#pragma mark - Setup

- (void)setup {
    self.backgroundColor = [UIColor blackColor];

    self.videoContainerView = ({
        UIView *view = [UIView new];
        view.backgroundColor = [UIColor clearColor];
        [self addSubview:view];
        view.userInteractionEnabled = NO;

        view;
    });

    self.controlContainerView = ({
        UIView *view = [UIView new];
        view.backgroundColor = [UIColor clearColor];
        [self addSubview:view];

        view;
    });

    self.cacheIndicatorContainerView = ({
        UIView *view = [UIView new];
        view.backgroundColor = [UIColor clearColor];
        [self addSubview:view];
        view.userInteractionEnabled = NO;

        view;
    });

    self.userInteractionContainerView = ({
        UIView *view = [UIView new];
        view.backgroundColor = [UIColor clearColor];
        [self addSubview:view];

        view;
    });

    UITapGestureRecognizer *tapGestureRecognizer = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(tapGestureDidTap)];
    [self.userInteractionContainerView addGestureRecognizer:tapGestureRecognizer];
    [self startTimer];

    [NSNotificationCenter.defaultCenter addObserver:self
                                           selector:@selector(didReceiveUserStartDragNotification)
                                               name:JPVideoPlayerProgressViewUserDidStartDragNotification
                                             object:nil];
    [NSNotificationCenter.defaultCenter addObserver:self
                                           selector:@selector(didReceiveUserEndDragNotification)
                                               name:JPVideoPlayerProgressViewUserDidEndDragNotification
                                             object:nil];
}

- (void)didReceiveUserStartDragNotification {
    if(self.timer){
        self.isInterruptTimer = YES;
        [self endTimer];
    }
}

- (void)didReceiveUserEndDragNotification {
    if(self.isInterruptTimer){
       [self startTimer];
    }
}

- (void)startTimer {
    if(!self.timer){
       self.timer = [NSTimer timerWithTimeInterval:kJPControlViewAutoHiddenTimeInterval
                                            target:self
                                          selector:@selector(timeDidChange:)
                                          userInfo:nil
                                           repeats:NO];
       [[NSRunLoop mainRunLoop] addTimer:self.timer forMode:NSRunLoopCommonModes];
    }

}

- (void)endTimer {
    if(self.timer){
       [self.timer invalidate];
       self.timer = nil;
    }
}

- (void)timeDidChange:(NSTimer *)timer {
    [self tapGestureDidTap];
    [self endTimer];
}

@end

CGFloat const JPVideoPlayerActivityIndicatorWH = 46;

@interface JPVideoPlayerActivityIndicator()

@property(nonatomic, strong, nullable)UIActivityIndicatorView *activityIndicator;

@property(nonatomic, strong, nullable)UIVisualEffectView *blurView;

@property(nonatomic, assign, getter=isAnimating)BOOL animating;

@end

@implementation JPVideoPlayerActivityIndicator

- (instancetype)init{
    self = [super init];
    if (self) {
        [self setup_];
    }
    return self;
}

- (void)layoutSubviews{
    [super layoutSubviews];

    self.blurView.frame = self.bounds;
    self.activityIndicator.frame = self.bounds;
}


#pragma mark - Public

- (void)startAnimating{
    if (!self.isAnimating) {
        self.hidden = NO;
        [self.activityIndicator startAnimating];
        self.animating = YES;
    }
}

- (void)stopAnimating{
    if (self.isAnimating) {
        self.hidden = YES;
        [self.activityIndicator stopAnimating];
        self.animating = NO;
    }
}


#pragma mark - Private

- (void)setup_{
    self.backgroundColor = [UIColor clearColor];
    self.layer.cornerRadius = 8;
    self.clipsToBounds = YES;

    UIVisualEffectView *blurView = [[UIVisualEffectView alloc]initWithEffect:[UIBlurEffect effectWithStyle:UIBlurEffectStyleLight]];
    [self addSubview:blurView];
    self.blurView = blurView;

    UIActivityIndicatorView *indicator = [UIActivityIndicatorView new];
    indicator.activityIndicatorViewStyle = UIActivityIndicatorViewStyleGray;
    indicator.color = [UIColor colorWithRed:35.0/255 green:35.0/255 blue:35.0/255 alpha:1];
    [self addSubview:indicator];
    self.activityIndicator = indicator;

    self.animating = NO;
}

@end
