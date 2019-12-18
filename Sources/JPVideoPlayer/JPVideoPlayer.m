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

@property(nonatomic, strong, nullable)NSURL *url;

/**
 * The layer of the video picture will show on.
 */
@property(nonatomic, weak, nullable)CALayer *unownedShowLayer;

@property(nonatomic, assign)JPVideoPlayerOptions playerOptions;

@property(nonatomic, strong, nullable)AVPlayer *player;

@property(nonatomic, strong, nullable)AVPlayerLayer *playerLayer;

@property(nonatomic, strong, nullable)AVPlayerItem *playerItem;

@property(nonatomic, strong, nullable)AVURLAsset *videoURLAsset;

@property(nonatomic, assign, getter=isCancelled)BOOL cancelled;

/**
 * The resourceLoader for the videoPlayer.
 */
@property(nonatomic, strong, nullable)JPVideoPlayerResourceLoader *resourceLoader;

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

static NSString *JPVideoPlayerURLScheme = @"com.jpvideoplayer.system.cannot.recognition.scheme.www";
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

- (BOOL)seekToTime:(CMTime)time {
    NSAssert(NO, @"You cannot call this method.");
    return NO;
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
    [self.playerItem removeObserver:self.videoPlayer forKeyPath:@"playbackLikelyToKeepUp"];
    [self.playerItem removeObserver:self.videoPlayer forKeyPath:@"playbackBufferEmpty"];
    [self.playerItem removeObserver:self.videoPlayer forKeyPath:@"playbackBufferFull"];
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

@property(nonatomic, assign) JPVideoPlayerStatus playerStatus;

@property(nonatomic, assign) BOOL seekingToTime;

@end

@implementation JPVideoPlayer

- (void)dealloc {
    [self stopPlay];
    [self removePlayerItemDidPlayToEndObserver];
}

- (instancetype)init{
    self = [super init];
    if (self) {
        _playerStatus = JPVideoPlayerStatusUnknown;
        _seekingToTime = NO;
    }
    return self;
}


#pragma mark - Public

- (JPVideoPlayerModel *)playExistedVideoWithURL:(NSURL *)url
                             fullVideoCachePath:(NSString *)fullVideoCachePath
                                        options:(JPVideoPlayerOptions)options
                                    showOnLayer:(CALayer *)showLayer
                                  configuration:(JPVideoPlayerConfiguration)configuration {
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
    [self removePlayerItemDidPlayToEndObserver];
    [self addPlayerItemDidPlayToEndObserver:playerItem];
    JPVideoPlayerModel *model = [self playerModelWithURL:url
                                              playerItem:playerItem
                                                 options:options
                                             showOnLayer:showLayer];
    if (options & JPVideoPlayerMutedPlay) {
        model.player.muted = YES;
    }
    self.playerModel = model;
    if(configuration) configuration(model);
    return model;
}

- (nullable JPVideoPlayerModel *)playVideoWithURL:(NSURL *)url
                                          options:(JPVideoPlayerOptions)options
                                        showLayer:(CALayer *)showLayer
                                    configuration:(JPVideoPlayerConfiguration)configuration {
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
    
    // url instead of `[self composeFakeVideoURL]`, otherwise some urls can not play normally
    AVURLAsset *videoURLAsset = [AVURLAsset URLAssetWithURL:[self composeFakeVideoURL] options:nil];
    [videoURLAsset.resourceLoader setDelegate:resourceLoader queue:dispatch_get_main_queue()];
    AVPlayerItem *playerItem = [AVPlayerItem playerItemWithAsset:videoURLAsset];
    [self removePlayerItemDidPlayToEndObserver];
    [self addPlayerItemDidPlayToEndObserver:playerItem];
    JPVideoPlayerModel *model = [self playerModelWithURL:url
                                              playerItem:playerItem
                                                 options:options
                                             showOnLayer:showLayer];
    self.playerModel = model;
    model.resourceLoader = resourceLoader;
    if (options & JPVideoPlayerMutedPlay) {
        model.player.muted = YES;
    }
    if(configuration) configuration(model);
    [self invokePlayerStatusDidChangeDelegateMethod];
    return model;
}

- (void)resumePlayWithShowLayer:(CALayer *)showLayer
                        options:(JPVideoPlayerOptions)options
                  configuration:(JPVideoPlayerConfiguration)configuration {
    JPAssertMainThread;
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

    if(configuration) configuration(self.playerModel);
    [self invokePlayerStatusDidChangeDelegateMethod];
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
        return 0.f;
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
        return 0.f;
    }
    return self.playerModel.volume;
}

- (BOOL)seekToTime:(CMTime)time {
    if(!self.playerModel || !CMTIME_IS_VALID(time)) return NO;

    if (self.playerStatus == JPVideoPlayerStatusUnknown || self.playerStatus == JPVideoPlayerStatusFailed || self.playerStatus == JPVideoPlayerStatusStop) {
        return NO;
    }

    BOOL needResume = self.playerModel.player.rate != 0;
    [self internalPauseWithNeedCallDelegate:NO];
    self.seekingToTime = YES;
    __weak typeof(self) wself = self;
    [self.playerModel.player seekToTime:time completionHandler:^(BOOL finished) {

        __strong typeof(wself) sself = wself;
        sself.seekingToTime = NO;
        if(finished && needResume){
            [sself internalResumeWithNeedCallDelegate:NO];
        }

    }];

    return YES;
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
    self.playerModel = nil;
    self.playerStatus = JPVideoPlayerStatusStop;
    [self invokePlayerStatusDidChangeDelegateMethod];
}


#pragma mark - JPVideoPlayerResourceLoaderDelegate

- (void)resourceLoader:(JPVideoPlayerResourceLoader *)resourceLoader
didReceiveLoadingRequestTask:(JPResourceLoadingRequestWebTask *)requestTask {
    if (self.delegate && [self.delegate respondsToSelector:@selector(videoPlayer:didReceiveLoadingRequestTask:)]) {
        [self.delegate videoPlayer:self didReceiveLoadingRequestTask:requestTask];
    }
}


#pragma mark - App Observer

- (void)addPlayerItemDidPlayToEndObserver:(AVPlayerItem *)playerItem {
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(playerItemDidPlayToEnd:)
                                                 name:AVPlayerItemDidPlayToEndTimeNotification
                                               object:playerItem];
}

- (void)removePlayerItemDidPlayToEndObserver {
    [NSNotificationCenter.defaultCenter removeObserver:self
                                                  name:AVPlayerItemDidPlayToEndTimeNotification
                                                object:nil];
}


#pragma mark - AVPlayer Observer

- (void)playerItemDidPlayToEnd:(NSNotification *)notification {
    AVPlayerItem *playerItem = notification.object;
    if(playerItem != self.playerModel.playerItem) return;

    self.playerStatus = JPVideoPlayerStatusStop;
    [self invokePlayerStatusDidChangeDelegateMethod];

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
    if (object == self.playerModel.player) {
        if([keyPath isEqualToString:@"rate"]) {
            float rate = [change[NSKeyValueChangeNewKey] floatValue];
            if((rate != 0) && (self.playerStatus == JPVideoPlayerStatusReadyToPlay)){
                self.playerStatus = JPVideoPlayerStatusPlaying;
                [self invokePlayerStatusDidChangeDelegateMethod];
            }
        }
    }
    else if (object == self.playerModel.playerItem) {
        if ([keyPath isEqualToString:@"status"]) {
            AVPlayerItem *playerItem = (AVPlayerItem *)object;
            AVPlayerItemStatus status = playerItem.status;
            switch (status) {
                case AVPlayerItemStatusUnknown:{
                    JPDebugLog(@"AVPlayerItemStatusUnknown");
                    self.playerStatus = JPVideoPlayerStatusUnknown;
                    [self invokePlayerStatusDidChangeDelegateMethod];
                }
                    break;

                case AVPlayerItemStatusReadyToPlay:{
                    JPDebugLog(@"AVPlayerItemStatusReadyToPlay");
                    self.playerStatus = JPVideoPlayerStatusReadyToPlay;
                    // When get ready to play note, we can go to play, and can add the video picture on show view.
                    if (!self.playerModel) return;
                    [self invokePlayerStatusDidChangeDelegateMethod];
                    [self.playerModel.player play];
                    [self displayVideoPicturesOnShowLayer];
                }
                    break;

                case AVPlayerItemStatusFailed:{
                    self.playerStatus = JPVideoPlayerStatusFailed;
                    JPDebugLog(@"AVPlayerItemStatusFailed");
                    [self callDelegateMethodWithError:JPErrorWithDescription(@"AVPlayerItemStatusFailed")];
                    [self invokePlayerStatusDidChangeDelegateMethod];
                }
                    break;

                default:
                    break;
            }
        }
        else if ([keyPath isEqualToString:@"playbackLikelyToKeepUp"]) {
            BOOL playbackLikelyToKeepUp = self.playerModel.playerItem.playbackLikelyToKeepUp;
            JPDebugLog(@"%@", playbackLikelyToKeepUp ? @"buffering finished, start to play." : @"start to buffer.");
            self.playerStatus = playbackLikelyToKeepUp ? JPVideoPlayerStatusPlaying : JPVideoPlayerStatusBuffering;
            [self invokePlayerStatusDidChangeDelegateMethod];
        }
        else if ([keyPath isEqualToString:@"playbackBufferEmpty"]) {
            BOOL playbackBufferEmpty = self.playerModel.playerItem.playbackBufferEmpty;
            JPDebugLog(@"playbackBufferEmpty: %@.", playbackBufferEmpty ? @"empty" : @"not empty");
            if (playbackBufferEmpty) {
                self.playerStatus = JPVideoPlayerStatusBuffering;
                [self invokePlayerStatusDidChangeDelegateMethod];
            }
        }
        else if ([keyPath isEqualToString:@"playbackBufferFull"]) {
            BOOL playbackBufferFull = self.playerModel.playerItem.playbackBufferFull;
            JPDebugLog(@"playbackBufferFull: %@.", playbackBufferFull ? @"full" : @"not full");
            if (playbackBufferFull) {
                self.playerStatus = JPVideoPlayerStatusPlaying;
                [self invokePlayerStatusDidChangeDelegateMethod];
            }
        }
    }
}


#pragma mark - Private

- (void)seekToHeaderThenStartPlayback {
    // Seek the start point of file data and repeat play, this handle have no memory surge.
    __weak typeof(self.playerModel) weak_Item = self.playerModel;
    __weak typeof(self) wself = self;
    [self invokePlayerStatusDidChangeDelegateMethod];

    [self.playerModel.player seekToTime:CMTimeMake(0, 1) completionHandler:^(BOOL finished) {

        __strong typeof(weak_Item) strong_Item = weak_Item;
        __weak typeof(wself) sself = wself;
        [strong_Item.player play];
        sself.playerStatus = JPVideoPlayerStatusPlaying;
        [sself invokePlayerStatusDidChangeDelegateMethod];

    }];
}

- (void)invokePlayerStatusDidChangeDelegateMethod {
    JPDispatchAsyncOnMainQueue(^{

        if (self.delegate && [self.delegate respondsToSelector:@selector(videoPlayer:playerStatusDidChange:)]) {
            [self.delegate videoPlayer:self playerStatusDidChange:self.playerStatus];
        }

    });
}

- (void)internalPauseWithNeedCallDelegate:(BOOL)needCallDelegate {
    [self.playerModel pause];
    self.playerStatus = JPVideoPlayerStatusPause;
    if(needCallDelegate){
        [self invokePlayerStatusDidChangeDelegateMethod];
    }
}

- (void)internalResumeWithNeedCallDelegate:(BOOL)needCallDelegate {
    [self.playerModel resume];
    self.playerStatus = JPVideoPlayerStatusPlaying;
    if(needCallDelegate){
        [self invokePlayerStatusDidChangeDelegateMethod];
    }
}

- (JPVideoPlayerModel *)playerModelWithURL:(NSURL *)url
                                playerItem:(AVPlayerItem *)playerItem
                                   options:(JPVideoPlayerOptions)options
                               showOnLayer:(CALayer *)showLayer {
    JPVideoPlayerModel *model = [JPVideoPlayerModel new];
    model.unownedShowLayer = showLayer;
    model.url = url;
    model.playerOptions = options;
    model.playerItem = playerItem;
    [playerItem addObserver:self forKeyPath:@"status" options:NSKeyValueObservingOptionNew context:nil];
    [playerItem addObserver:self forKeyPath:@"playbackLikelyToKeepUp" options:NSKeyValueObservingOptionNew context:nil];
    [playerItem addObserver:self forKeyPath:@"playbackBufferEmpty" options:NSKeyValueObservingOptionNew context:nil];
    [playerItem addObserver:self forKeyPath:@"playbackBufferFull" options:NSKeyValueObservingOptionNew context:nil];

    model.player = [AVPlayer playerWithPlayerItem:playerItem];
    [model.player addObserver:self forKeyPath:@"rate" options:NSKeyValueObservingOptionNew context:nil];
    if ([model.player respondsToSelector:@selector(automaticallyWaitsToMinimizeStalling)]) {
        model.player.automaticallyWaitsToMinimizeStalling = NO;
    }
    model.playerLayer = [AVPlayerLayer playerLayerWithPlayer:model.player];
    [self setVideoGravityWithOptions:options playerModel:model];
    model.videoPlayer = self;
    self.playerStatus = JPVideoPlayerStatusUnknown;

    // add observer for video playing progress.
    __weak typeof(model) wItem = model;
    __weak typeof(self) wself = self;
    [model.player addPeriodicTimeObserverForInterval:CMTimeMake(1, 10) queue:dispatch_get_main_queue() usingBlock:^(CMTime time){
        __strong typeof(wItem) sItem = wItem;
        __strong typeof(wself) sself = wself;
        if (!sItem || !sself) return;

        double elapsedSeconds = CMTimeGetSeconds(time);
        double totalSeconds = CMTimeGetSeconds(sItem.playerItem.duration);
        sself.playerModel.elapsedSeconds = elapsedSeconds;
        sself.playerModel.totalSeconds = totalSeconds;
        if(totalSeconds == 0 || isnan(totalSeconds) || elapsedSeconds > totalSeconds) return;

        if (!sself.seekingToTime) {
            JPDispatchSyncOnMainQueue(^{
                if (sself.delegate && [sself.delegate respondsToSelector:@selector(videoPlayerPlayProgressDidChange:elapsedSeconds:totalSeconds:)]) {
                    [sself.delegate videoPlayerPlayProgressDidChange:sself
                                                      elapsedSeconds:elapsedSeconds
                                                        totalSeconds:totalSeconds];
                }
            });
        }

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

- (NSURL *)composeFakeVideoURL {
    NSURLComponents *components = [[NSURLComponents alloc] initWithURL:[NSURL URLWithString:JPVideoPlayerURL] resolvingAgainstBaseURL:NO];
    components.scheme = JPVideoPlayerURLScheme;
    return [components URL];
}

- (void)displayVideoPicturesOnShowLayer {
    if (!self.playerModel.isCancelled && !self.playerModel.playerLayer.superlayer) {
        // fixed #26.
        self.playerModel.playerLayer.frame = self.playerModel.unownedShowLayer.bounds;
        // remove all layer layout animations.
        [self.playerModel.unownedShowLayer removeAllAnimations];
        [self.playerModel.playerLayer removeAllAnimations];
        [self.playerModel.unownedShowLayer addSublayer:self.playerModel.playerLayer];
    }
}

- (void)callDelegateMethodWithError:(NSError *)error {
    JPErrorLog(@"Player abort because of error: %@", error);
    JPDispatchAsyncOnMainQueue(^{
        if (self.delegate && [self.delegate respondsToSelector:@selector(videoPlayer:playFailedWithError:)]) {
            [self.delegate videoPlayer:self playFailedWithError:error];
        }
    });
}

@end
