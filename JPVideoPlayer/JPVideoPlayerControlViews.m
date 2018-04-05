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

@interface JPVideoPlayerControlProgressView()

@property (nonatomic, strong) NSArray<NSValue *> *rangesValue;

@property(nonatomic, assign) NSUInteger fileLength;

@property(nonatomic, assign) NSTimeInterval totalSeconds;

@property(nonatomic, assign) NSTimeInterval elapsedSeconds;

@property (nonatomic, strong) UISlider *dragSlider;

@property (nonatomic, strong) UIView *cachedProgressView;

@property (nonatomic, strong) UIProgressView *trackProgressView;

@property(nonatomic, assign) BOOL userDragging;

@property (nonatomic, weak) UIView *playerView;

@end

static const CGFloat kJPVideoPlayerDragSliderLeftEdge = 2;
static const CGFloat kJPVideoPlayerCachedProgressViewHeight = 2;
NSString *JPVideoPlayerControlProgressViewUserDidStartDragNotification = @"com.jpvideoplayer.progressview.user.drag.start.www";
NSString *JPVideoPlayerControlProgressViewUserDidEndDragNotification = @"com.jpvideoplayer.progressview.user.drag.end.www";;
@implementation JPVideoPlayerControlProgressView

- (instancetype)init {
    self = [super init];
    if (self) {
        [self _setup];
    }
    return self;
}

- (void)setFrame:(CGRect)frame {
    [super setFrame:frame];

    CGSize referenceSize = self.bounds.size;
    self.trackProgressView.frame = CGRectMake(kJPVideoPlayerDragSliderLeftEdge,
            (referenceSize.height - kJPVideoPlayerCachedProgressViewHeight) * 0.5,
            referenceSize.width - 2 * kJPVideoPlayerDragSliderLeftEdge, kJPVideoPlayerCachedProgressViewHeight);
    self.dragSlider.frame = self.bounds;
    [self updateCacheProgressViewIfNeed];
    [self playProgressDidChangeElapsedSeconds:self.elapsedSeconds
                                 totalSeconds:self.totalSeconds];
}


#pragma mark - JPVideoPlayerControlProtocol

- (void)viewWillAddToSuperView:(UIView *)view {
    self.playerView = view;
}

- (void)viewWillPrepareToReuse {
    [self cacheRangeDidChange:nil];
    [self playProgressDidChangeElapsedSeconds:0 totalSeconds:1];
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

    if(totalSeconds == 0){
       totalSeconds = 1;
    }

    float delta = elapsedSeconds / totalSeconds;
    NSParameterAssert(delta >= 0);
    NSParameterAssert(delta <= 1);
    delta = MIN(1, delta);
    delta = MAX(0, delta);
    [self.dragSlider setValue:delta animated:YES];
    self.totalSeconds = totalSeconds;
    self.elapsedSeconds = elapsedSeconds;
}

- (void)didFetchVideoFileLength:(NSUInteger)videoLength {
    self.fileLength = videoLength;
}


#pragma mark - Private

- (void)_setup {
    self.trackProgressView = ({
        UIProgressView *view = [UIProgressView new];
        [self addSubview:view];

        view;
    });

    self.cachedProgressView = ({
        UIView *view = [UIView new];
        [self.trackProgressView addSubview:view];
        view.clipsToBounds = YES;
        view.layer.cornerRadius = 1;

        view;
    });

    self.dragSlider = ({
        UISlider *view = [UISlider new];
        [view setThumbImage:[UIImage imageNamed:@"JPVideoPlayer.bundle/jp_videoplayer_progress_handler_normal"] forState:UIControlStateNormal];
        [view setThumbImage:[UIImage imageNamed:@"JPVideoPlayer.bundle/jp_videoplayer_progress_handler_hightlight"] forState:UIControlStateHighlighted];
        view.maximumTrackTintColor = [UIColor clearColor];
        [view addTarget:self action:@selector(dragSliderDidDrag:) forControlEvents:UIControlEventValueChanged];
        [view addTarget:self action:@selector(dragSliderDidStart:) forControlEvents:UIControlEventTouchDown];
        [view addTarget:self action:@selector(dragSliderDidEnd:) forControlEvents:UIControlEventTouchUpInside];
        [self addSubview:view];

        view;
    });
}

- (void)dragSliderDidStart:(UISlider *)slider {
    self.userDragging = YES;
    [NSNotificationCenter.defaultCenter postNotificationName:JPVideoPlayerControlProgressViewUserDidStartDragNotification object:self];
}

- (void)dragSliderDidDrag:(UISlider *)slider {
    [self callTimeChangeDelegateMethod];
}

- (void)dragSliderDidEnd:(UISlider *)slider {
    self.userDragging = NO;
    [self userDidFinishDrag];
    [NSNotificationCenter.defaultCenter postNotificationName:JPVideoPlayerControlProgressViewUserDidEndDragNotification object:self];
}

- (void)callTimeChangeDelegateMethod {
    if (self.delegate && [self.delegate respondsToSelector:@selector(progressView:userDidDragToTime:totalSeconds:)]) {
        [self.delegate progressView:self
                  userDidDragToTime:self.dragSlider.value * self.totalSeconds
                       totalSeconds:self.totalSeconds];
    }
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
    CGFloat cacheProgressViewOriginX = targetRange.location * self.trackProgressView.bounds.size.width / self.fileLength;
    CGFloat cacheProgressViewWidth = targetRange.length * self.trackProgressView.bounds.size.width / self.fileLength;
    self.cachedProgressView.frame = CGRectMake(cacheProgressViewOriginX, 0, cacheProgressViewWidth, self.trackProgressView.bounds.size.height);
    [self.trackProgressView addSubview:self.cachedProgressView];
}

- (NSUInteger)fetchDragStartLocation {
    return self.fileLength * self.dragSlider.value;
}

- (NSTimeInterval)fetchElapsedTimeInterval {
    return self.dragSlider.value * self.totalSeconds;
}

@end

@interface JPVideoPlayerControlBar()<JPVideoPlayerProgressProtocol, JPVideoPlayerControlProgressViewDelegate>

@property (nonatomic, strong) UIButton *playButton;

@property (nonatomic, strong) JPVideoPlayerControlProgressView *progressView;

@property (nonatomic, strong) UILabel *timeLabel;

@property (nonatomic, strong) UIButton *landscapeButton;

@property (nonatomic, weak) UIView *playerView;

@end

static const CGFloat kJPVideoPlayerControlBarButtonWidthHeight = 22;
static const CGFloat kJPVideoPlayerControlBarElementGap = 16;
static const CGFloat kJPVideoPlayerControlBarTimeLabelWidth = 68;
@implementation JPVideoPlayerControlBar

- (instancetype)initWithProgressView:(UIView <JPVideoPlayerProgressProtocol> *_Nullable)progressView {
    self = [super init];
    if (self) {
        _progressView = progressView;
        [self _setup];
    }
    return self;
}

- (instancetype)init {
    NSAssert(NO, @"Please use given method to initialize this class.");
    return [self initWithProgressView:nil];
}

- (void)setFrame:(CGRect)frame {
    [super setFrame:frame];
    CGSize referenceSize = self.bounds.size;
    CGFloat elementOriginY = (referenceSize.height - kJPVideoPlayerControlBarButtonWidthHeight) * 0.5;
    self.playButton.frame = CGRectMake(kJPVideoPlayerControlBarElementGap,
            elementOriginY,
            kJPVideoPlayerControlBarButtonWidthHeight,
            kJPVideoPlayerControlBarButtonWidthHeight);
    self.landscapeButton.frame = CGRectMake(referenceSize.width - kJPVideoPlayerControlBarElementGap - kJPVideoPlayerControlBarButtonWidthHeight,
            elementOriginY,
            kJPVideoPlayerControlBarButtonWidthHeight,
            kJPVideoPlayerControlBarButtonWidthHeight);
    self.timeLabel.frame = CGRectMake(self.landscapeButton.frame.origin.x - kJPVideoPlayerControlBarTimeLabelWidth - kJPVideoPlayerControlBarElementGap,
            elementOriginY,
            kJPVideoPlayerControlBarTimeLabelWidth,
            kJPVideoPlayerControlBarButtonWidthHeight);
    CGFloat progressViewOriginX = self.playButton.frame.origin.x + self.playButton.frame.size.width + kJPVideoPlayerControlBarElementGap;
    CGFloat progressViewWidth = self.timeLabel.frame.origin.x - progressViewOriginX - kJPVideoPlayerControlBarElementGap;
    self.progressView.frame = CGRectMake(progressViewOriginX,
            elementOriginY,
            progressViewWidth,
            kJPVideoPlayerControlBarButtonWidthHeight);
}

- (void)progressView:(JPVideoPlayerControlProgressView *)progressView
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

- (void)viewWillPrepareToReuse {
    [self updateTimeLabelWithElapsedSeconds:0 totalSeconds:0];
    [self.progressView viewWillPrepareToReuse];
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
    button.selected = !button.selected;
    self.playerView.jp_viewStatus == JPVideoPlayerVideoViewStatusPortrait ? [self.playerView jp_gotoLandscape] : [self.playerView jp_gotoPortrait];
}

- (void)_setup {
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
            JPVideoPlayerControlProgressView *view = [JPVideoPlayerControlProgressView new];
            view.delegate = self;
            [self addSubview:view];

            view;
        });
    }

    self.timeLabel = ({
        UILabel *label = [UILabel new];
        label.textAlignment = NSTextAlignmentCenter;
        [self addSubview:label];

        label;
    });

    self.landscapeButton = ({
        UIButton *button = [UIButton new];
        [button setImage:[UIImage imageNamed:@"JPVideoPlayer.bundle/jp_videoplayer_landscape"] forState:UIControlStateNormal];
        [button setImage:[UIImage imageNamed:@"JPVideoPlayer.bundle/jp_videoplayer_portrait"] forState:UIControlStateSelected];
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
static const CGFloat kJPVideoPlayerControlBarLandscapeUpOffset = 12;
@implementation JPVideoPlayerControlView

- (instancetype)initWithControlBar:(UIView <JPVideoPlayerProgressProtocol> *)controlBar
                         blurImage:(UIImage *)blurImage {
    self = [super initWithFrame:CGRectZero];
    if(self){
        _controlBar = controlBar;
        _blurImage = blurImage;
        [self _setup];
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
    CGRect controlBarFrame = CGRectMake(0,
            self.bounds.size.height - kJPVideoPlayerControlBarHeight,
            self.bounds.size.width,
            kJPVideoPlayerControlBarHeight);
    if(self.bounds.size.width == [UIScreen mainScreen].bounds.size.height){ // landscape.
        controlBarFrame = CGRectMake(0,
                self.bounds.size.height - kJPVideoPlayerControlBarHeight - kJPVideoPlayerControlBarLandscapeUpOffset,
                self.bounds.size.width,
                kJPVideoPlayerControlBarHeight);
    }
    self.controlBar.frame = controlBarFrame;
}


#pragma mark - JPVideoPlayerControlProtocol

- (void)viewWillAddToSuperView:(UIView *)view {
    [self.controlBar viewWillAddToSuperView:view];
}

- (void)viewWillPrepareToReuse {
    [self.controlBar viewWillPrepareToReuse];
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


#pragma mark - Private

- (void)_setup {
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
            bar.progressView.trackProgressView.trackTintColor = [UIColor colorWithWhite:1 alpha:0.15];
            bar.progressView.cachedProgressView.backgroundColor = [UIColor colorWithWhite:1 alpha:0.3];

            bar;
        });
    }
}

@end

@interface JPVideoPlayerProgressView()

@property (nonatomic, strong) UIProgressView *trackProgressView;

@property (nonatomic, strong) UIView *cachedProgressView;

@property (nonatomic, strong) UIProgressView *elapsedProgressView;

@property (nonatomic, strong) NSArray<NSValue *> *rangesValue;

@property(nonatomic, assign) NSUInteger fileLength;

@property(nonatomic, assign) NSTimeInterval totalSeconds;

@property(nonatomic, assign) NSTimeInterval elapsedSeconds;

@end

static const CGFloat kJPVideoPlayerProgressViewEelementHeight = 2;
@implementation JPVideoPlayerProgressView

- (instancetype)init {
    self = [super init];
    if(self){
        [self _setup];
    }
    return self;
}

- (void)setFrame:(CGRect)frame {
    [super setFrame:frame];

    self.trackProgressView.frame = CGRectMake(0,
            frame.size.height - kJPVideoPlayerProgressViewEelementHeight,
            frame.size.width,
            kJPVideoPlayerProgressViewEelementHeight);
    self.cachedProgressView.frame = self.trackProgressView.bounds;
    self.elapsedProgressView.frame = self.trackProgressView.frame;
}

#pragma mark - Setup

- (void)_setup {
    self.trackProgressView = ({
        UIProgressView *view = [UIProgressView new];
        view.trackTintColor = [UIColor colorWithWhite:1 alpha:0.15];
        [self addSubview:view];

        view;
    });

    self.cachedProgressView = ({
        UIView *view = [UIView new];
        view.backgroundColor = [UIColor colorWithWhite:1 alpha:0.3];
        [self.trackProgressView addSubview:view];

        view;
    });

    self.elapsedProgressView = ({
        UIProgressView *view = [UIProgressView new];
        view.trackTintColor = [UIColor clearColor];
        [self addSubview:view];

        view;
    });
}



#pragma mark - JPVideoPlayerControlProtocol

- (void)viewWillAddToSuperView:(UIView *)view {
}

- (void)viewWillPrepareToReuse {
    [self cacheRangeDidChange:nil];
    [self playProgressDidChangeElapsedSeconds:0 totalSeconds:1];
}

- (void)cacheRangeDidChange:(NSArray<NSValue *> *)cacheRanges {
    _rangesValue = cacheRanges;
    [self displayCacheProgressViewIfNeed];
}

- (void)playProgressDidChangeElapsedSeconds:(NSTimeInterval)elapsedSeconds
                               totalSeconds:(NSTimeInterval)totalSeconds {
    if(totalSeconds == 0){
        totalSeconds = 1;
    }

    float delta = elapsedSeconds / totalSeconds;
    NSParameterAssert(delta >= 0);
    NSParameterAssert(delta <= 1);
    delta = MIN(1, delta);
    delta = MAX(0, delta);
    [self.elapsedProgressView setProgress:delta animated:YES];
    self.totalSeconds = totalSeconds;
    self.elapsedSeconds = elapsedSeconds;
}

- (void)didFetchVideoFileLength:(NSUInteger)videoLength {
    self.fileLength = videoLength;
}

- (void)displayCacheProgressViewIfNeed {
    if(!self.rangesValue.count){
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
    CGFloat cacheProgressViewOriginX = targetRange.location * self.trackProgressView.bounds.size.width / self.fileLength;
    CGFloat cacheProgressViewWidth = targetRange.length * self.trackProgressView.bounds.size.width / self.fileLength;
    self.cachedProgressView.frame = CGRectMake(cacheProgressViewOriginX, 0, cacheProgressViewWidth, self.trackProgressView.bounds.size.height);
    [self.trackProgressView addSubview:self.cachedProgressView];
}

- (void)removeCacheProgressViewIfNeed {
    if(self.cachedProgressView.superview){
        [self.cachedProgressView removeFromSuperview];
    }
}

- (NSUInteger)fetchDragStartLocation {
    return self.fileLength * self.elapsedProgressView.progress;
}

@end

@interface JPVideoPlayerBufferingIndicator()

@property(nonatomic, strong)UIActivityIndicatorView *activityIndicator;

@property(nonatomic, strong)UIVisualEffectView *blurView;

@property(nonatomic, assign, getter=isAnimating)BOOL animating;

@property (nonatomic, strong) UIView *blurBackgroundView;

@end

CGFloat const JPVideoPlayerBufferingIndicatorWidthHeight = 46;
@implementation JPVideoPlayerBufferingIndicator

- (instancetype)init {
    self = [super init];
    if (self) {
        [self _setup];
    }
    return self;
}

- (void)setFrame:(CGRect)frame {
    [super setFrame:frame];

    CGSize referenceSize = frame.size;
    self.blurBackgroundView.frame = CGRectMake((referenceSize.width - JPVideoPlayerBufferingIndicatorWidthHeight) * 0.5,
            (referenceSize.height - JPVideoPlayerBufferingIndicatorWidthHeight) * 0.5,
            JPVideoPlayerBufferingIndicatorWidthHeight,
            JPVideoPlayerBufferingIndicatorWidthHeight);
    self.activityIndicator.frame = self.blurBackgroundView.bounds;
    self.blurView.frame = self.blurBackgroundView.bounds;
}

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


#pragma mark - JPVideoPlayerBufferingProtocol

- (void)didStartBuffering {
    [self startAnimating];
}

- (void)didFinishBuffering {
    [self stopAnimating];
}


#pragma mark - Private

- (void)_setup{
    self.backgroundColor = [UIColor clearColor];

    self.blurBackgroundView = ({
        UIView *view = [UIView new];
        view.backgroundColor = [UIColor colorWithWhite:1 alpha:0.6];
        view.layer.cornerRadius = 10;
        view.clipsToBounds = YES;
        [self addSubview:view];

        view;
    });

    self.blurView = ({
        UIVisualEffectView *blurView = [[UIVisualEffectView alloc]initWithEffect:[UIBlurEffect effectWithStyle:UIBlurEffectStyleLight]];
        [self.blurBackgroundView addSubview:blurView];

        blurView;
    });

    self.activityIndicator = ({
        UIActivityIndicatorView *indicator = [UIActivityIndicatorView new];
        indicator.activityIndicatorViewStyle = UIActivityIndicatorViewStyleGray;
        indicator.color = [UIColor colorWithRed:35.0/255 green:35.0/255 blue:35.0/255 alpha:1];
        [self.blurBackgroundView addSubview:indicator];

        indicator;
    });

    self.animating = NO;
}

@end

@interface JPVideoPlayerView()

@property (nonatomic, strong) UIView *videoContainerView;

@property (nonatomic, strong) UIView *controlContainerView;

@property (nonatomic, strong) UIView *progressContainerView;

@property (nonatomic, strong) UIView *bufferingIndicatorContainerView;

@property (nonatomic, strong) UIView *userInteractionContainerView;

@property (nonatomic, strong) NSTimer *timer;

@property(nonatomic, assign) BOOL isInterruptTimer;

@end

static const NSTimeInterval kJPControlViewAutoHiddenTimeInterval = 5;
@implementation JPVideoPlayerView

- (void)dealloc {
    [NSNotificationCenter.defaultCenter removeObserver:self];
}

- (instancetype)init {
    self = [super init];
    if(self){
        [self _setup];
    }
    return self;
}

- (void)setFrame:(CGRect)frame {
    [super setFrame:frame];
    self.videoContainerView.frame = self.bounds;
    self.controlContainerView.frame = self.bounds;
    self.progressContainerView.frame = self.bounds;
    self.bufferingIndicatorContainerView.frame = self.bounds;
    self.userInteractionContainerView.frame = CGRectMake(0, 0, self.bounds.size.width, self.bounds.size.height - kJPVideoPlayerControlBarHeight);
    for(UIView *view in self.controlContainerView.subviews){
        view.frame = self.bounds;
    }
    for(UIView *view in self.progressContainerView.subviews){
        view.frame = self.bounds;
    }
    for(UIView *view in self.bufferingIndicatorContainerView.subviews){
        view.frame = self.bounds;
    }
}

- (void)setBounds:(CGRect)bounds {
    [super setBounds:bounds];
    self.videoContainerView.frame = CGRectMake(self.videoContainerView.center.x - bounds.size.width * 0.5,
            self.videoContainerView.center.y - bounds.size.height * 0.5,
            bounds.size.width,
            bounds.size.height);
    self.controlContainerView.frame = self.videoContainerView.frame;
    self.progressContainerView.frame = self.videoContainerView.frame;
    self.bufferingIndicatorContainerView.frame = self.videoContainerView.frame;
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
    for(UIView *view in self.progressContainerView.subviews){
        view.frame = CGRectMake(view.center.x - bounds.size.width * 0.5,
                view.center.y - bounds.size.height * 0.5,
                bounds.size.width,
                bounds.size.height);
    }
    for(UIView *view in self.bufferingIndicatorContainerView.subviews){
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
    self.controlContainerView.frame = self.videoContainerView.frame;
    self.progressContainerView.frame = self.videoContainerView.frame;
    self.bufferingIndicatorContainerView.frame = self.videoContainerView.frame;
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
    for(UIView *view in self.progressContainerView.subviews){
        view.frame = CGRectMake(center.y - view.bounds.size.width * 0.5,
                center.x - view.bounds.size.height * 0.5,
                view.bounds.size.width,
                view.bounds.size.height);
    }
    for(UIView *view in self.bufferingIndicatorContainerView.subviews){
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
                             self.progressContainerView.alpha = 0;
                             [self startTimer];
                         }
                         else {
                             self.controlContainerView.alpha = 0;
                             self.progressContainerView.alpha = 1;
                             [self endTimer];
                         }

                     }
                     completion:^(BOOL finished) {

                     }];
}


#pragma mark - Setup

- (void)_setup {
    self.backgroundColor = [UIColor blackColor];

    self.videoContainerView = ({
        UIView *view = [UIView new];
        view.backgroundColor = [UIColor clearColor];
        [self addSubview:view];
        view.userInteractionEnabled = NO;

        view;
    });

    self.bufferingIndicatorContainerView = ({
        UIView *view = [UIView new];
        view.backgroundColor = [UIColor clearColor];
        [self addSubview:view];
        view.userInteractionEnabled = NO;

        view;
    });

    self.progressContainerView = ({
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
                                               name:JPVideoPlayerControlProgressViewUserDidStartDragNotification
                                             object:nil];
    [NSNotificationCenter.defaultCenter addObserver:self
                                           selector:@selector(didReceiveUserEndDragNotification)
                                               name:JPVideoPlayerControlProgressViewUserDidEndDragNotification
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
