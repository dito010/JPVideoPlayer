/*
 * This file is part of the JPVideoPlayer package.
 * (c) NewPan <13246884282@163.com>
 *
 * For the full copyright and license information, please view the LICENSE
 * file that was distributed with this source code.
 *
 * Click https://github.com/Chris-Pan
 * or http://www.jianshu.com/users/e2f2d779c022/latest_articles to contact me.
 */

#import "JPVideoPlayer.h"
#import "JPVideoPlayerResourceLoader.h"
#import "UIView+PlayerStatusAndDownloadIndicator.h"
#import "JPVideoPlayerDownloaderOperation.h"
#import "JPVideoPlayerCompat.h"
#import "UIView+WebVideoCache.h"
#import <pthread.h>

CGFloat const JPVideoPlayerLayerFrameY = 1;

@interface JPVideoPlayerModel()

/** 
 * The playing URL
 */
@property(nonatomic, strong, nullable)NSURL *url;

/**
 * The view of the video picture will show on.
 */
@property(nonatomic, weak, nullable)UIView *unownShowView;

/**
 * options
 */
@property(nonatomic, assign)JPVideoPlayerOptions playerOptions;

/**
 * The Player to play video.
 */
@property(nonatomic, strong, nullable)AVPlayer *player;

/**
 * The current player's layer.
 */
@property(nonatomic, strong, nullable)AVPlayerLayer *currentPlayerLayer;

/**
 * The current player's item.
 */
@property(nonatomic, strong, nullable)AVPlayerItem *currentPlayerItem;

/**
 * The current player's urlAsset.
 */
@property(nonatomic, strong, nullable)AVURLAsset *videoURLAsset;

/**
 * A flag to book is cancel play or not.
 */
@property(nonatomic, assign, getter=isCancelled)BOOL cancelled;

/**
 * Error message.
 */
@property(nonatomic, strong, nullable)JPVideoPlayerErrorBlock error;

/**
 * The resourceLoader for the videoPlayer.
 */
@property(nonatomic, strong, nullable)JPVideoPlayerResourceLoader *resourceLoader;

/**
 * The current playing url key.
 */
@property(nonatomic, strong, nonnull)NSString *playingKey;

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

@end

static NSString *JPVideoPlayerURLScheme = @"SystemCannotRecognition";
static NSString *JPVideoPlayerURL = @"www.newpan.com";
@implementation JPVideoPlayerModel

- (void)stopPlayVideo{
    self.cancelled = YES;
    
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
    [self.unownShowView performSelector:NSSelectorFromString(@"jp_hideProgressView")];
    [self.unownShowView performSelector:NSSelectorFromString(@"jp_hideActivityIndicatorView")];
#pragma clang diagnostic pop
    
    [self reset];
}

- (void)pausePlayVideo{
    if (!self.player) {
        return;
    }
    [self.player pause];
}

- (void)resumePlayVideo{
    if (!self.player) {
        return;
    }
    [self.player play];
}

- (void)reset{
    // remove video layer from superlayer.
    if (self.unownShowView.jp_backgroundLayer.superlayer) {
        [self.currentPlayerLayer removeFromSuperlayer];
        [self.unownShowView.jp_backgroundLayer removeFromSuperlayer];
    }
    
    // remove observer.
    [self.currentPlayerItem removeObserver:self.videoPlayer forKeyPath:@"status"];
    [self.currentPlayerItem removeObserver:self.videoPlayer forKeyPath:@"loadedTimeRanges"];
    [self.player removeTimeObserver:self.timeObserver];
    
    // remove player
    [self.player pause];
    [self.player cancelPendingPrerolls];
    self.player = nil;
    [self.videoURLAsset.resourceLoader setDelegate:nil queue:dispatch_get_main_queue()];
    self.currentPlayerItem = nil;
    self.currentPlayerLayer = nil;
    self.videoURLAsset = nil;
    self.resourceLoader = nil;
}

@end


@interface JPVideoPlayer()<JPVideoPlayerResourceLoaderDelegate>

/**
 * The current play video item.
 */
@property(nonatomic, strong, nullable)JPVideoPlayerModel *currentVideoPlayerModel;

/**
 * The playing status of video player before app enter background.
 */
@property(nonatomic, assign)JPVideoPlayerStatus playingStatus_beforeEnterBackground;

/*
 * lock.
 */
@property(nonatomic) pthread_mutex_t lock;


@end

@implementation JPVideoPlayer

- (void)dealloc {
    pthread_mutex_destroy(&_lock);
    [self.currentVideoPlayerModel.currentPlayerItem removeObserver:self forKeyPath:@"status"];
    [self.currentVideoPlayerModel.currentPlayerItem removeObserver:self forKeyPath:@"loadedTimeRanges"];
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (instancetype)init{
    self = [super init];
    if (self) {
        pthread_mutex_init(&(_lock), NULL);
        [self addObserver];
    }
    return self;
}


#pragma mark - Public

- (nullable JPVideoPlayerModel *)playExistedVideoWithURL:(NSURL * _Nullable)url
                                      fullVideoCachePath:(NSString * _Nullable)fullVideoCachePath
                                                 options:(JPVideoPlayerOptions)options
                                              showOnView:(UIView * _Nullable)showView
                                                progress:(JPVideoPlayerProgressBlock _Nullable )progress
                                                   error:(nullable JPVideoPlayerErrorBlock)error {
    if (!url.absoluteString.length) {
        NSError *e = [NSError errorWithDomain:JPVideoPlayerErrorDomain code:0 userInfo:@{NSLocalizedDescriptionKey : @"the url is disable"}];
        if (error) error(e);
        return nil;
    }
    
    if (fullVideoCachePath.length==0) {
        NSError *e = [NSError errorWithDomain:JPVideoPlayerErrorDomain code:0 userInfo:@{NSLocalizedDescriptionKey : @"the file path is disable"}];
        if (error) error(e);
        return nil;
    }
    
    if (!showView) {
        NSError *e = [NSError errorWithDomain:JPVideoPlayerErrorDomain code:0 userInfo:@{NSLocalizedDescriptionKey : @"the layer to display video layer is nil"}];
        if (error) error(e);
        return nil;
    }
    
    NSURL *videoPathURL = [NSURL fileURLWithPath:fullVideoCachePath];
    AVURLAsset *videoURLAsset = [AVURLAsset URLAssetWithURL:videoPathURL options:nil];
    AVPlayerItem *playerItem = [AVPlayerItem playerItemWithAsset:videoURLAsset];
    JPVideoPlayerModel *model = [self generatePlayerModelWithURL:url
                                                      playerItem:playerItem
                                                         options:options
                                                      showOnView:showView
                                                        progress:progress
                                                           error:error];
    if (options & JPVideoPlayerMutedPlay) {
        model.player.muted = YES;
    }
    self.currentVideoPlayerModel = model;
    return model;
}

- (JPVideoPlayerModel *)playVideoWithURL:(NSURL *)url
                                 options:(JPVideoPlayerOptions)options
                              showOnView:(UIView *)showView
                                progress:(JPVideoPlayerProgressBlock)progress
                                   error:(JPVideoPlayerErrorBlock)error {
    if (!url.absoluteString.length) {
        NSError *e = [NSError errorWithDomain:JPVideoPlayerErrorDomain code:0 userInfo:@{NSLocalizedDescriptionKey : @"the url is disable"}];
        if (error) error(e);
        return nil;
    }
    
    if (!showView) {
        NSError *e = [NSError errorWithDomain:JPVideoPlayerErrorDomain code:0 userInfo:@{NSLocalizedDescriptionKey : @"the layer to display video layer is nil"}];
        if (error) error(e);
        return nil;
    }
    
    // Re-create all all configuration agian.
    // Make the `resourceLoader` become the delegate of 'videoURLAsset', and provide data to the player.
    JPVideoPlayerResourceLoader *resourceLoader = [JPVideoPlayerResourceLoader new];
    resourceLoader.delegate = self;
    AVURLAsset *videoURLAsset = [AVURLAsset URLAssetWithURL:url options:nil];
    [videoURLAsset.resourceLoader setDelegate:resourceLoader queue:dispatch_get_main_queue()];
    AVPlayerItem *playerItem = [AVPlayerItem playerItemWithAsset:videoURLAsset];
    JPVideoPlayerModel *model = [self generatePlayerModelWithURL:url
                                                      playerItem:playerItem
                                                         options:options
                                                      showOnView:showView
                                                        progress:progress
                                                           error:error];
    self.currentVideoPlayerModel = model;
    model.resourceLoader = resourceLoader;
    if (options & JPVideoPlayerMutedPlay) {
        model.player.muted = YES;
    }
    return model;
}

- (void)didReceivedDataCacheInDiskByTempPath:(NSString * _Nonnull)tempCacheVideoPath
                         videoFileExceptSize:(NSUInteger)expectedSize
                       videoFileReceivedSize:(NSUInteger)receivedSize{
    [self.currentVideoPlayerModel.resourceLoader didReceivedDataCacheInDiskByTempPath:tempCacheVideoPath
                                                                  videoFileExceptSize:expectedSize
                                                                videoFileReceivedSize:receivedSize];
}

- (void)didCachedVideoDataFinishedFromWebFullVideoCachePath:(NSString * _Nullable)fullVideoCachePath{
    if (self.currentVideoPlayerModel.resourceLoader) {
        [self.currentVideoPlayerModel.resourceLoader didCachedVideoDataFinishedFromWebFullVideoCachePath:fullVideoCachePath];
    }
}

- (void)setMute:(BOOL)mute{
    self.currentVideoPlayerModel.player.muted = mute;
}

- (void)stopPlay{
    [self.currentVideoPlayerModel stopPlayVideo];
    self.currentVideoPlayerModel = nil;
    if (self.delegate && [self.delegate respondsToSelector:@selector(videoPlayer:playStatusDidChange:)]) {
        [self.delegate videoPlayer:self playStatusDidChange:JPVideoPlayerStatusStop];
    }
}

- (void)pause{
    [self.currentVideoPlayerModel pausePlayVideo];
    
    if (self.delegate && [self.delegate respondsToSelector:@selector(videoPlayer:playStatusDidChange:)]) {
        [self.delegate videoPlayer:self playStatusDidChange:JPVideoPlayerStatusPause];
    }
}

- (void)resume{
    [self.currentVideoPlayerModel resumePlayVideo];
    
    if (self.delegate && [self.delegate respondsToSelector:@selector(videoPlayer:playStatusDidChange:)]) {
        [self.delegate videoPlayer:self playStatusDidChange:JPVideoPlayerStatusPlaying];
    }
}


#pragma mark - JPVideoPlayerResourceLoaderDelegate

- (void)resourceLoader:(JPVideoPlayerResourceLoader *)resourceLoader requestRangeDidChange:(NSString *)requestRangeString {
    if (self.delegate && [self.delegate respondsToSelector:@selector(videoPlayer:playerRequestRangeDidChange:)]) {
        [self.delegate videoPlayer:self playerRequestRangeDidChange:requestRangeString];
    }
}


#pragma mark - App Observer

- (void)addObserver {
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(appDidEnterBackground) name:UIApplicationWillResignActiveNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(appDidEnterPlayGround) name:UIApplicationDidBecomeActiveNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(playerItemDidPlayToEnd:) name:AVPlayerItemDidPlayToEndTimeNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(appReceivedMemoryWarning) name:UIApplicationDidReceiveMemoryWarningNotification object:nil];
}

- (void)appReceivedMemoryWarning{
    [self.currentVideoPlayerModel stopPlayVideo];
}

- (void)appDidEnterBackground{
    [self.currentVideoPlayerModel pausePlayVideo];
    if (self.currentVideoPlayerModel.unownShowView) {
        self.playingStatus_beforeEnterBackground = self.currentVideoPlayerModel.unownShowView.playingStatus;
    }
    
    if (self.delegate && [self.delegate respondsToSelector:@selector(videoPlayer:playStatusDidChange:)]) {
        [self.delegate videoPlayer:self playStatusDidChange:JPVideoPlayerStatusPause];
    }
}

- (void)appDidEnterPlayGround{
    // fixed #35.
    if (self.currentVideoPlayerModel.unownShowView && (self.playingStatus_beforeEnterBackground == JPVideoPlayerStatusPlaying)) {
        [self.currentVideoPlayerModel resumePlayVideo];
        
        if (self.delegate && [self.delegate respondsToSelector:@selector(videoPlayer:playStatusDidChange:)]) {
            [self.delegate videoPlayer:self playStatusDidChange:JPVideoPlayerStatusPlaying];
        }
    }
    else{
        [self.currentVideoPlayerModel pausePlayVideo];
        
        if (self.delegate && [self.delegate respondsToSelector:@selector(videoPlayer:playStatusDidChange:)]) {
            [self.delegate videoPlayer:self playStatusDidChange:JPVideoPlayerStatusPause];
        }
    }
}


#pragma mark - AVPlayer Observer

- (void)playerItemDidPlayToEnd:(NSNotification *)notification{
    // ask need automatic replay or not.
    if (self.delegate && [self.delegate respondsToSelector:@selector(videoPlayer:shouldAutoReplayVideoForURL:)]) {
        if (![self.delegate videoPlayer:self shouldAutoReplayVideoForURL:self.currentVideoPlayerModel.url]) {
            return;
        }
    }
    
    // Seek the start point of file data and repeat play, this handle have no memory surge.
    __weak typeof(self.currentVideoPlayerModel) weak_Item = self.currentVideoPlayerModel;
    [self.currentVideoPlayerModel.player seekToTime:CMTimeMake(0, 1) completionHandler:^(BOOL finished) {
        __strong typeof(weak_Item) strong_Item = weak_Item;
        if (!strong_Item) return;
        
        self.currentVideoPlayerModel.lastTime = 0;
        [strong_Item.player play];
        
        if (self.delegate && [self.delegate respondsToSelector:@selector(videoPlayer:playStatusDidChange:)]) {
            [self.delegate videoPlayer:self playStatusDidChange:JPVideoPlayerStatusPlaying];
        }
    }];
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary<NSString *,id> *)change context:(void *)context{
    if ([keyPath isEqualToString:@"status"]) {
        AVPlayerItem *playerItem = (AVPlayerItem *)object;
        AVPlayerItemStatus status = playerItem.status;
        switch (status) {
            case AVPlayerItemStatusUnknown:{
                if (self.delegate && [self.delegate respondsToSelector:@selector(videoPlayer:playStatusDidChange:)]) {
                    [self.delegate videoPlayer:self playStatusDidChange:JPVideoPlayerStatusUnkown];
                }
            }
                break;
                
            case AVPlayerItemStatusReadyToPlay:{
                // When get ready to play note, we can go to play, and can add the video picture on show view.
                if (!self.currentVideoPlayerModel) return;
                
                [self.currentVideoPlayerModel.player play];
                [self stopPlay];
                
                [self displayVideoPicturesOnShowLayer];
                [self hideActivaityIndicatorView];
                
                if (self.delegate && [self.delegate respondsToSelector:@selector(videoPlayer:playStatusDidChange:)]) {
                    [self.delegate videoPlayer:self playStatusDidChange:JPVideoPlayerStatusPlaying];
                }
            }
                break;
                
            case AVPlayerItemStatusFailed:{
                [self hideActivaityIndicatorView];
                
                NSError *e = [NSError errorWithDomain:JPVideoPlayerErrorDomain code:0 userInfo:@{NSLocalizedDescriptionKey : @"AVPlayerItemStatusFailed"}];
                if (self.currentVideoPlayerModel.error) self.currentVideoPlayerModel.error(e);
                
                if (self.delegate && [self.delegate respondsToSelector:@selector(videoPlayer:playStatusDidChange:)]) {
                    [self.delegate videoPlayer:self playStatusDidChange:JPVideoPlayerStatusFailed];
                }
            }
                break;
            default:
                break;
        }
    }
    else if ([keyPath isEqualToString:@"loadedTimeRanges"]){
        // It means player buffering if the player time don't change,
        // else if the player time plus than before, it means begain play.
        // fixed #28.
        NSTimeInterval currentTime = CMTimeGetSeconds(self.currentVideoPlayerModel.player.currentTime);

        if (currentTime != 0 && currentTime > self.currentVideoPlayerModel.lastTime) {
            [self hideActivaityIndicatorView];
            self.currentVideoPlayerModel.lastTime = currentTime;

            if (self.delegate && [self.delegate respondsToSelector:@selector(videoPlayer:playStatusDidChange:)]) {
                [self.delegate videoPlayer:self playStatusDidChange:JPVideoPlayerStatusPlaying];
            }
        }
        else{
            [self showActivaityIndicatorView];

            if (self.delegate && [self.delegate respondsToSelector:@selector(videoPlayer:playStatusDidChange:)]) {
                [self.delegate videoPlayer:self playStatusDidChange:JPVideoPlayerStatusBuffering];
            }
        }
    }
}


#pragma mark - Private

- (JPVideoPlayerModel *)generatePlayerModelWithURL:(NSURL *)url
                                        playerItem:(AVPlayerItem *)playerItem
                                           options:(JPVideoPlayerOptions)options
                                        showOnView:(UIView *)showView
                                          progress:(JPVideoPlayerProgressBlock)progress
                                             error:(JPVideoPlayerErrorBlock)error {
    JPVideoPlayerModel *model = [JPVideoPlayerModel new];
    model.unownShowView = showView;
    model.url = url;
    model.playerOptions = options;
    model.currentPlayerItem = playerItem;
    [playerItem addObserver:self forKeyPath:@"status" options:NSKeyValueObservingOptionNew context:nil];
    [playerItem addObserver:self forKeyPath:@"loadedTimeRanges" options:NSKeyValueObservingOptionNew context:nil];
    
    model.player = [AVPlayer playerWithPlayerItem:playerItem];
    model.currentPlayerLayer = [AVPlayerLayer playerLayerWithPlayer:model.player];
    
    NSString *videoGravity = nil;
    if (options&JPVideoPlayerLayerVideoGravityResizeAspect) {
        videoGravity = AVLayerVideoGravityResizeAspect;
    }
    else if (options&JPVideoPlayerLayerVideoGravityResize){
        videoGravity = AVLayerVideoGravityResize;
    }
    else if (options&JPVideoPlayerLayerVideoGravityResizeAspectFill){
        videoGravity = AVLayerVideoGravityResizeAspectFill;
    }
    model.currentPlayerLayer.videoGravity = videoGravity;
    model.unownShowView.jp_backgroundLayer.frame = CGRectMake(0, 0, showView.bounds.size.width, showView.bounds.size.height);
    model.currentPlayerLayer.frame = model.unownShowView.jp_backgroundLayer.bounds;
    model.error = error;
    model.playingKey = [[JPVideoPlayerManager sharedManager]cacheKeyForURL:url];
    
    // add observer for video playing progress.
    __weak typeof(model) wItem = model;
    [model.player addPeriodicTimeObserverForInterval:CMTimeMake(1.0, 10.0) queue:dispatch_get_main_queue() usingBlock:^(CMTime time){
        __strong typeof(wItem) sItem = wItem;
        if (!sItem) return;
        
        double current = CMTimeGetSeconds(time);
        double total = CMTimeGetSeconds(sItem.currentPlayerItem.duration);
        if (current && progress) {
            progress(current, total);
        }
    }];
    model.videoPlayer = self;
    return model;
}

- (void)showActivaityIndicatorView{
    if (self.currentVideoPlayerModel.playerOptions&JPVideoPlayerShowActivityIndicatorView){
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
        [self.currentVideoPlayerModel.unownShowView performSelector:NSSelectorFromString(@"jp_showActivityIndicatorView")];
#pragma clang diagnostic pop
    }
}

- (void)hideActivaityIndicatorView{
    if (self.currentVideoPlayerModel.playerOptions&JPVideoPlayerShowActivityIndicatorView){
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
        [self.currentVideoPlayerModel.unownShowView performSelector:NSSelectorFromString(@"jp_hideActivityIndicatorView")];
#pragma clang diagnostic pop
    }
}

- (void)setCurrentVideoPlayerModel:(JPVideoPlayerModel *)currentPlayVideoItem{
    [self willChangeValueForKey:@"currentPlayVideoItem"];
    _currentVideoPlayerModel = currentPlayVideoItem;
    [self didChangeValueForKey:@"currentPlayVideoItem"];
}

- (NSURL *)handleVideoURL:(NSURL *)url {
    NSURLComponents *components = [[NSURLComponents alloc] initWithURL:url resolvingAgainstBaseURL:NO];
    components.scheme = JPVideoPlayerURLScheme;
    return [components URL];
}

- (void)displayVideoPicturesOnShowLayer{
    if (!self.currentVideoPlayerModel.isCancelled) {
        // fixed #26.
//        [self.currentVideoPlayerModel.unownShowView.jp_backgroundLayer addSublayer:self.currentVideoPlayerModel.currentPlayerLayer];
        [self.currentVideoPlayerModel.unownShowView.layer addSublayer:self.currentVideoPlayerModel.currentPlayerLayer];
    }
}

@end
