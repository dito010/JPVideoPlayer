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

@interface JPVideoPlayerProgressView : UIView<JPVideoPlayerProtocol>

@property (nonatomic, strong) UIImageView *controlHandlerView;

@property (nonatomic, strong) UIView *backgroundView;

@property (nonatomic, strong) NSArray<NSValue *> *rangesValue;

@property(nonatomic, assign) NSUInteger fileLength;

@property(nonatomic, assign) NSTimeInterval totalSeconds;

@property (nonatomic, strong) UIView *elapsedProgressView;

@property (nonatomic, strong) UIView *cachedProgressView;

@property(nonatomic, assign) BOOL userDragging;

@property (nonatomic, weak) UIView *playerView;

@end

static const CGFloat kJPVideoPlayerProgressViewEaseTouchEdgeWidth = 2;
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

    if(!self.backgroundView.frame.size.height && self.bounds.size.width) {
        CGSize referSize = self.bounds.size;
        self.controlHandlerView.frame = CGRectMake(-kJPVideoPlayerProgressViewEaseTouchEdgeWidth, 0, 20, 20);
        self.backgroundView.frame = CGRectMake(0, (referSize.height - 2) * 0.5, referSize.width, 2);
        self.elapsedProgressView.frame = CGRectMake(0, (referSize.height - 2) * 0.5, 0, 2);
    }
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

    CGRect frame = self.controlHandlerView.frame;
    CGFloat handlerWidth = frame.size.width;
    CGFloat controlHandleViewOriginX = (self.bounds.size.width - handlerWidth + kJPVideoPlayerProgressViewEaseTouchEdgeWidth * 2) * (elapsedSeconds / totalSeconds) - kJPVideoPlayerProgressViewEaseTouchEdgeWidth;
    [self updateElapsedProgressWithControlHandleViewOriginX:controlHandleViewOriginX];
    self.totalSeconds = totalSeconds;
    //TODO: 进度条更新完成, 接下来做用户点击事件.
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
        [self addSubview:view];

        view;
    });

    self.controlHandlerView = ({
        UIImageView *view = [UIImageView new];
        view.userInteractionEnabled = YES;
        view.image = [UIImage imageNamed:@"JPVideoPlayer.bundle/jp_videoplayer_progress_handler"];
        [self addSubview:view];

        view;
    });

    UIPanGestureRecognizer *recognizer = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(panGestureDidChange:)];
    [self.controlHandlerView addGestureRecognizer:recognizer];
}

- (void)updateElapsedProgressWithControlHandleViewOriginX:(CGFloat)controlHandleViewOriginX {
    CGRect frame = self.controlHandlerView.frame;
    CGFloat handlerWidth = frame.size.width;
    frame.origin.x = controlHandleViewOriginX;
    frame.origin.x = MAX(-kJPVideoPlayerProgressViewEaseTouchEdgeWidth, frame.origin.x);
    frame.origin.x = MIN((self.bounds.size.width - handlerWidth + kJPVideoPlayerProgressViewEaseTouchEdgeWidth), frame.origin.x);
    self.controlHandlerView.frame = frame;
    CGRect elapsedFrame = self.elapsedProgressView.frame;
    elapsedFrame.size.width = frame.origin.x + kJPVideoPlayerProgressViewEaseTouchEdgeWidth;
    self.elapsedProgressView.frame = elapsedFrame;
}

- (void)panGestureDidChange:(UIPanGestureRecognizer *)panGestureRecognizer {
    CGPoint transPoint = [panGestureRecognizer translationInView:panGestureRecognizer.view];
    CGFloat offsetX = transPoint.x;
    CGRect frame = panGestureRecognizer.view.frame;
    frame.origin.x += offsetX;
    [self updateElapsedProgressWithControlHandleViewOriginX:frame.origin.x];

    [panGestureRecognizer setTranslation:CGPointZero inView:panGestureRecognizer.view];

    switch(panGestureRecognizer.state){
        case UIGestureRecognizerStateBegan:
            self.userDragging = YES;
            break;

        case UIGestureRecognizerStateEnded:
            self.userDragging = NO;
            [self userDidFinishDrag];
            break;

        default:
            break;
    }
}

- (void)userDidFinishDrag {
    NSParameterAssert(!self.userDragging);
    if(!self.totalSeconds){
        return;
    }
    [self.playerView jp_seekToTime:CMTimeMakeWithSeconds([self fetchElapsedTimeInterval], 1)];
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
        for(NSValue *value in self.rangesValue){
            NSRange range = [value rangeValue];
            if(JPValidFileRange(range)){
                if(NSLocationInRange(dragStartLocation, range)){
                    targetRange = range;
                    break;
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
    [self.backgroundView addSubview:self.cachedProgressView];
}

- (NSUInteger)fetchDragStartLocation {
    return self.fileLength * [self fetchElapsedProgressRatio];
}

- (NSTimeInterval)fetchElapsedTimeInterval {
    return [self fetchElapsedProgressRatio] * self.totalSeconds;
}

- (CGFloat)fetchElapsedProgressRatio {
    CGFloat totalDragWidth = self.bounds.size.width - self.controlHandlerView.bounds.size.width;
    // the view do not finish layout yet.
    if(totalDragWidth == 0){
        totalDragWidth = 1;
    }
    CGFloat delta = self.elapsedProgressView.frame.size.width / totalDragWidth;
    NSParameterAssert(delta >= 0 && delta <= 1);
    return delta;
}

@end

@interface JPVideoPlayerControlBar()<JPVideoPlayerProtocol>

@property (nonatomic, strong) UIButton *playButton;

@property (nonatomic, strong) JPVideoPlayerProgressView *progressView;

@property (nonatomic, strong) UILabel *timeLabel;

@property (nonatomic, strong) UIButton *landscapeButton;

@end

@implementation JPVideoPlayerControlBar

- (instancetype)init {
    self = [super init];
    if (self) {
        [self setup];
    }
    return self;
}

- (void)setFrame:(CGRect)frame {
    [super setFrame:frame];

    CGSize screenSize = [UIScreen.mainScreen bounds].size;
    self.playButton.frame = CGRectMake(16, 10, 18, 18);
    self.landscapeButton.frame = CGRectMake(screenSize.width - 34, 10, 18, 18);
    self.timeLabel.frame = CGRectMake(self.landscapeButton.frame.origin.x - 86, 10, 72, 16);
    CGFloat progressViewWidth = self.timeLabel.frame.origin.x - self.playButton.frame.origin.x - self.playButton.frame.size.width - 32;
    self.progressView.frame = CGRectMake(45, 9, progressViewWidth, 20);
}


#pragma mark - JPVideoPlayerControlProtocol

- (void)viewWillAddToSuperView:(UIView *)view {
    [self.progressView viewWillAddToSuperView:view];
}

- (void)cacheRangeDidChange:(NSArray<NSValue *> *)cacheRanges {
    [self.progressView cacheRangeDidChange:cacheRanges];
}

- (void)playProgressDidChangeElapsedSeconds:(NSTimeInterval)elapsedSeconds
                               totalSeconds:(NSTimeInterval)totalSeconds {
    NSString *elapsedString = [self convertSecondsToTimeString:elapsedSeconds];
    NSString *totalString = [self convertSecondsToTimeString:totalSeconds];
    self.timeLabel.attributedText = [[NSAttributedString alloc] initWithString:[NSString stringWithFormat:@"%@/%@", elapsedString, totalString]
                                                                    attributes:@{
                                                                            NSFontAttributeName : [UIFont systemFontOfSize:10],
                                                                            NSForegroundColorAttributeName : [UIColor whiteColor]
                                                                    }];
    [self.progressView playProgressDidChangeElapsedSeconds:elapsedSeconds
                                              totalSeconds:totalSeconds];
}

- (void)didFetchVideoFileLength:(NSUInteger)videoLength {
    [self.progressView didFetchVideoFileLength:videoLength];
}


#pragma mark - Private

- (NSString *)convertSecondsToTimeString:(NSTimeInterval)seconds {
    NSUInteger minute = (NSUInteger)(seconds / 60);
    NSUInteger second = (NSUInteger)((NSUInteger)seconds % 60);
    return [NSString stringWithFormat:@"%02ld:%02ld", minute, second];
}

- (void)playButtonDidClick:(UIButton *)button {
}

- (void)landscapeButtonDidClick:(UIButton *)button {
}

- (void)setup {
    self.backgroundColor = [UIColor clearColor];

    self.playButton = ({
        UIButton *button = [UIButton new];
        [button setImage:[UIImage imageNamed:@"JPVideoPlayer.bundle/jp_videoplayer_pause"] forState:UIControlStateNormal];
        [button setImage:[UIImage imageNamed:@"JPVideoPlayer.bundle/jp_videoplayer_play"] forState:UIControlStateSelected];
        [button addTarget:self action:@selector(playButtonDidClick:) forControlEvents:UIControlEventTouchDragInside];
        [self addSubview:button];

        button;
    });

    self.progressView = ({
        JPVideoPlayerProgressView *view = [JPVideoPlayerProgressView new];
        [self addSubview:view];

        view;
    });

    self.timeLabel = ({
        UILabel *label = [UILabel new];
        [self addSubview:label];

        label;
    });

    self.landscapeButton = ({
        UIButton *button = [UIButton new];
        [button setImage:[UIImage imageNamed:@"JPVideoPlayer.bundle/jp_videoplayer_landscape"] forState:UIControlStateNormal];
        [button addTarget:self action:@selector(landscapeButtonDidClick:) forControlEvents:UIControlEventTouchDragInside];
        [self addSubview:button];

        button;
    });
}

@end

@interface JPVideoPlayerControlView()

@property (nonatomic, strong) JPVideoPlayerControlBar *controlBar;

@property (nonatomic, strong) UIImageView *blurImageView;

@end

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
    self.controlBar.frame = CGRectMake(0, self.bounds.size.height - 38, self.bounds.size.width, 38);
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
            JPVideoPlayerControlBar *bar = [JPVideoPlayerControlBar new];
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

@end

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
}

- (CALayer *)videoContainerLayer {
    return self.videoContainerView.layer;
}


#pragma mark - Setup

- (void)setup {
    self.backgroundColor = [UIColor blackColor];

    self.videoContainerView = ({
        UIView *view = [UIView new];
        view.backgroundColor = [UIColor clearColor];
        [self addSubview:view];

        view;
    });

    self.controlContainerView = ({
        UIView *view = [UIView new];
        view.backgroundColor = [UIColor clearColor];
        [self addSubview:view];

        view;
    });
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
