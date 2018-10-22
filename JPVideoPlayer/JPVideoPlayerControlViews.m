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

@property (nonatomic, weak) UIView *playerView;

@end

static const CGFloat kJPVideoPlayerDragSliderLeftEdge = 2;
static const CGFloat kJPVideoPlayerCachedProgressViewHeight = 2;
NSString *JPVideoPlayerControlProgressViewUserDidStartDragNotification = @"com.jpvideoplayer.progressview.user.drag.start.www";
NSString *JPVideoPlayerControlProgressViewUserDidEndDragNotification = @"com.jpvideoplayer.progressview.user.drag.end.www";;
@implementation JPVideoPlayerControlProgressView {
    BOOL _userDragging;
    NSTimeInterval _userDragTimeInterval;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        [self _setup];
    }
    return self;
}


#pragma mark - JPVideoPlayerLayoutProtocol

- (void)layoutThatFits:(CGRect)constrainedRect
nearestViewControllerInViewTree:(UIViewController *_Nullable)nearestViewController
        interfaceOrientation:(JPVideoPlayViewInterfaceOrientation)interfaceOrientation {
    CGSize referenceSize = constrainedRect.size;
    self.trackProgressView.frame = CGRectMake(kJPVideoPlayerDragSliderLeftEdge,
            (referenceSize.height - kJPVideoPlayerCachedProgressViewHeight) * 0.5,
            referenceSize.width - 2 * kJPVideoPlayerDragSliderLeftEdge, kJPVideoPlayerCachedProgressViewHeight);
    self.dragSlider.frame = constrainedRect;
    [self updateCacheProgressViewIfNeed];
    [self playProgressDidChangeElapsedSeconds:self.elapsedSeconds
                                 totalSeconds:self.totalSeconds
                                     videoURL:[NSURL new]];
}


#pragma mark - JPVideoPlayerProtocol

- (void)viewWillAddToSuperView:(UIView *)view {
    self.playerView = view;
}

- (void)viewWillPrepareToReuse {
    [self cacheRangeDidChange:@[] videoURL:[NSURL new]];
    [self playProgressDidChangeElapsedSeconds:0
                                 totalSeconds:1
                                     videoURL:[NSURL new]];
}

- (void)cacheRangeDidChange:(NSArray<NSValue *> *)cacheRanges
                   videoURL:(NSURL *)videoURL {
    _rangesValue = cacheRanges;
    [self updateCacheProgressViewIfNeed];
}

- (void)playProgressDidChangeElapsedSeconds:(NSTimeInterval)elapsedSeconds
                               totalSeconds:(NSTimeInterval)totalSeconds
                                   videoURL:(NSURL *)videoURL {
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

- (void)didFetchVideoFileLength:(NSUInteger)videoLength
                       videoURL:(NSURL *)videoURL {
    self.fileLength = videoLength;
}

- (void)setUserDragging:(BOOL)userDragging {
    [self willChangeValueForKey:@"userDragging"];
    _userDragging = userDragging;
    [self didChangeValueForKey:@"userDragging"];
}

- (BOOL)userDragging {
    return _userDragging;
}

- (void)setUserDragTimeInterval:(NSTimeInterval)userDragTimeInterval {
    [self willChangeValueForKey:@"userDragTimeInterval"];
    _userDragTimeInterval = userDragTimeInterval;
    [self didChangeValueForKey:@"userDragTimeInterval"];
}

- (NSTimeInterval)userDragTimeInterval {
    return _userDragTimeInterval;
}


#pragma mark - Private

- (void)_setup {
    NSBundle *bundle = [NSBundle bundleForClass:[JPVideoPlayer class]];
    NSString *bundlePath = [bundle pathForResource:@"JPVideoPlayer" ofType:@"bundle"];

    self.trackProgressView = ({
        UIProgressView *view = [UIProgressView new];
        view.trackTintColor = [UIColor colorWithWhite:1 alpha:0.15];
        [self addSubview:view];

        view;
    });

    self.cachedProgressView = ({
        UIView *view = [UIView new];
        [self.trackProgressView addSubview:view];
        view.clipsToBounds = YES;
        view.layer.cornerRadius = 1;
        view.backgroundColor = [UIColor colorWithWhite:1 alpha:0.3];

        view;
    });

    self.dragSlider = ({
        UISlider *view = [UISlider new];
        [view setThumbImage:[UIImage imageNamed:[bundlePath stringByAppendingPathComponent:@"jp_videoplayer_progress_handler_normal"]] forState:UIControlStateNormal];
        [view setThumbImage:[UIImage imageNamed:[bundlePath stringByAppendingPathComponent:@"jp_videoplayer_progress_handler_hightlight"]] forState:UIControlStateHighlighted];
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
    self.userDragTimeInterval = slider.value * self.totalSeconds;
}

- (void)dragSliderDidEnd:(UISlider *)slider {
    self.userDragging = NO;
    [self userDidFinishDrag];
    [NSNotificationCenter.defaultCenter postNotificationName:JPVideoPlayerControlProgressViewUserDidEndDragNotification object:self];
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
                    int deltaDistance = abs((int)(range.location - dragStartLocation));
                    deltaDistance = abs((int)(NSMaxRange(range) - dragStartLocation)) < deltaDistance ?: deltaDistance;
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
    if(self.fileLength == 0){
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

@interface JPVideoPlayerControlBar()<JPVideoPlayerProtocol>

@property (nonatomic, strong) UIButton *playButton;

@property (nonatomic, strong) UIView<JPVideoPlayerControlProgressProtocol> *progressView;

@property (nonatomic, strong) UILabel *timeLabel;

@property (nonatomic, strong) UIButton *landscapeButton;

@property (nonatomic, weak) UIView *playerView;

@property(nonatomic, assign) NSTimeInterval totalSeconds;

@end

static const CGFloat kJPVideoPlayerControlBarButtonWidthHeight = 22;
static const CGFloat kJPVideoPlayerControlBarElementGap = 16;
static const CGFloat kJPVideoPlayerControlBarTimeLabelWidth = 68;
@implementation JPVideoPlayerControlBar

- (void)dealloc {
    [self.progressView removeObserver:self forKeyPath:@"userDragTimeInterval"];
}

- (instancetype)initWithFrame:(CGRect)frame {
    NSAssert(NO, @"Please use given method to initialize this class.");
    return [self initWithProgressView:nil];
}

- (instancetype)initWithCoder:(NSCoder *)aDecoder {
    NSAssert(NO, @"Please use given method to initialize this class.");
    return [self initWithProgressView:nil];
}

- (instancetype)initWithProgressView:(UIView <JPVideoPlayerControlProgressProtocol> *_Nullable)progressView {
    self = [super initWithFrame:CGRectZero];
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


#pragma mark - JPVideoPlayerLayoutProtocol

- (void)layoutThatFits:(CGRect)constrainedRect
nearestViewControllerInViewTree:(UIViewController *_Nullable)nearestViewController
        interfaceOrientation:(JPVideoPlayViewInterfaceOrientation)interfaceOrientation {
    CGSize referenceSize = constrainedRect.size;
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
    if([self.progressView respondsToSelector:@selector(layoutThatFits:nearestViewControllerInViewTree:interfaceOrientation:)]){
        [self.progressView layoutThatFits:self.progressView.bounds
        nearestViewControllerInViewTree:nearestViewController
                   interfaceOrientation:interfaceOrientation];
    }
}


#pragma mark - JPVideoPlayerProtocol

- (void)viewWillAddToSuperView:(UIView *)view {
    self.playerView = view;
    [self updateTimeLabelWithElapsedSeconds:0 totalSeconds:0];
    [self.progressView viewWillAddToSuperView:view];
}

- (void)viewWillPrepareToReuse {
    [self updateTimeLabelWithElapsedSeconds:0 totalSeconds:0];
    [self.progressView viewWillPrepareToReuse];
}

- (void)cacheRangeDidChange:(NSArray<NSValue *> *)cacheRanges
                   videoURL:(NSURL *)videoURL {
    [self.progressView cacheRangeDidChange:cacheRanges
                                  videoURL:videoURL];
}

- (void)playProgressDidChangeElapsedSeconds:(NSTimeInterval)elapsedSeconds
                               totalSeconds:(NSTimeInterval)totalSeconds
                                   videoURL:(NSURL *)videoURL {
    self.totalSeconds = totalSeconds;
    if(!self.progressView.userDragging){
        [self updateTimeLabelWithElapsedSeconds:elapsedSeconds totalSeconds:totalSeconds];
    }
    [self.progressView playProgressDidChangeElapsedSeconds:elapsedSeconds
                                              totalSeconds:totalSeconds
                                                  videoURL:videoURL];
}

- (void)didFetchVideoFileLength:(NSUInteger)videoLength
                       videoURL:(NSURL *)videoURL {
    [self.progressView didFetchVideoFileLength:videoLength
                                      videoURL:videoURL];
}

- (void)videoPlayerStatusDidChange:(JPVideoPlayerStatus)playerStatus
                          videoURL:(NSURL *)videoURL {
    BOOL isPlaying = playerStatus == JPVideoPlayerStatusBuffering || playerStatus == JPVideoPlayerStatusPlaying;
    self.playButton.selected = !isPlaying;
}

- (void)videoPlayerInterfaceOrientationDidChange:(JPVideoPlayViewInterfaceOrientation)interfaceOrientation
                                        videoURL:(NSURL *)videoURL {
    self.landscapeButton.selected = interfaceOrientation == JPVideoPlayViewInterfaceOrientationLandscape;
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
    return [NSString stringWithFormat:@"%02d:%02d", (int)minute, (int)second];
}

- (void)playButtonDidClick:(UIButton *)button {
    button.selected = !button.selected;
    BOOL isPlay = self.playerView.jp_playerStatus == JPVideoPlayerStatusBuffering ||
            self.playerView.jp_playerStatus == JPVideoPlayerStatusPlaying;
    isPlay ? [self.playerView jp_pause] : [self.playerView jp_resume];
}

- (void)landscapeButtonDidClick:(UIButton *)button {
    button.selected = !button.selected;
    self.playerView.jp_viewInterfaceOrientation == JPVideoPlayViewInterfaceOrientationPortrait ? [self.playerView jp_gotoLandscape] : [self.playerView jp_gotoPortrait];
}

- (void)_setup {
    NSBundle *bundle = [NSBundle bundleForClass:[JPVideoPlayer class]];
    NSString *bundlePath = [bundle pathForResource:@"JPVideoPlayer" ofType:@"bundle"];

    self.backgroundColor = [UIColor clearColor];

    self.playButton = ({
        UIButton *button = [UIButton new];
        [button setImage:[UIImage imageNamed:[bundlePath stringByAppendingPathComponent:@"jp_videoplayer_pause"]] forState:UIControlStateNormal];
        [button setImage:[UIImage imageNamed:[bundlePath stringByAppendingPathComponent:@"jp_videoplayer_play"]] forState:UIControlStateSelected];
        [button addTarget:self action:@selector(playButtonDidClick:) forControlEvents:UIControlEventTouchUpInside];
        [self addSubview:button];

        button;
    });

    if(!self.progressView){
        self.progressView = ({
            JPVideoPlayerControlProgressView *view = [JPVideoPlayerControlProgressView new];
            [view addObserver:self forKeyPath:@"userDragTimeInterval" options:NSKeyValueObservingOptionNew context:nil];
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
        [button setImage:[UIImage imageNamed:[bundlePath stringByAppendingPathComponent:@"jp_videoplayer_landscape"]] forState:UIControlStateNormal];
        [button setImage:[UIImage imageNamed:[bundlePath stringByAppendingPathComponent:@"jp_videoplayer_portrait"]] forState:UIControlStateSelected];
        [button addTarget:self action:@selector(landscapeButtonDidClick:) forControlEvents:UIControlEventTouchUpInside];
        [self addSubview:button];

        button;
    });
}

- (void)observeValueForKeyPath:(nullable NSString *)keyPath
                      ofObject:(nullable id)object
                        change:(nullable NSDictionary<NSKeyValueChangeKey, id> *)change
                       context:(nullable void *)context {
    if([keyPath isEqualToString:@"userDragTimeInterval"]) {
        NSNumber *timeIntervalNumber = change[NSKeyValueChangeNewKey];
        NSTimeInterval timeInterval = timeIntervalNumber.floatValue;
        [self updateTimeLabelWithElapsedSeconds:timeInterval totalSeconds:self.totalSeconds];
    }
}

@end

@interface JPVideoPlayerControlView()

@property (nonatomic, strong) UIView<JPVideoPlayerProtocol> *controlBar;

@property (nonatomic, strong) UIImageView *blurImageView;

@end

static const CGFloat kJPVideoPlayerControlBarHeight = 38;
static const CGFloat kJPVideoPlayerControlBarLandscapeUpOffset = 12;
@implementation JPVideoPlayerControlView

- (instancetype)initWithFrame:(CGRect)frame {
    NSAssert(NO, @"Please use given method to initialize this class.");
    return [self initWithControlBar:nil blurImage:nil];
}

- (instancetype)initWithCoder:(NSCoder *)aDecoder {
    NSAssert(NO, @"Please use given method to initialize this class.");
    return [self initWithControlBar:nil blurImage:nil];
}

- (instancetype)initWithControlBar:(UIView <JPVideoPlayerProtocol> *)controlBar
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


#pragma mark - JPVideoPlayerLayoutProtocol

- (void)layoutThatFits:(CGRect)constrainedRect
nearestViewControllerInViewTree:(UIViewController *_Nullable)nearestViewController
        interfaceOrientation:(JPVideoPlayViewInterfaceOrientation)interfaceOrientation {
    self.blurImageView.frame = constrainedRect;
    CGRect controlBarFrame = CGRectMake(0,
            constrainedRect.size.height - kJPVideoPlayerControlBarHeight,
            constrainedRect.size.width,
            kJPVideoPlayerControlBarHeight);
    if(interfaceOrientation == JPVideoPlayViewInterfaceOrientationLandscape){ // landscape.
        CGFloat controlBarOriginX = 0;
        if (@available(iOS 11.0, *)) {
            UIEdgeInsets insets = self.window.safeAreaInsets;
            controlBarOriginX = insets.bottom;
        }
        controlBarFrame = CGRectMake(controlBarOriginX,
                constrainedRect.size.height - kJPVideoPlayerControlBarHeight - kJPVideoPlayerControlBarLandscapeUpOffset,
                constrainedRect.size.width - 2 * controlBarOriginX,
                kJPVideoPlayerControlBarHeight);
    }
    self.controlBar.frame = controlBarFrame;
    if([self.controlBar respondsToSelector:@selector(layoutThatFits:nearestViewControllerInViewTree:interfaceOrientation:)]){
       [self.controlBar layoutThatFits:self.controlBar.bounds
       nearestViewControllerInViewTree:nearestViewController
                  interfaceOrientation:interfaceOrientation];
    }
}


#pragma mark - JPVideoPlayerProtocol

- (void)viewWillAddToSuperView:(UIView *)view {
    [self.controlBar viewWillAddToSuperView:view];
}

- (void)viewWillPrepareToReuse {
    [self.controlBar viewWillPrepareToReuse];
}

- (void)cacheRangeDidChange:(NSArray<NSValue *> *)cacheRanges
                   videoURL:(NSURL *)videoURL {
    [self.controlBar cacheRangeDidChange:cacheRanges
                                videoURL:videoURL];
}

- (void)playProgressDidChangeElapsedSeconds:(NSTimeInterval)elapsedSeconds
                               totalSeconds:(NSTimeInterval)totalSeconds
                                   videoURL:(NSURL *)videoURL {
    [self.controlBar playProgressDidChangeElapsedSeconds:elapsedSeconds
                                            totalSeconds:totalSeconds
                                                videoURL:videoURL];
}

- (void)didFetchVideoFileLength:(NSUInteger)videoLength
                       videoURL:(NSURL *)videoURL {
    [self.controlBar didFetchVideoFileLength:videoLength
                                    videoURL:videoURL];
}

- (void)videoPlayerStatusDidChange:(JPVideoPlayerStatus)playerStatus
                          videoURL:(NSURL *)videoURL {
    [self.controlBar videoPlayerStatusDidChange:playerStatus
                                       videoURL:videoURL];
}

- (void)videoPlayerInterfaceOrientationDidChange:(JPVideoPlayViewInterfaceOrientation)interfaceOrientation
                                        videoURL:(NSURL *)videoURL {
    [self.controlBar videoPlayerInterfaceOrientationDidChange:interfaceOrientation
                                                     videoURL:videoURL];
}


#pragma mark - Private

- (void)_setup {
    NSBundle *bundle = [NSBundle bundleForClass:[JPVideoPlayer class]];
    NSString *bundlePath = [bundle pathForResource:@"JPVideoPlayer" ofType:@"bundle"];

    self.blurImageView = ({
        UIImageView *view = [UIImageView new];
        UIImage *blurImage = self.blurImage;
        if(!blurImage){
            blurImage = [UIImage imageNamed:[bundlePath stringByAppendingPathComponent:@"jp_videoplayer_blur"]];
        }
        view.image = blurImage;
        [self addSubview:view];

        view;
    });

    if(!self.controlBar){
        self.controlBar = ({
            JPVideoPlayerControlBar *bar = [[JPVideoPlayerControlBar alloc] initWithProgressView:nil];
            [self addSubview:bar];

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

const CGFloat JPVideoPlayerProgressViewElementHeight = 2;
@implementation JPVideoPlayerProgressView

- (instancetype)init {
    self = [super init];
    if(self){
        [self _setup];
    }
    return self;
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


#pragma mark - JPVideoPlayerLayoutProtocol

- (void)layoutThatFits:(CGRect)constrainedRect
nearestViewControllerInViewTree:(UIViewController *_Nullable)nearestViewController
        interfaceOrientation:(JPVideoPlayViewInterfaceOrientation)interfaceOrientation {
    self.trackProgressView.frame = CGRectMake(0,
            constrainedRect.size.height - JPVideoPlayerProgressViewElementHeight,
            constrainedRect.size.width,
            JPVideoPlayerProgressViewElementHeight);
    self.cachedProgressView.frame = self.trackProgressView.bounds;
    self.elapsedProgressView.frame = self.trackProgressView.frame;
}

#pragma mark - JPVideoPlayerProtocol

- (void)viewWillAddToSuperView:(UIView *)view {
}

- (void)viewWillPrepareToReuse {
    [self cacheRangeDidChange:@[] videoURL:[NSURL new]];
    [self playProgressDidChangeElapsedSeconds:0
                                 totalSeconds:1
                                     videoURL:[NSURL new]];
}

- (void)cacheRangeDidChange:(NSArray<NSValue *> *)cacheRanges
                   videoURL:(NSURL *)videoURL {
    _rangesValue = cacheRanges;
    [self displayCacheProgressViewIfNeed];
}

- (void)playProgressDidChangeElapsedSeconds:(NSTimeInterval)elapsedSeconds
                               totalSeconds:(NSTimeInterval)totalSeconds
                                   videoURL:(NSURL *)videoURL {
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

- (void)didFetchVideoFileLength:(NSUInteger)videoLength
                       videoURL:(NSURL *)videoURL {
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
                    int deltaDistance = abs((int)(range.location - dragStartLocation));
                    deltaDistance = abs((int)(NSMaxRange(range) - dragStartLocation)) < deltaDistance ?: deltaDistance;
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
    if(self.fileLength == 0){
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


#pragma mark - JPVideoPlayerLayoutProtocol

- (void)layoutThatFits:(CGRect)constrainedRect
nearestViewControllerInViewTree:(UIViewController *_Nullable)nearestViewController
  interfaceOrientation:(JPVideoPlayViewInterfaceOrientation)interfaceOrientation {
    CGSize referenceSize = constrainedRect.size;
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

- (void)didStartBufferingVideoURL:(NSURL *)videoURL {
    [self startAnimating];
}

- (void)didFinishBufferingVideoURL:(NSURL *)videoURL {
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

@property (nonatomic, strong) UIView *placeholderView;

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

- (instancetype)initWithNeedAutoHideControlViewWhenUserTapping:(BOOL)needAutoHideControlViewWhenUserTapping {
    self = [super init];
    if(self){
        _needAutoHideControlViewWhenUserTapping = needAutoHideControlViewWhenUserTapping;
        [self _setup];
    }
    return self;
}

- (void)setFrame:(CGRect)frame {
    [super setFrame:frame];
    self.placeholderView.frame = self.bounds;
    self.videoContainerView.frame = self.bounds;
    self.controlContainerView.frame = self.bounds;
    self.progressContainerView.frame = self.bounds;
    self.bufferingIndicatorContainerView.frame = self.bounds;
    self.userInteractionContainerView.frame = CGRectMake(0, 0, self.bounds.size.width, self.bounds.size.height - kJPVideoPlayerControlBarHeight);
    [self layoutContainerSubviewsWithBounds:CGRectZero center:CGPointZero  frame:frame];
    [self callLayoutMethodForContainerSubviews];
}

- (void)setBounds:(CGRect)bounds {
    [super setBounds:bounds];
    self.videoContainerView.frame = CGRectMake(self.videoContainerView.center.x - bounds.size.width * 0.5,
            self.videoContainerView.center.y - bounds.size.height * 0.5,
            bounds.size.width,
            bounds.size.height);
    self.placeholderView.frame = self.videoContainerView.frame;
    self.controlContainerView.frame = self.videoContainerView.frame;
    self.progressContainerView.frame = self.videoContainerView.frame;
    self.bufferingIndicatorContainerView.frame = self.videoContainerView.frame;
    self.userInteractionContainerView.frame = CGRectMake(self.userInteractionContainerView.center.x - bounds.size.width * 0.5,
            self.userInteractionContainerView.center.y - bounds.size.height * 0.5,
            bounds.size.width,
            bounds.size.height - kJPVideoPlayerControlBarHeight);
    [self layoutContainerSubviewsWithBounds:bounds center:CGPointZero frame:CGRectZero];
    [self callLayoutMethodForContainerSubviews];
}

- (void)setCenter:(CGPoint)center {
    [super setCenter:center];
    self.videoContainerView.frame = CGRectMake(center.y - self.videoContainerView.bounds.size.width * 0.5,
            center.x - self.videoContainerView.bounds.size.height * 0.5,
            self.videoContainerView.bounds.size.width,
            self.videoContainerView.bounds.size.height);
    self.placeholderView.frame = self.videoContainerView.frame;
    self.controlContainerView.frame = self.videoContainerView.frame;
    self.progressContainerView.frame = self.videoContainerView.frame;
    self.bufferingIndicatorContainerView.frame = self.videoContainerView.frame;
    self.userInteractionContainerView.frame = CGRectMake(center.y -  self.userInteractionContainerView.bounds.size.width * 0.5,
            center.x -  self.userInteractionContainerView.bounds.size.height * 0.5,
            self.userInteractionContainerView.bounds.size.width,
            self.userInteractionContainerView.bounds.size.height - kJPVideoPlayerControlBarHeight);
    [self layoutContainerSubviewsWithBounds:CGRectZero center:center frame:CGRectZero];
    [self callLayoutMethodForContainerSubviews];
}

- (CALayer *)videoContainerLayer {
    return self.videoContainerView.layer;
}

- (void)tapGestureDidTap {
    [UIView animateWithDuration:0.35
                          delay:0
                        options:UIViewAnimationOptionCurveEaseOut
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

- (void)layoutContainerSubviewsWithBounds:(CGRect)bounds center:(CGPoint)center frame:(CGRect)frame {
    for(UIView *view in self.controlContainerView.subviews){
        if(!CGRectIsEmpty(frame)){
           view.frame = frame;
        }
        else {
            if(CGRectIsEmpty(bounds)){
                bounds = view.bounds;
            }
            if(CGPointEqualToPoint(center, CGPointZero)){
                center = view.center;
            }
            view.frame = CGRectMake(center.y - bounds.size.width * 0.5,
                    center.x - bounds.size.height * 0.5,
                    bounds.size.width,
                    bounds.size.height);
        }
    }
    for(UIView *view in self.progressContainerView.subviews){
        if(!CGRectIsEmpty(frame)){
            view.frame = frame;
        }
        else {
            if(CGRectIsEmpty(bounds)){
                bounds = view.bounds;
            }
            if(CGPointEqualToPoint(center, CGPointZero)){
                center = view.center;
            }
            view.frame = CGRectMake(center.y - bounds.size.width * 0.5,
                    center.x - bounds.size.height * 0.5,
                    bounds.size.width,
                    bounds.size.height);
        }
    }
    for(UIView *view in self.bufferingIndicatorContainerView.subviews){
        if(!CGRectIsEmpty(frame)){
            view.frame = frame;
        }
        else {
            if(CGRectIsEmpty(bounds)){
                bounds = view.bounds;
            }
            if(CGPointEqualToPoint(center, CGPointZero)){
                center = view.center;
            }
            view.frame = CGRectMake(center.y - bounds.size.width * 0.5,
                    center.x - bounds.size.height * 0.5,
                    bounds.size.width,
                    bounds.size.height);
        }
    }
}

- (void)callLayoutMethodForContainerSubviews {
    UIViewController *nearestViewController = [self findNearestViewControllerForView:self.superview];
    for(UIView<JPVideoPlayerProtocol> *view in self.controlContainerView.subviews){
        if([view respondsToSelector:@selector(layoutThatFits:nearestViewControllerInViewTree:interfaceOrientation:)]){
            [view layoutThatFits:self.bounds
 nearestViewControllerInViewTree:nearestViewController
            interfaceOrientation:[self fetchCurrentInterfaceOrientation]];
        }
    }
    for(UIView<JPVideoPlayerProtocol> *view in self.progressContainerView.subviews){
        if([view respondsToSelector:@selector(layoutThatFits:nearestViewControllerInViewTree:interfaceOrientation:)]){
            [view layoutThatFits:self.bounds
 nearestViewControllerInViewTree:nearestViewController
            interfaceOrientation:[self fetchCurrentInterfaceOrientation]];
        }
    }
    for(UIView<JPVideoPlayerProtocol> *view in self.bufferingIndicatorContainerView.subviews){
        if([view respondsToSelector:@selector(layoutThatFits:nearestViewControllerInViewTree:interfaceOrientation:)]){
            [view layoutThatFits:self.bounds
 nearestViewControllerInViewTree:nearestViewController
            interfaceOrientation:[self fetchCurrentInterfaceOrientation]];
        }
    }
}

- (JPVideoPlayViewInterfaceOrientation)fetchCurrentInterfaceOrientation {
    return self.superview.jp_viewInterfaceOrientation;
}

- (UIViewController *)findNearestViewControllerForView:(UIView *)view {
    if(!view){
        return nil;
    }

    BOOL isFind = [[view nextResponder] isKindOfClass:[UIViewController class]] && CGRectEqualToRect(view.bounds, [UIScreen mainScreen].bounds);
    if(isFind){
        return (UIViewController *)[view nextResponder];
    }
    return [self findNearestViewControllerForView:view.superview];
}

#pragma mark - Setup

- (void)_setup {
    self.placeholderView = ({
        UIView *view = [UIView new];
        view.backgroundColor = [UIColor clearColor];
        [self addSubview:view];

        view;
    });

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

    if (self.needAutoHideControlViewWhenUserTapping) {
        UITapGestureRecognizer *tapGestureRecognizer = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(tapGestureDidTap)];
        [self.userInteractionContainerView addGestureRecognizer:tapGestureRecognizer];
        [self startTimer];
    }
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

// TODO: 捕获音量, 自定义音量控制.
