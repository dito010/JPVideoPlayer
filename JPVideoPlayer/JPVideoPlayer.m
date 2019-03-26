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
#import "JPReusePool.h"

@interface JPVideoPlayerModel()<JPReusableObject>

@property(nonatomic, strong, nullable)NSURL *url;

/// The layer of the video picture will show on.
@property(nonatomic, weak, nullable)CALayer *unownedShowLayer;

@property(nonatomic, assign)JPVideoPlayerOptions playerOptions;

@property(nonatomic, strong, nullable)AVPlayerItem *playerItem;

@property(nonatomic, strong, nullable)AVURLAsset *videoURLAsset;

/// The resourceLoader for the videoPlayer.
@property(nonatomic, strong, nullable)JPVideoPlayerResourceLoader *resourceLoader;

@end

static NSString *JPVideoPlayerURLScheme = @"com.jpvideoplayer.system.cannot.recognition.scheme.www";
static NSString *JPVideoPlayerURL = @"www.newpan.com";
@implementation JPVideoPlayerModel

- (void)prepareToReuse {
    self.onUsing = NO;
    self.unownedShowLayer = nil;
    self.playerItem = nil;
    self.videoURLAsset = nil;
    self.url = nil;
    self.resourceLoader = nil;
}

@end

@interface JPVideoPlayer()<JPVideoPlayerResourceLoaderDelegate>

/// The current play video item.
@property(nonatomic, strong, nullable)JPVideoPlayerModel *playerModel;

@property(nonatomic, assign) JPVideoPlayerStatus playerStatus;

@property(nonatomic, assign) BOOL seekingToTime;

@property(nonatomic, strong) JPReusePool<JPVideoPlayerModel *> *playerModelReusePool;

@property(nonatomic, strong, nullable)AVPlayer *player;

@property(nonatomic, strong, nullable)AVPlayerLayer *playerLayer;

@property(nonatomic, assign) NSTimeInterval elapsedSeconds;

@property(nonatomic, assign) NSTimeInterval totalSeconds;

/// The player progress observer.
@property(nonatomic, strong) id playerPeriodicTimeObserver;

@end

@implementation JPVideoPlayer

- (void)dealloc {
    [self.player removeObserver:self forKeyPath:@"rate"];
    [self _reset];
}

- (instancetype)init{
    self = [super init];
    if (self) {
        _playerStatus = JPVideoPlayerStatusUnknown;
        _seekingToTime = NO;
        _playerModelReusePool = [[JPReusePool alloc] initWithReusableObjectClass:[JPVideoPlayerModel class]];
        _periodicTimeObserverInterval = CMTimeMake(1, 10);
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
        [self _callDelegateMethodWithError:JPErrorWithDescription(@"The url is disable")];
        return nil;
    }

    if (fullVideoCachePath.length == 0) {
        [self _callDelegateMethodWithError:JPErrorWithDescription(@"The file path is disable")];
        return nil;
    }

    if (!showLayer) {
        [self _callDelegateMethodWithError:JPErrorWithDescription(@"The layer to display video layer is nil")];
        return nil;
    }

    @autoreleasepool {
        NSURL *videoPathURL = [NSURL fileURLWithPath:fullVideoCachePath];
        AVURLAsset *videoURLAsset = [AVURLAsset URLAssetWithURL:videoPathURL options:nil];
        AVPlayerItem *playerItem = [AVPlayerItem playerItemWithAsset:videoURLAsset];
        JPVideoPlayerModel *playerModel = [self _playVideoWithURL:url
                                                          options:options
                                                        showLayer:showLayer
                                                       playerItem:playerItem
                                                    configuration:configuration];
        playerModel.videoURLAsset = videoURLAsset;
        return playerModel;
    }
}

- (nullable JPVideoPlayerModel *)playVideoWithURL:(NSURL *)url
                                          options:(JPVideoPlayerOptions)options
                                        showLayer:(CALayer *)showLayer
                                    configuration:(JPVideoPlayerConfiguration)configuration {
    if (!url.absoluteString.length) {
        [self _callDelegateMethodWithError:JPErrorWithDescription(@"The url is disable")];
        return nil;
    }

    if (!showLayer) {
        [self _callDelegateMethodWithError:JPErrorWithDescription(@"The layer to display video layer is nil")];
        return nil;
    }

    @autoreleasepool {
        // Re-create all all configuration again.
        // Make the `resourceLoader` become the delegate of 'videoURLAsset', and provide data to the player.
        JPVideoPlayerResourceLoader *resourceLoader = [JPVideoPlayerResourceLoader resourceLoaderWithCustomURL:url];
        resourceLoader.delegate = self;

        // url instead of `[self _composeFakeVideoURL]`, otherwise some urls can not play normally
        AVURLAsset *videoURLAsset = [AVURLAsset URLAssetWithURL:[self _composeFakeVideoURL] options:nil];
        [videoURLAsset.resourceLoader setDelegate:resourceLoader queue:dispatch_get_main_queue()]; // TODO: customize dispatch queue.

        AVPlayerItem *playerItem = [AVPlayerItem playerItemWithAsset:videoURLAsset];
        JPVideoPlayerModel *playerModel = [self _playVideoWithURL:url
                                                          options:options
                                                        showLayer:showLayer
                                                       playerItem:playerItem
                                                    configuration:configuration];
        playerModel.resourceLoader = resourceLoader;
        playerModel.videoURLAsset = videoURLAsset;
        return playerModel;
    }
}

- (void)resumePlayWithShowLayer:(CALayer *)showLayer
                        options:(JPVideoPlayerOptions)options
                  configuration:(JPVideoPlayerConfiguration)configuration {
    JPAssertMainThread;
    if (!showLayer) {
        [self _callDelegateMethodWithError:JPErrorWithDescription(@"The layer to display video layer is nil")];
        return;
    }

    if (self.playerModel.unownedShowLayer != showLayer) {
        [self.playerLayer removeFromSuperlayer];
        self.playerModel.unownedShowLayer = showLayer;
        [self _setVideoGravityWithOptions:options playerModel:self.playerModel];
        [self displayVideoPicturesOnShowLayer];
    }

    self.player.muted = options & JPVideoPlayerMutedPlay;
    if(configuration) configuration(self.playerModel);
    [self _invokePlayerStatusDidChangeDelegateMethod];
}

- (void)seekToTimeWhenRecordPlayback:(CMTime)time {
    if(!self.playerModel || !CMTIME_IS_VALID(time)) return;
    __weak typeof(self) wself = self;
    [self.player seekToTime:time completionHandler:^(BOOL finished) {

        __strong typeof(wself) sself = wself;
        if(finished){
            [sself _internalResumeWithNeedCallDelegate:YES];
        }

    }];
}


#pragma mark - JPVideoPlayerPlaybackProtocol

- (void)setRate:(float)rate {
    if (!self.playerModel) return;
    [self.player setRate:rate];
}

- (float)rate {
    if (!self.playerModel) return 0.f;
    return self.player.rate;
}

- (void)setMuted:(BOOL)muted {
    if (!self.playerModel) return;
    [self.player setMuted:muted];
}

- (BOOL)muted {
    if (!self.playerModel) return NO;
    return self.player.muted;
}

- (void)setVolume:(float)volume {
    if (!self.playerModel) return;
    [self.player setVolume:volume];
}

- (float)volume {
    if (!self.playerModel) return 0.f;
    return self.player.volume;
}

- (BOOL)seekToTime:(CMTime)time {
    if(!self.playerModel || !CMTIME_IS_VALID(time)) return NO;
    if (self.playerStatus == JPVideoPlayerStatusUnknown || self.playerStatus == JPVideoPlayerStatusFailed || self.playerStatus == JPVideoPlayerStatusStop) return NO;

    BOOL needResume = self.player.rate > 0.f;
    [self _internalPauseWithNeedCallDelegate:NO];
    self.seekingToTime = YES;
    __weak typeof(self) wself = self;
    [self.player seekToTime:time completionHandler:^(BOOL finished) {

        __strong typeof(wself) sself = wself;
        sself.seekingToTime = NO;
        if(finished && needResume){
            [sself _internalResumeWithNeedCallDelegate:NO];
        }

    }];

    return YES;
}

- (void)pause {
    if (!self.playerModel) return;
    [self _internalPauseWithNeedCallDelegate:YES];
}

- (void)resume {
    if (!self.playerModel) return;
    if(self.playerStatus == JPVideoPlayerStatusStop){
        self.playerStatus = JPVideoPlayerStatusUnknown;
        [self _seekToHeaderThenStartPlayback];
        return;
    }
    [self _internalResumeWithNeedCallDelegate:YES];
}

- (CMTime)currentTime {
    if (!self.playerModel) return kCMTimeZero;
    return self.player.currentTime;
}

- (void)stopPlay {
    if (!self.playerModel) return;
    [self _reset];
    self.playerStatus = JPVideoPlayerStatusStop;
    [self _invokePlayerStatusDidChangeDelegateMethod];
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
                                             selector:@selector(_playerItemDidPlayToEnd:)
                                                 name:AVPlayerItemDidPlayToEndTimeNotification
                                               object:playerItem];
}

- (void)removePlayerItemDidPlayToEndObserver {
    [NSNotificationCenter.defaultCenter removeObserver:self
                                                  name:AVPlayerItemDidPlayToEndTimeNotification
                                                object:nil];
}


#pragma mark - AVPlayer Observer

- (void)_playerItemDidPlayToEnd:(NSNotification *)notification {
    AVPlayerItem *playerItem = notification.object;
    if(playerItem != self.playerModel.playerItem) return;

    self.playerStatus = JPVideoPlayerStatusStop;
    [self _invokePlayerStatusDidChangeDelegateMethod];

    // ask need automatic replay or not.
    if (self.delegate && [self.delegate respondsToSelector:@selector(videoPlayer:shouldAutoReplayVideoForURL:)]) {
        if (![self.delegate videoPlayer:self shouldAutoReplayVideoForURL:self.playerModel.url]) return;
    }
    [self _seekToHeaderThenStartPlayback];
}

- (void)observeValueForKeyPath:(NSString *)keyPath
                      ofObject:(id)object
                        change:(NSDictionary<NSString *,id> *)change
                       context:(void *)context{
    if (object == self.player) {
        if([keyPath isEqualToString:@"rate"]) {
            float rate = [change[NSKeyValueChangeNewKey] floatValue];
            if((rate != 0) && (self.playerStatus == JPVideoPlayerStatusReadyToPlay)){
                self.playerStatus = JPVideoPlayerStatusPlaying;
                [self _invokePlayerStatusDidChangeDelegateMethod];
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
                    [self _invokePlayerStatusDidChangeDelegateMethod];
                    break;
                }

                case AVPlayerItemStatusReadyToPlay:{
                    JPDebugLog(@"AVPlayerItemStatusReadyToPlay");
                    self.playerStatus = JPVideoPlayerStatusReadyToPlay;
                    // When get ready to play note, we can go to play, and can add the video picture on show view.
                    if (!self.playerModel) return;
                    [self _invokePlayerStatusDidChangeDelegateMethod];
                    [self.player play];
                    [self displayVideoPicturesOnShowLayer];
                    break;
                }

                case AVPlayerItemStatusFailed:{
                    self.playerStatus = JPVideoPlayerStatusFailed;
                    JPDebugLog(@"AVPlayerItemStatusFailed");
                    [self _callDelegateMethodWithError:JPErrorWithDescription(@"AVPlayerItemStatusFailed")];
                    [self _invokePlayerStatusDidChangeDelegateMethod];
                    break;
                }

                default:
                    break;
            }
        }
        else if ([keyPath isEqualToString:@"playbackLikelyToKeepUp"]) {
            BOOL playbackLikelyToKeepUp = self.playerModel.playerItem.playbackLikelyToKeepUp;
            JPDebugLog(@"%@", playbackLikelyToKeepUp ? @"buffering finished, start to play." : @"start to buffer.");
            self.playerStatus = playbackLikelyToKeepUp ? JPVideoPlayerStatusPlaying : JPVideoPlayerStatusBuffering;
            [self _invokePlayerStatusDidChangeDelegateMethod];
        }
        else if ([keyPath isEqualToString:@"playbackBufferEmpty"]) {
            BOOL playbackBufferEmpty = self.playerModel.playerItem.playbackBufferEmpty;
            JPDebugLog(@"playbackBufferEmpty: %@.", playbackBufferEmpty ? @"empty" : @"not empty");
            if (playbackBufferEmpty) {
                self.playerStatus = JPVideoPlayerStatusBuffering;
                [self _invokePlayerStatusDidChangeDelegateMethod];
            }
        }
        else if ([keyPath isEqualToString:@"playbackBufferFull"]) {
            BOOL playbackBufferFull = self.playerModel.playerItem.playbackBufferFull;
            JPDebugLog(@"playbackBufferFull: %@.", playbackBufferFull ? @"full" : @"not full");
            if (playbackBufferFull) {
                self.playerStatus = JPVideoPlayerStatusPlaying;
                [self _invokePlayerStatusDidChangeDelegateMethod];
            }
        }
    }
}


#pragma mark - Private

- (void)_playbackTimeDidChange:(CMTime)time {
    if (!self.playerModel) return;

    NSTimeInterval elapsedSeconds = CMTimeGetSeconds(time);
    NSTimeInterval totalSeconds = CMTimeGetSeconds(self.playerModel.playerItem.duration);
    self.elapsedSeconds = elapsedSeconds;
    self.totalSeconds = totalSeconds;
    if(totalSeconds <= 1e-3 || isnan(totalSeconds) || elapsedSeconds > totalSeconds) return;

    if (self.seekingToTime) return;
    JPDispatchSyncOnMainQueue(^{
        if (self.delegate && [self.delegate respondsToSelector:@selector(videoPlayerPlayProgressDidChange:elapsedSeconds:totalSeconds:)]) {
            [self.delegate videoPlayerPlayProgressDidChange:self
                                             elapsedSeconds:elapsedSeconds
                                               totalSeconds:totalSeconds];
        }
    });
}

- (void)_seekToHeaderThenStartPlayback {
    // Seek the start point of file data and repeat play, this handle have no memory surge.
    __weak typeof(self) wself = self;
    [self _invokePlayerStatusDidChangeDelegateMethod];

    [self.player seekToTime:CMTimeMake(0, 1) completionHandler:^(BOOL finished) {

        __weak typeof(wself) sself = wself;
        [sself.player play];
        sself.playerStatus = JPVideoPlayerStatusPlaying;
        [sself _invokePlayerStatusDidChangeDelegateMethod];

    }];
}

- (void)_invokePlayerStatusDidChangeDelegateMethod {
    JPDispatchSyncOnMainQueue(^{
        if (self.delegate && [self.delegate respondsToSelector:@selector(videoPlayer:playerStatusDidChange:)]) {
            [self.delegate videoPlayer:self playerStatusDidChange:self.playerStatus];
        }
    });
}

- (void)_internalPauseWithNeedCallDelegate:(BOOL)needCallDelegate {
    [self.player pause];
    self.playerStatus = JPVideoPlayerStatusPause;
    if(needCallDelegate){
        [self _invokePlayerStatusDidChangeDelegateMethod];
    }
}

- (void)_internalResumeWithNeedCallDelegate:(BOOL)needCallDelegate {
    [self.player play];
    self.playerStatus = JPVideoPlayerStatusPlaying;
    if(needCallDelegate){
        [self _invokePlayerStatusDidChangeDelegateMethod];
    }
}

- (JPVideoPlayerModel *)_playerModelWithURL:(NSURL *)url
                                 playerItem:(AVPlayerItem *)playerItem
                                    options:(JPVideoPlayerOptions)options
                                showOnLayer:(CALayer *)showLayer {
    @autoreleasepool {
        JPVideoPlayerModel *model = [self.playerModelReusePool retrieveReusableObject];
        model.unownedShowLayer = showLayer;
        model.url = url;
        model.playerOptions = options;
        model.playerItem = playerItem;

        [playerItem addObserver:self forKeyPath:@"status" options:NSKeyValueObservingOptionNew context:nil];
        [playerItem addObserver:self forKeyPath:@"playbackLikelyToKeepUp" options:NSKeyValueObservingOptionNew context:nil];
        [playerItem addObserver:self forKeyPath:@"playbackBufferEmpty" options:NSKeyValueObservingOptionNew context:nil];
        [playerItem addObserver:self forKeyPath:@"playbackBufferFull" options:NSKeyValueObservingOptionNew context:nil];

        [self _generatePlayerOnceOrReplaceCurrentItemWithPlayerItem:playerItem];

        // add observer for video playing progress.
        __weak typeof(self) wself = self;
        _playerPeriodicTimeObserver = [self.player addPeriodicTimeObserverForInterval:self.periodicTimeObserverInterval queue:dispatch_get_main_queue() usingBlock:^(CMTime time){

            __strong typeof(wself) sself = wself;
            if (!sself) return;
            [sself _playbackTimeDidChange:time];

        }];
        if (!self.playerLayer) self.playerLayer = [AVPlayerLayer playerLayerWithPlayer:self.player];
        [self _setVideoGravityWithOptions:options playerModel:model];
        self.playerStatus = JPVideoPlayerStatusUnknown;

        return model;
    }
}

- (void)_setVideoGravityWithOptions:(JPVideoPlayerOptions)options
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
    self.playerLayer.videoGravity = videoGravity;
}

- (NSURL *)_composeFakeVideoURL {
    NSURLComponents *components = [[NSURLComponents alloc] initWithURL:[NSURL URLWithString:JPVideoPlayerURL] resolvingAgainstBaseURL:NO];
    components.scheme = JPVideoPlayerURLScheme;
    return [components URL];
}

- (void)displayVideoPicturesOnShowLayer {
    if (!self.playerModel || !self.playerLayer) return;
    // fixed #26.
    self.playerLayer.frame = self.playerModel.unownedShowLayer.bounds;
    // remove all layer layout animations.
    [self.playerModel.unownedShowLayer removeAllAnimations];
    [self.playerLayer removeAllAnimations];
    if (self.playerLayer.superlayer) [self.playerLayer removeFromSuperlayer];
    [self.playerModel.unownedShowLayer addSublayer:self.playerLayer];
}

- (void)_hidePlayerLayerIfNeed {
    if (!self.playerLayer.superlayer) return;
    [self.playerLayer removeFromSuperlayer];
}

- (void)_callDelegateMethodWithError:(NSError *)error {
    JPErrorLog(@"Player abort because of error: %@", error);
    JPDispatchAsyncOnMainQueue(^{
        if (self.delegate && [self.delegate respondsToSelector:@selector(videoPlayer:playFailedWithError:)]) {
            [self.delegate videoPlayer:self playFailedWithError:error];
        }
    });
}

- (nullable JPVideoPlayerModel *)_playVideoWithURL:(NSURL *)url
                                           options:(JPVideoPlayerOptions)options
                                         showLayer:(CALayer *)showLayer
                                        playerItem:(AVPlayerItem *)playerItem
                                     configuration:(JPVideoPlayerConfiguration)configuration {
    [self _reset];
    [self addPlayerItemDidPlayToEndObserver:playerItem];
    self.playerModel = [self _playerModelWithURL:url
                                      playerItem:playerItem
                                         options:options
                                     showOnLayer:showLayer];
    self.player.muted = options & JPVideoPlayerMutedPlay;
    if(configuration) configuration(self.playerModel);
    [self _invokePlayerStatusDidChangeDelegateMethod];
    return self.playerModel;
}

- (void)_reset {
    [self _hidePlayerLayerIfNeed];
    if (!self.playerModel) return;

    // remove observer.
    [self.playerModel.playerItem removeObserver:self forKeyPath:@"status"];
    [self.playerModel.playerItem removeObserver:self forKeyPath:@"playbackLikelyToKeepUp"];
    [self.playerModel.playerItem removeObserver:self forKeyPath:@"playbackBufferEmpty"];
    [self.playerModel.playerItem removeObserver:self forKeyPath:@"playbackBufferFull"];

    [self removePlayerItemDidPlayToEndObserver];

    if (self.playerPeriodicTimeObserver) {
        [self.player removeTimeObserver:self.playerPeriodicTimeObserver];
        self.playerPeriodicTimeObserver = nil;
    }

    [self.player cancelPendingPrerolls];
    [self.player pause];
    if (self.playerModel.resourceLoader) {
        [self.playerModel.videoURLAsset.resourceLoader setDelegate:nil queue:nil];
    }

    [self.playerModelReusePool objectPerformReuse:self.playerModel];
    self.playerModel = nil;
}

- (void)_generatePlayerOnceOrReplaceCurrentItemWithPlayerItem:(AVPlayerItem *)playerItem {
    NSParameterAssert(playerItem);
    if (!playerItem) return;

    if (!self.player) {
        self.player = ({
            AVPlayer *player = [AVPlayer playerWithPlayerItem:playerItem];
            [player addObserver:self forKeyPath:@"rate" options:NSKeyValueObservingOptionNew context:nil];
            if ([player respondsToSelector:@selector(automaticallyWaitsToMinimizeStalling)]) {
                player.automaticallyWaitsToMinimizeStalling = NO;
            }

            player;
        });
        return;
    }

    [self.player replaceCurrentItemWithPlayerItem:playerItem];
}

@end
