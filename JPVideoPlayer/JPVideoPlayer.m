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

#import "JPVideoPlayer.h"
#import "JPVideoPlayerResourceLoader.h"
#import "UIView+WebVideoCache.h"
#import <pthread.h>

@interface JPVideoPlayerModel()

/**
 * The playing URL.
 */
@property(nonatomic, strong, nullable)NSURL *url;

/**
 * The view of the video picture will show on.
 */
@property(nonatomic, weak, nullable)CALayer *unownedShowLayer;

/**
 * options,
 */
@property(nonatomic, assign)JPVideoPlayerOptions playerOptions;

/**
 * The Player to play video.
 */
@property(nonatomic, strong, nullable)AVPlayer *player;

/**
 * The current player's layer.
 */
@property(nonatomic, strong, nullable)AVPlayerLayer *playerLayer;

/**
 * The current player's item.
 */
@property(nonatomic, strong, nullable)AVPlayerItem *playerItem;

/**
 * The current player's urlAsset.
 */
@property(nonatomic, strong, nullable)AVURLAsset *videoURLAsset;

/**
 * A flag to book is cancel play or not.
 */
@property(nonatomic, assign, getter=isCancelled)BOOL cancelled;

/**
 * The resourceLoader for the videoPlayer.
 */
@property(nonatomic, strong, nullable)JPVideoPlayerResourceLoader *resourceLoader;

/**
 * The last play time for player.
 */
@property(nonatomic, assign)NSTimeInterval lastTime;

/**
 * The play progress observer.
 */
@property(nonatomic, strong)id timeObserver;

/*
 * videoPlayer.
 */
@property(nonatomic, weak) JPVideoPlayer *videoPlayer;

@property(nonatomic, assign) NSTimeInterval elapsedSeconds;

@property(nonatomic, assign) NSTimeInterval totalSeconds;

@end

static NSString *JPVideoPlayerURLScheme = @"systemCannotRecognitionScheme";
static NSString *JPVideoPlayerURL = @"www.newpan.com";
@implementation JPVideoPlayerModel

#pragma mark - JPVideoPlayerPlaybackProtocol

- (void)setRate:(float)rate {
    self.player.rate = rate;
}

- (float)rate {
    return self.player.rate;
}

- (void)setMuted:(BOOL)muted {
    self.player.muted = muted;
}

- (BOOL)muted {
    return self.player.muted;
}

- (void)setVolume:(float)volume {
    self.player.volume = volume;
}

- (float)volume {
    return self.player.volume;
}

- (void)seekToTime:(CMTime)time {
    NSAssert(NO, @"You cannot call this method.");
}

- (void)pause {
    [self.player pause];
}

- (void)resume {
    [self.player play];
}

- (CMTime)currentTime {
    return self.player.currentTime;
}

- (void)stopPlay {
    self.cancelled = YES;
    [self reset];
}

- (void)reset {
    // remove video layer from superlayer.
    if (self.playerLayer.superlayer) {
        [self.playerLayer removeFromSuperlayer];
    }

    // remove observer.
    [self.playerItem removeObserver:self.videoPlayer forKeyPath:@"status"];
    [self.player removeTimeObserver:self.timeObserver];
    [self.player removeObserver:self.videoPlayer forKeyPath:@"rate"];

    // remove player
    [self.player pause];
    [self.player cancelPendingPrerolls];
    self.player = nil;
    [self.videoURLAsset.resourceLoader setDelegate:nil queue:dispatch_get_main_queue()];
    self.playerItem = nil;
    self.playerLayer = nil;
    self.videoURLAsset = nil;
    self.resourceLoader = nil;
    self.elapsedSeconds = 0;
    self.totalSeconds = 0;
}

@end


@interface JPVideoPlayer()<JPVideoPlayerResourceLoaderDelegate>

/**
 * The current play video item.
 */
@property(nonatomic, strong, nullable)JPVideoPlayerModel *playerModel;

/**
 * The playing status of video player before app enter background.
 */
@property(nonatomic, assign)JPVideoPlayerStatus playerStatus_beforeEnterBackground;

/*
 * lock.
 */
@property(nonatomic) pthread_mutex_t lock;

@property (nonatomic, strong) NSTimer *checkBufferingTimer;

@property(nonatomic, assign) JPVideoPlayerStatus playerStatus;

@end

@implementation JPVideoPlayer

- (void)dealloc {
    pthread_mutex_destroy(&_lock);
    [self stopPlay];
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (instancetype)init{
    self = [super init];
    if (self) {
        pthread_mutexattr_t mutexattr;
        pthread_mutexattr_init(&mutexattr);
        pthread_mutexattr_settype(&mutexattr, PTHREAD_MUTEX_RECURSIVE);
        pthread_mutex_init(&_lock, &mutexattr);
        _playerStatus = JPVideoPlayerStatusUnknown;
        [self addObserver];
    }
    return self;
}


#pragma mark - Public

- (JPVideoPlayerModel *)playExistedVideoWithURL:(NSURL *)url
                             fullVideoCachePath:(NSString *)fullVideoCachePath
                                        options:(JPVideoPlayerOptions)options
                                    showOnLayer:(CALayer *)showLayer
                        configurationCompletion:(JPPlayVideoConfiguration)configurationCompletion {
    if (!url.absoluteString.length) {
        [self callDelegateMethodWithError:JPErrorWithDescription(@"The url is disable")];
        return nil;
    }

    if (fullVideoCachePath.length==0) {
        [self callDelegateMethodWithError:JPErrorWithDescription(@"The file path is disable")];
        return nil;
    }

    if (!showLayer) {
        [self callDelegateMethodWithError:JPErrorWithDescription(@"The layer to display video layer is nil")];
        return nil;
    }
    if(self.playerModel){
        [self.playerModel reset];
        self.playerModel = nil;
    }

    NSURL *videoPathURL = [NSURL fileURLWithPath:fullVideoCachePath];
    AVURLAsset *videoURLAsset = [AVURLAsset URLAssetWithURL:videoPathURL options:nil];
    AVPlayerItem *playerItem = [AVPlayerItem playerItemWithAsset:videoURLAsset];
    JPVideoPlayerModel *model = [self playerModelWithURL:url
                                              playerItem:playerItem
                                                 options:options
                                             showOnLayer:showLayer];
    if (options & JPVideoPlayerMutedPlay) {
        model.player.muted = YES;
    }
    self.playerModel = model;
    if(configurationCompletion){
        configurationCompletion([UIView new], model);
    }
    return model;
}

- (nullable JPVideoPlayerModel *)playVideoWithURL:(NSURL *)url
                                          options:(JPVideoPlayerOptions)options
                                        showLayer:(CALayer *)showLayer
                          configurationCompletion:(JPPlayVideoConfiguration)configurationCompletion {
    if (!url.absoluteString.length) {
        [self callDelegateMethodWithError:JPErrorWithDescription(@"The url is disable")];
        return nil;
    }

    if (!showLayer) {
        [self callDelegateMethodWithError:JPErrorWithDescription(@"The layer to display video layer is nil")];
        return nil;
    }

    if(self.playerModel){
        [self.playerModel reset];
        self.playerModel = nil;
    }

    // Re-create all all configuration again.
    // Make the `resourceLoader` become the delegate of 'videoURLAsset', and provide data to the player.
    JPVideoPlayerResourceLoader *resourceLoader = [JPVideoPlayerResourceLoader resourceLoaderWithCustomURL:url];
    resourceLoader.delegate = self;
    AVURLAsset *videoURLAsset = [AVURLAsset URLAssetWithURL:[self handleVideoURL] options:nil];
    [videoURLAsset.resourceLoader setDelegate:resourceLoader queue:dispatch_get_main_queue()];
    AVPlayerItem *playerItem = [AVPlayerItem playerItemWithAsset:videoURLAsset];
    JPVideoPlayerModel *model = [self playerModelWithURL:url
                                              playerItem:playerItem
                                                 options:options
                                             showOnLayer:showLayer];
    self.playerModel = model;
    model.resourceLoader = resourceLoader;
    if (options & JPVideoPlayerMutedPlay) {
        model.player.muted = YES;
    }
    if(configurationCompletion){
        configurationCompletion([UIView new], model);
    }
    return model;
}

- (void)resumePlayWithShowLayer:(CALayer *)showLayer
                        options:(JPVideoPlayerOptions)options
        configurationCompletion:(JPPlayVideoConfiguration)configurationCompletion {
    if (!showLayer) {
        [self callDelegateMethodWithError:JPErrorWithDescription(@"The layer to display video layer is nil")];
        return;
    }
    [self.playerModel.playerLayer removeFromSuperlayer];
    self.playerModel.unownedShowLayer = showLayer;

    if (options & JPVideoPlayerMutedPlay) {
        self.playerModel.player.muted = YES;
    }
    else {
        self.playerModel.player.muted = NO;
    }
    [self setVideoGravityWithOptions:options playerModel:self.playerModel];
    [self displayVideoPicturesOnShowLayer];

    if(configurationCompletion){
        configurationCompletion([UIView new], self.playerModel);
    }
    [self callPlayerStatusDidChangeDelegateMethod];
}

- (void)seekToTimeWhenRecordPlayback:(CMTime)time {
    if(!self.playerModel){
        return;
    }
    if(!CMTIME_IS_VALID(time)){
        return;
    }
    __weak typeof(self) wself = self;
    [self.playerModel.player seekToTime:time completionHandler:^(BOOL finished) {

        __strong typeof(wself) sself = wself;
        if(finished){
            [sself internalResumeWithNeedCallDelegate:YES];
        }

    }];
}


#pragma mark - JPVideoPlayerPlaybackProtocol

- (void)setRate:(float)rate {
    if(!self.playerModel){
        return;
    }
    [self.playerModel setRate:rate];
}

- (float)rate {
    if(!self.playerModel){
        return 0;
    }
    return self.playerModel.rate;
}

- (void)setMuted:(BOOL)muted {
    if(!self.playerModel){
        return;
    }
    [self.playerModel setMuted:muted];
}

- (BOOL)muted {
    if(!self.playerModel){
        return NO;
    }
    return self.playerModel.muted;
}

- (void)setVolume:(float)volume {
    if(!self.playerModel){
        return;
    }
    [self.playerModel setVolume:volume];
}

- (float)volume {
    if(!self.playerModel){
        return 0;
    }
    return self.playerModel.volume;
}

- (void)seekToTime:(CMTime)time {
    if(!self.playerModel){
        return;
    }
    if(!CMTIME_IS_VALID(time)){
        return;
    }
    BOOL needResume = self.playerModel.player.rate != 0;
    self.playerModel.lastTime = 0;
    [self internalPauseWithNeedCallDelegate:NO];
    __weak typeof(self) wself = self;
    [self.playerModel.player seekToTime:time completionHandler:^(BOOL finished) {

        __strong typeof(wself) sself = wself;
        if(finished && needResume){
            [sself internalResumeWithNeedCallDelegate:NO];
        }

    }];
}

- (NSTimeInterval)elapsedSeconds {
    return [self.playerModel elapsedSeconds];
}

- (NSTimeInterval)totalSeconds {
    return [self.playerModel totalSeconds];
}

- (void)pause {
    if(!self.playerModel){
        return;
    }
    [self internalPauseWithNeedCallDelegate:YES];
}

- (void)resume {
    if(!self.playerModel){
        return;
    }
    if(self.playerStatus == JPVideoPlayerStatusStop){
       self.playerStatus = JPVideoPlayerStatusUnknown;
       [self seekToHeaderThenStartPlayback];
        return;
    }
    [self internalResumeWithNeedCallDelegate:YES];
}

- (CMTime)currentTime {
    if(!self.playerModel){
        return kCMTimeZero;
    }
    return self.playerModel.currentTime;
}

- (void)stopPlay{
    if(!self.playerModel){
        return;
    }
    [self.playerModel stopPlay];
    [self stopCheckBufferingTimerIfNeed];
    [self resetAwakeWaitingTimeInterval];
    self.playerModel = nil;
    self.playerStatus = JPVideoPlayerStatusStop;
    [self callPlayerStatusDidChangeDelegateMethod];
}


#pragma mark - JPVideoPlayerResourceLoaderDelegate

- (void)resourceLoader:(JPVideoPlayerResourceLoader *)resourceLoader
didReceiveLoadingRequestTask:(JPResourceLoadingRequestWebTask *)requestTask {
    if (self.delegate && [self.delegate respondsToSelector:@selector(videoPlayer:didReceiveLoadingRequestTask:)]) {
        [self.delegate videoPlayer:self didReceiveLoadingRequestTask:requestTask];
    }
}


#pragma mark - App Observer

- (void)addObserver {
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(playerItemDidPlayToEnd:)
                                                 name:AVPlayerItemDidPlayToEndTimeNotification
                                               object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(appReceivedMemoryWarning)
                                                 name:UIApplicationDidReceiveMemoryWarningNotification
                                               object:nil];
}

- (void)appReceivedMemoryWarning {
    [self.playerModel stopPlay];
}


#pragma mark - AVPlayer Observer

- (void)playerItemDidPlayToEnd:(NSNotification *)notification {
    AVPlayerItem *playerItem = notification.object;
    if(playerItem != self.playerModel.playerItem){
        return;
    }

    self.playerStatus = JPVideoPlayerStatusStop;
    [self callPlayerStatusDidChangeDelegateMethod];
    [self stopCheckBufferingTimerIfNeed];

    // ask need automatic replay or not.
    if (self.delegate && [self.delegate respondsToSelector:@selector(videoPlayer:shouldAutoReplayVideoForURL:)]) {
        if (![self.delegate videoPlayer:self shouldAutoReplayVideoForURL:self.playerModel.url]) {
            return;
        }
    }
    [self seekToHeaderThenStartPlayback];
}

- (void)observeValueForKeyPath:(NSString *)keyPath
                      ofObject:(id)object
                        change:(NSDictionary<NSString *,id> *)change
                       context:(void *)context{
    if ([keyPath isEqualToString:@"status"]) {
        AVPlayerItem *playerItem = (AVPlayerItem *)object;
        AVPlayerItemStatus status = playerItem.status;
        switch (status) {
            case AVPlayerItemStatusUnknown:{
                self.playerStatus = AVPlayerItemStatusUnknown;
                [self callPlayerStatusDidChangeDelegateMethod];
            }
                break;

            case AVPlayerItemStatusReadyToPlay:{
                JPDebugLog(@"AVPlayerItemStatusReadyToPlay");
                self.playerStatus = JPVideoPlayerStatusReadyToPlay;
                // When get ready to play note, we can go to play, and can add the video picture on show view.
                if (!self.playerModel) return;
                [self callPlayerStatusDidChangeDelegateMethod];
                [self.playerModel.player play];
                [self displayVideoPicturesOnShowLayer];
            }
                break;

            case AVPlayerItemStatusFailed:{
                [self stopCheckBufferingTimerIfNeed];
                self.playerStatus = JPVideoPlayerStatusFailed;
                [self callDelegateMethodWithError:JPErrorWithDescription(@"AVPlayerItemStatusFailed")];
                [self callPlayerStatusDidChangeDelegateMethod];
            }
                break;

            default:
                break;
        }
    }
    else if([keyPath isEqualToString:@"rate"]) {
        float rate = [change[NSKeyValueChangeNewKey] floatValue];
        if((rate != 0) && (self.playerStatus == JPVideoPlayerStatusReadyToPlay)){
            self.playerStatus = JPVideoPlayerStatusPlaying;
            [self callPlayerStatusDidChangeDelegateMethod];
        }
    }
}


#pragma mark - Timer

- (void)startCheckBufferingTimer {
    if(self.checkBufferingTimer){
        [self stopCheckBufferingTimerIfNeed];
    }
    self.checkBufferingTimer = ({
        NSTimer *timer = [NSTimer timerWithTimeInterval:0.5
                                                 target:self
                                               selector:@selector(checkBufferingTimeDidChange)
                                               userInfo:nil
                                                repeats:YES];
        [NSRunLoop.mainRunLoop addTimer:timer forMode:NSRunLoopCommonModes];

        timer;
    });
}

- (void)stopCheckBufferingTimerIfNeed {
    if(self.checkBufferingTimer){
        [self.checkBufferingTimer invalidate];
        self.checkBufferingTimer = nil;
    }
}

- (void)checkBufferingTimeDidChange {
    NSTimeInterval currentTime = CMTimeGetSeconds(self.playerModel.player.currentTime);
    if (currentTime != 0 && currentTime > (self.playerModel.lastTime + 0.3)) {
        self.playerModel.lastTime = currentTime;
        [self endAwakeFromBuffering];
        if(self.playerStatus == JPVideoPlayerStatusPlaying){
            return;
        }
        self.playerStatus = JPVideoPlayerStatusPlaying;
        [self callPlayerStatusDidChangeDelegateMethod];
    }
    else{
        if(self.playerStatus == JPVideoPlayerStatusBuffering){
            [self startAwakeWhenBuffering];
            return;
        }
        self.playerStatus = JPVideoPlayerStatusBuffering;
        [self callPlayerStatusDidChangeDelegateMethod];
    }
}


#pragma mark - Awake When Buffering

static NSTimeInterval _awakeWaitingTimeInterval = 3;
- (void)resetAwakeWaitingTimeInterval {
    _awakeWaitingTimeInterval = 3;
    JPDebugLog(@"重置了播放唤醒等待时间");
}

- (void)updateAwakeWaitingTimerInterval {
    _awakeWaitingTimeInterval += 2;
    if(_awakeWaitingTimeInterval > 12){
        _awakeWaitingTimeInterval = 12;
    }
}

static BOOL _isOpenAwakeWhenBuffering = NO;
- (void)startAwakeWhenBuffering {
    if(!_isOpenAwakeWhenBuffering){
        _isOpenAwakeWhenBuffering = YES;
        JPDebugLog(@"Start awake when buffering.");
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(_awakeWaitingTimeInterval * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{

            if(!_isOpenAwakeWhenBuffering){
                [self endAwakeFromBuffering];
                JPDebugLog(@"Player is playing when call awake buffering block.");
                return;
            }
            JPDebugLog(@"Call resume in awake buffering block.");
            _isOpenAwakeWhenBuffering = NO;
            [self.playerModel pause];
            [self updateAwakeWaitingTimerInterval];
            [self.playerModel resume];

        });
    }
}

- (void)endAwakeFromBuffering {
    if(_isOpenAwakeWhenBuffering){
        JPDebugLog(@"End awake buffering.");
        _isOpenAwakeWhenBuffering = NO;
        [self resetAwakeWaitingTimeInterval];
    }
}


#pragma mark - Private

- (void)seekToHeaderThenStartPlayback {
    // Seek the start point of file data and repeat play, this handle have no memory surge.
    __weak typeof(self.playerModel) weak_Item = self.playerModel;
    [self.playerModel.player seekToTime:CMTimeMake(0, 1) completionHandler:^(BOOL finished) {
        __strong typeof(weak_Item) strong_Item = weak_Item;
        if (!strong_Item) return;

        self.playerModel.lastTime = 0;
        [strong_Item.player play];
        [self callPlayerStatusDidChangeDelegateMethod];
        [self startCheckBufferingTimer];

    }];
}

- (void)callPlayerStatusDidChangeDelegateMethod {
    if (self.delegate && [self.delegate respondsToSelector:@selector(videoPlayer:playerStatusDidChange:)]) {
        [self.delegate videoPlayer:self playerStatusDidChange:self.playerStatus];
    }
}

- (void)internalPauseWithNeedCallDelegate:(BOOL)needCallDelegate {
    [self.playerModel pause];
    [self stopCheckBufferingTimerIfNeed];
    self.playerStatus = JPVideoPlayerStatusPause;
    [self endAwakeFromBuffering];
    if(needCallDelegate){
        [self callPlayerStatusDidChangeDelegateMethod];
    }
}

- (void)internalResumeWithNeedCallDelegate:(BOOL)needCallDelegate {
    [self.playerModel resume];
    [self startCheckBufferingTimer];
    self.playerStatus = JPVideoPlayerStatusPlaying;
    if(needCallDelegate){
        [self callPlayerStatusDidChangeDelegateMethod];
    }
}

- (JPVideoPlayerModel *)playerModelWithURL:(NSURL *)url
                                playerItem:(AVPlayerItem *)playerItem
                                   options:(JPVideoPlayerOptions)options
                               showOnLayer:(CALayer *)showLayer {
    [self resetAwakeWaitingTimeInterval];
    JPVideoPlayerModel *model = [JPVideoPlayerModel new];
    model.unownedShowLayer = showLayer;
    model.url = url;
    model.playerOptions = options;
    model.playerItem = playerItem;
    [playerItem addObserver:self forKeyPath:@"status" options:NSKeyValueObservingOptionNew context:nil];

    model.player = [AVPlayer playerWithPlayerItem:playerItem];
    [model.player addObserver:self forKeyPath:@"rate" options:NSKeyValueObservingOptionNew context:nil];
    if ([model.player respondsToSelector:@selector(automaticallyWaitsToMinimizeStalling)]) {
        model.player.automaticallyWaitsToMinimizeStalling = NO;
    }
    model.playerLayer = [AVPlayerLayer playerLayerWithPlayer:model.player];
    [self setVideoGravityWithOptions:options playerModel:model];
    model.videoPlayer = self;
    self.playerStatus = JPVideoPlayerStatusUnknown;
    [self startCheckBufferingTimer];

    // add observer for video playing progress.
    __weak typeof(model) wItem = model;
    __weak typeof(self) wself = self;
    [model.player addPeriodicTimeObserverForInterval:CMTimeMake(1.0, 10.0) queue:dispatch_get_main_queue() usingBlock:^(CMTime time){
        __strong typeof(wItem) sItem = wItem;
        __strong typeof(wself) sself = wself;
        if (!sItem || !sself) return;

        double elapsedSeconds = CMTimeGetSeconds(time);
        double totalSeconds = CMTimeGetSeconds(sItem.playerItem.duration);
        sself.playerModel.elapsedSeconds = elapsedSeconds;
        sself.playerModel.totalSeconds = totalSeconds;
        if(totalSeconds == 0 || isnan(totalSeconds) || elapsedSeconds > totalSeconds){
            return;
        }
        JPDispatchSyncOnMainQueue(^{
            if (sself.delegate && [sself.delegate respondsToSelector:@selector(videoPlayerPlayProgressDidChange:elapsedSeconds:totalSeconds:)]) {
                [sself.delegate videoPlayerPlayProgressDidChange:sself
                                                  elapsedSeconds:elapsedSeconds
                                                    totalSeconds:totalSeconds];
            }
        });

    }];

    return model;
}

- (void)setVideoGravityWithOptions:(JPVideoPlayerOptions)options
                       playerModel:(JPVideoPlayerModel *)playerModel {
    NSString *videoGravity = nil;
    if (options & JPVideoPlayerLayerVideoGravityResizeAspect) {
        videoGravity = AVLayerVideoGravityResizeAspect;
    }
    else if (options & JPVideoPlayerLayerVideoGravityResize){
        videoGravity = AVLayerVideoGravityResize;
    }
    else if (options & JPVideoPlayerLayerVideoGravityResizeAspectFill){
        videoGravity = AVLayerVideoGravityResizeAspectFill;
    }
    playerModel.playerLayer.videoGravity = videoGravity;
}

- (NSURL *)handleVideoURL {
    NSURLComponents *components = [[NSURLComponents alloc] initWithURL:[NSURL URLWithString:JPVideoPlayerURL] resolvingAgainstBaseURL:NO];
    components.scheme = JPVideoPlayerURLScheme;
    return [components URL];
}

- (void)displayVideoPicturesOnShowLayer{
    if (!self.playerModel.isCancelled) {
        // fixed #26.
        self.playerModel.playerLayer.frame = self.playerModel.unownedShowLayer.bounds;
        // use dispatch_after to prevent layer layout animation.
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.01 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            [self.playerModel.unownedShowLayer addSublayer:self.playerModel.playerLayer];
        });
    }
}

- (void)callDelegateMethodWithError:(NSError *)error {
    JPDebugLog(@"Player abort because of error: %@", error);
    JPDispatchSyncOnMainQueue(^{
        if (self.delegate && [self.delegate respondsToSelector:@selector(videoPlayer:playFailedWithError:)]) {
            [self.delegate videoPlayer:self playFailedWithError:error];
        }
    });
}

@end