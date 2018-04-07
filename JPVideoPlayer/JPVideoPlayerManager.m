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

#import "JPVideoPlayerManager.h"
#import "JPVideoPlayerCompat.h"
#import "JPVideoPlayerCachePath.h"
#import "JPVideoPlayer.h"
#import "UIView+WebVideoCache.h"
#import <pthread.h>
#import "JPVideoPlayerSupportUtils.h"
#import "JPVideoPlayerCacheFile.h"
#import "JPVideoPlayerResourceLoader.h"

@interface JPVideoPlayerManager()<JPVideoPlayerInternalDelegate,
                                  JPVideoPlayerDownloaderDelegate,
                                  JPApplicationStateMonitorDelegate>

@property (strong, nonatomic, readwrite, nonnull) JPVideoPlayerCache *videoCache;

@property (strong, nonatomic) JPVideoPlayerDownloader *videoDownloader;

@property (strong, nonatomic, nonnull) NSMutableSet<NSURL *> *failedURLs;

@property (nonatomic, strong) NSURL *videoURL;

@property (nonatomic, assign) JPVideoPlayerOptions playerOptions;

@property (nonatomic, strong, nonnull) JPVideoPlayer *videoPlayer;

@property (nonatomic) pthread_mutex_t lock;

@property(nonatomic, assign) BOOL isReturnWhenApplicationDidEnterBackground;

@property(nonatomic, assign) BOOL isReturnWhenApplicationWillResignActive;

@property (nonatomic, strong) JPApplicationStateMonitor *applicationStateMonitor;

@end

@implementation JPVideoPlayerManager

+ (nonnull instancetype)sharedManager {
    static dispatch_once_t once;
    static id instance;
    dispatch_once(&once, ^{
        instance = [self new];
    });
    return instance;
}

- (nonnull instancetype)init {
    JPVideoPlayerCache *cache = [JPVideoPlayerCache sharedCache];
    JPVideoPlayerDownloader *downloader = [JPVideoPlayerDownloader sharedDownloader];
    downloader.delegate = self;
    return [self initWithCache:cache downloader:downloader];
}

- (nonnull instancetype)initWithCache:(nonnull JPVideoPlayerCache *)cache
                           downloader:(nonnull JPVideoPlayerDownloader *)downloader {
    if ((self = [super init])) {
        _videoCache = cache;
        _videoDownloader = downloader;
        _failedURLs = [NSMutableSet new];
        pthread_mutexattr_t mutexattr;
        pthread_mutexattr_init(&mutexattr);
        pthread_mutexattr_settype(&mutexattr, PTHREAD_MUTEX_RECURSIVE);
        pthread_mutex_init(&_lock, &mutexattr);
        _videoPlayer = [JPVideoPlayer new];
        _videoPlayer.delegate = self;
        _isReturnWhenApplicationDidEnterBackground = NO;
        _isReturnWhenApplicationWillResignActive = NO;
        _applicationStateMonitor = [JPApplicationStateMonitor new];
        _applicationStateMonitor.delegate = self;
    }
    return self;
}


#pragma mark - Public

+ (void)preferLogLevel:(JPLogLevel)logLevel {
    _logLevel = logLevel;
}

- (void)playVideoWithURL:(NSURL *)url
             showOnLayer:(CALayer *)showLayer
                 options:(JPVideoPlayerOptions)options
     configFinishedBlock:(JPPlayVideoConfigFinishedBlock)configFinishedBlock {
    JPMainThreadAssert;
    NSParameterAssert(showLayer);

    // Very common mistake is to send the URL using NSString object instead of NSURL. For some strange reason, XCode won't
    // throw any warning for this type mismatch. Here we failsafe this error by allowing URLs to be passed as NSString.
    if ([url isKindOfClass:NSString.class]) {
        url = [NSURL URLWithString:(NSString *)url];
    }

    // Prevents app crashing on argument type error like sending NSNull instead of NSURL
    if (![url isKindOfClass:NSURL.class]) {
        url = nil;
    }

    self.videoURL = url;
    self.playerOptions = options;
    BOOL isFailedUrl = NO;
    if (url) {
        int lock = pthread_mutex_trylock(&_lock);
        isFailedUrl = [self.failedURLs containsObject:url];
        if (!lock) {
            pthread_mutex_unlock(&_lock);
        }
    }

    if (url.absoluteString.length == 0 || (!(options & JPVideoPlayerRetryFailed) && isFailedUrl)) {
        NSError *error = [NSError errorWithDomain:JPVideoPlayerErrorDomain
                                             code:NSURLErrorFileDoesNotExist
                                         userInfo:@{NSLocalizedDescriptionKey : @"The file of given URL not exists"}];
        [self callDownloadDelegateMethodWithFragmentRanges:nil
                                              expectedSize:1
                                                 cacheType:JPVideoPlayerCacheTypeNone
                                                     error:error];
        return;
    }

    BOOL isFileURL = [url isFileURL];
    if (isFileURL) {
        // play file URL.
        [self playLocalVideoWithShowLayer:showLayer
                                      url:url
                                  options:options
                      configFinishedBlock:configFinishedBlock];
        return;
    }
    else {
        NSString *key = [self cacheKeyForURL:url];
        [self.videoCache queryCacheOperationForKey:key completion:^(NSString *_Nullable videoPath, JPVideoPlayerCacheType cacheType) {

            if (!showLayer) {
                [self reset];
                return;
            }

            if (!videoPath && (![self.delegate respondsToSelector:@selector(videoPlayerManager:shouldDownloadVideoForURL:)] || [self.delegate videoPlayerManager:self shouldDownloadVideoForURL:url])) {
                // play web video.
                JPDebugLog(@"Start play a web video: %@", url);
                [self.videoPlayer playVideoWithURL:url
                                           options:options
                                         showLayer:showLayer
                               configFinishedBlock:configFinishedBlock];
            } else if (videoPath) {
                // full video cache file in disk.
                if(cacheType == JPVideoPlayerCacheTypeFull){
                    JPDebugLog(@"Start play a cached video: %@", url);
                    [self playExistedVideoWithShowLayer:showLayer
                                                    url:url
                                              videoPath:videoPath
                                                options:options
                                              cacheType:cacheType
                                    configFinishedBlock:configFinishedBlock];
                }
                else if(cacheType == JPVideoPlayerCacheTypeFragment) {
                    JPDebugLog(@"Start play a fragment video: %@", url);
                    [self playFragmentVideoWithURL:url
                                           options:options
                                         showLayer:showLayer
                               configFinishedBlock:configFinishedBlock];
                }
            }
            else {
                // video not in cache and download disallowed by delegate.
                NSError *error = [NSError errorWithDomain:JPVideoPlayerErrorDomain
                                                     code:NSURLErrorFileDoesNotExist
                                                 userInfo:@{NSLocalizedDescriptionKey: @"Video not in cache and download disallowed by delegate"}];
                [self callDownloadDelegateMethodWithFragmentRanges:nil
                                                      expectedSize:1
                                                         cacheType:JPVideoPlayerCacheTypeNone
                                                             error:error];
                [self reset];
            }
        }];
    }
}

- (NSString *_Nullable)cacheKeyForURL:(nullable NSURL *)url {
    if (!url) {
        return nil;
    }
    //#pragma clang diagnostic push
    //#pragma clang diagnostic ignored "-Wdeprecated-declarations"
    //    url = [[NSURL alloc] initWithScheme:url.scheme host:url.host path:url.path];
    //#pragma clang diagnostic pop
    return [url absoluteString];
}


#pragma mark - JPVideoPlayerPlaybackProtocol

- (void)setRate:(float)rate {
    [self.videoPlayer setRate:rate];
}

- (float)rate {
    return self.videoPlayer.rate;
}

- (void)setMuted:(BOOL)muted {
    [self.videoPlayer setMuted:muted];
}

- (BOOL)muted {
    return self.videoPlayer.muted;
}

- (void)setVolume:(float)volume {
    [self.videoPlayer setVolume:volume];
}

- (float)volume {
    return self.videoPlayer.volume;
}

- (void)seekToTime:(CMTime)time {
    [self.videoPlayer seekToTime:time];
}

- (void)pause {
    [self.videoPlayer pause];
}

- (void)resume {
    [self.videoPlayer resume];
}

- (CMTime)currentTime {
    return self.videoPlayer.currentTime;
}

- (void)stopPlay {
    JPDispatchSyncOnMainQueue(^{
        [self.videoDownloader cancel];
        [self.videoPlayer stopPlay];
        [self reset];
    });
}


#pragma mark - JPVideoPlayerInternalDelegate

- (void)videoPlayer:(nonnull JPVideoPlayer *)videoPlayer
didReceiveLoadingRequestTask:(JPResourceLoadingRequestWebTask *)requestTask {
    JPVideoPlayerDownloaderOptions downloaderOptions = [self fetchDownloadOptionsWithOptions:self.playerOptions];
    [self.videoDownloader downloadVideoWithRequestTask:requestTask
                                       downloadOptions:downloaderOptions];
}

- (BOOL)videoPlayer:(JPVideoPlayer *)videoPlayer
shouldAutoReplayVideoForURL:(NSURL *)videoURL {
    if (self.delegate && [self.delegate respondsToSelector:@selector(videoPlayerManager:shouldAutoReplayForURL:)]) {
        return [self.delegate videoPlayerManager:self shouldAutoReplayForURL:videoURL];
    }
    return YES;
}

- (void)videoPlayer:(nonnull JPVideoPlayer *)videoPlayer
playerStatusDidChange:(JPVideoPlayerStatus)playerStatus {
    if (self.delegate && [self.delegate respondsToSelector:@selector(videoPlayerManager:playerStatusDidChanged:)]) {
        [self.delegate videoPlayerManager:self playerStatusDidChanged:playerStatus];
    }
}

- (void)videoPlayerPlayProgressDidChange:(nonnull JPVideoPlayer *)videoPlayer
                          elapsedSeconds:(double)elapsedSeconds
                            totalSeconds:(double)totalSeconds {
    if (self.delegate && [self.delegate respondsToSelector:@selector(videoPlayerManagerPlayProgressDidChange:elapsedSeconds:totalSeconds:error:)]) {
        [self.delegate videoPlayerManagerPlayProgressDidChange:self
                                                elapsedSeconds:elapsedSeconds
                                                  totalSeconds:totalSeconds
                                                         error:nil];
    }
}

- (void)videoPlayer:(nonnull JPVideoPlayer *)videoPlayer
playFailedWithError:(NSError *)error {
    [self stopPlay];
    [self callPlayDelegateMethodWithElapsedSeconds:0
                                      totalSeconds:0
                                             error:error];
}


#pragma mark - JPVideoPlayerDownloaderDelegate

- (void)downloader:(JPVideoPlayerDownloader *)downloader
didReceiveResponse:(NSURLResponse *)response {
    NSUInteger fileLength = self.videoPlayer.currentPlayerModel.resourceLoader.cacheFile.fileLength;
    [self callVideoLengthDelegateMethodWithVideoLength:fileLength];
}

- (void)downloader:(JPVideoPlayerDownloader *)downloader
    didReceiveData:(NSData *)data
      receivedSize:(NSUInteger)receivedSize
      expectedSize:(NSUInteger)expectedSize {
    NSUInteger fileLength = self.videoPlayer.currentPlayerModel.resourceLoader.cacheFile.fileLength;
    NSArray<NSValue *> *fragmentRanges = self.videoPlayer.currentPlayerModel.resourceLoader.cacheFile.fragmentRanges;
    [self callDownloadDelegateMethodWithFragmentRanges:fragmentRanges
                                          expectedSize:fileLength
                                             cacheType:JPVideoPlayerCacheTypeFragment
                                                 error:nil];
}

- (void)downloader:(JPVideoPlayerDownloader *)downloader
didCompleteWithError:(NSError *)error {
    if (error){
        [self callDownloadDelegateMethodWithFragmentRanges:nil
                                              expectedSize:1
                                                 cacheType:JPVideoPlayerCacheTypeNone
                                                     error:error];

        if (error.code != NSURLErrorNotConnectedToInternet
                && error.code != NSURLErrorCancelled
                && error.code != NSURLErrorTimedOut
                && error.code != NSURLErrorInternationalRoamingOff
                && error.code != NSURLErrorDataNotAllowed
                && error.code != NSURLErrorCannotFindHost
                && error.code != NSURLErrorCannotConnectToHost) {
            int lock = pthread_mutex_trylock(&_lock);
            if(self.videoURL){
                [self.failedURLs addObject:self.videoURL];
            }
            if (!lock) {
                pthread_mutex_unlock(&_lock);
            }
        }
        [self reset];
    }
    else {
        if ((self.playerOptions & JPVideoPlayerRetryFailed)) {
            int lock = pthread_mutex_trylock(&_lock);
            if ([self.failedURLs containsObject:self.videoURL]) {
                [self.failedURLs removeObject:self.videoURL];
            }
            if (!lock) {
                pthread_mutex_unlock(&_lock);
            }
        }
    }
}


#pragma mark - JPApplicationStateMonitorDelegate

- (void)applicationStateMonitor:(JPApplicationStateMonitor *)monitor
      applicationStateDidChange:(JPApplicationState)applicationState {
    BOOL needReturn = !self.videoURL ||
            self.videoPlayer.playerStatus == JPVideoPlayerStatusStop ||
            self.videoPlayer.playerStatus == JPVideoPlayerStatusPause ||
            self.videoPlayer.playerStatus == JPVideoPlayerStatusFailed;

    if(applicationState == JPApplicationStateWillResignActive){
        self.isReturnWhenApplicationWillResignActive = needReturn;
        if(needReturn){
            return;
        }
        if (self.delegate && [self.delegate respondsToSelector:@selector(videoPlayerManager:shouldPausePlaybackWhenApplicationWillResignActiveForURL:)]) {
            BOOL needPause = [self.delegate videoPlayerManager:self
            shouldPausePlaybackWhenApplicationWillResignActiveForURL:self.videoURL];
            if(needPause){
                [self.videoPlayer pause];
            }
            return;
        }

        [self.videoPlayer pause];
    }
    else if(applicationState == JPApplicationStateDidEnterBackground){
        self.isReturnWhenApplicationDidEnterBackground = needReturn;
        if(needReturn){
            return;
        }
        if (self.delegate && [self.delegate respondsToSelector:@selector(videoPlayerManager:shouldPausePlaybackWhenApplicationDidEnterBackgroundForURL:)]) {
            BOOL needPause = [self.delegate videoPlayerManager:self
      shouldPausePlaybackWhenApplicationDidEnterBackgroundForURL:self.videoURL];
            if(needPause){
                [self.videoPlayer pause];
            }
            return;
        }

        [self.videoPlayer pause];
    }
}

- (void)applicationDidBecomeActiveFromBackground:(JPApplicationStateMonitor *)monitor {
    if(self.isReturnWhenApplicationDidEnterBackground){
        return;
    }

    if (self.delegate && [self.delegate respondsToSelector:@selector(videoPlayerManager:shouldResumePlaybackWhenApplicationDidBecomeActiveFromBackgroundForURL:)]) {
        BOOL needResume = [self.delegate videoPlayerManager:self
       shouldResumePlaybackWhenApplicationDidBecomeActiveFromBackgroundForURL:self.videoURL];
        if(needResume){
            [self.videoPlayer resume];
        }
        return;
    }

    [self.videoPlayer resume];
}

- (void)applicationDidBecomeActiveFromResignActive:(JPApplicationStateMonitor *)monitor {
    if(self.isReturnWhenApplicationWillResignActive){
        return;
    }

    if (self.delegate && [self.delegate respondsToSelector:@selector(videoPlayerManager:shouldResumePlaybackWhenApplicationDidBecomeActiveFromResignActiveForURL:)]) {
        BOOL needResume = [self.delegate videoPlayerManager:self
shouldResumePlaybackWhenApplicationDidBecomeActiveFromResignActiveForURL:self.videoURL];
        if(needResume){
            [self.videoPlayer resume];
        }
        return;
    }

    [self.videoPlayer resume];
}

// TODO: 列表中点击 cell 视频连贯播放.


#pragma mark - Private

- (long long)fetchFileSizeAtPath:(NSString *)filePath{
    NSFileManager* manager = [NSFileManager defaultManager];
    if ([manager fileExistsAtPath:filePath]){
        return [[manager attributesOfItemAtPath:filePath error:nil] fileSize];
    }
    return 0;
}

- (void)reset {
    int lock = pthread_mutex_trylock(&_lock);
    self.videoURL = nil;
    self.playerOptions = 0;
    if (!lock) {
        pthread_mutex_unlock(&_lock);
    }
}

- (JPVideoPlayerDownloaderOptions)fetchDownloadOptionsWithOptions:(JPVideoPlayerOptions)options {
    // download if no cache, and download allowed by delegate.
    JPVideoPlayerDownloaderOptions downloadOptions = 0;
    if (options & JPVideoPlayerContinueInBackground)
        downloadOptions |= JPVideoPlayerDownloaderContinueInBackground;
    if (options & JPVideoPlayerHandleCookies)
        downloadOptions |= JPVideoPlayerDownloaderHandleCookies;
    if (options & JPVideoPlayerAllowInvalidSSLCertificates)
        downloadOptions |= JPVideoPlayerDownloaderAllowInvalidSSLCertificates;
    return downloadOptions;
}

- (void)callVideoLengthDelegateMethodWithVideoLength:(NSUInteger)videoLength {
    JPDispatchSyncOnMainQueue(^{
        if([self.delegate respondsToSelector:@selector(videoPlayerManager:didFetchVideoFileLength:)]){
            [self.delegate videoPlayerManager:self
                      didFetchVideoFileLength:videoLength];
        }
    });
}

- (void)callDownloadDelegateMethodWithFragmentRanges:(NSArray<NSValue *> *)fragmentRanges
                                        expectedSize:(NSUInteger)expectedSize
                                           cacheType:(JPVideoPlayerCacheType)cacheType
                                               error:(nullable NSError *)error {
    JPDispatchSyncOnMainQueue(^{
        if (self.delegate && [self.delegate respondsToSelector:@selector(videoPlayerManagerDownloadProgressDidChange:cacheType:fragmentRanges:expectedSize:error:)]) {
            [self.delegate videoPlayerManagerDownloadProgressDidChange:self
                                                             cacheType:cacheType
                                                        fragmentRanges:fragmentRanges
                                                          expectedSize:expectedSize
                                                                 error:error];
        }
    });
}

- (void)callPlayDelegateMethodWithElapsedSeconds:(double)elapsedSeconds
                                    totalSeconds:(double)totalSeconds
                                           error:(nullable NSError *)error {
    JPDispatchSyncOnMainQueue(^{
        if (self.delegate && [self.delegate respondsToSelector:@selector(videoPlayerManagerPlayProgressDidChange:elapsedSeconds:totalSeconds:error:)]) {
            [self.delegate videoPlayerManagerPlayProgressDidChange:self
                                                    elapsedSeconds:elapsedSeconds
                                                      totalSeconds:totalSeconds
                                                             error:error];
        }
    });
}


#pragma mark - Play Video

- (void)playFragmentVideoWithURL:(NSURL *)url
                         options:(JPVideoPlayerOptions)options
                       showLayer:(CALayer *)showLayer
             configFinishedBlock:(JPPlayVideoConfigFinishedBlock)configFinishedBlock{
    JPVideoPlayerModel *model = [self.videoPlayer playVideoWithURL:url
                                                           options:options
                                                         showLayer:showLayer
                                               configFinishedBlock:configFinishedBlock];
    [self callVideoLengthDelegateMethodWithVideoLength:model.resourceLoader.cacheFile.fileLength];
    [self callDownloadDelegateMethodWithFragmentRanges:model.resourceLoader.cacheFile.fragmentRanges
                                          expectedSize:model.resourceLoader.cacheFile.fileLength
                                             cacheType:JPVideoPlayerCacheTypeFragment
                                                 error:nil];
}

- (void)playExistedVideoWithShowLayer:(CALayer *)showLayer
                                  url:(NSURL *)url
                            videoPath:(NSString *)videoPath
                              options:(JPVideoPlayerOptions)options
                            cacheType:(JPVideoPlayerCacheType)cacheType
                  configFinishedBlock:(JPPlayVideoConfigFinishedBlock)configFinishedBlock{
    JPDebugLog(@"Start play a existed video: %@", url);
    NSUInteger videoLength = [self fetchFileSizeAtPath:videoPath];
    [self callVideoLengthDelegateMethodWithVideoLength:videoLength];
    [self callDownloadDelegateMethodWithFragmentRanges:@[[NSValue valueWithRange:NSMakeRange(0, videoLength)]]
                                          expectedSize:videoLength
                                             cacheType:JPVideoPlayerCacheTypeFull
                                                 error:nil];
    [self.videoPlayer playExistedVideoWithURL:url
                           fullVideoCachePath:videoPath
                                      options:options
                                  showOnLayer:showLayer
                          configFinishedBlock:configFinishedBlock];
}

- (void)playLocalVideoWithShowLayer:(CALayer *)showLayer
                                url:(NSURL *)url
                            options:(JPVideoPlayerOptions)options
                configFinishedBlock:(JPPlayVideoConfigFinishedBlock)configFinishedBlock {
    JPDebugLog(@"Start play a local video: %@", url);
    // local file.
    NSString *path = [url.absoluteString stringByReplacingOccurrencesOfString:@"file://" withString:@""];
    if ([[NSFileManager defaultManager] fileExistsAtPath:path]) {
        NSUInteger videoLength = [self fetchFileSizeAtPath:path];
        [self callVideoLengthDelegateMethodWithVideoLength:videoLength];
        [self callDownloadDelegateMethodWithFragmentRanges:@[[NSValue valueWithRange:NSMakeRange(0, videoLength)]]
                                              expectedSize:videoLength
                                                 cacheType:JPVideoPlayerCacheTypeLocation
                                                     error:nil];
        [self.videoPlayer playExistedVideoWithURL:url
                               fullVideoCachePath:path
                                          options:options
                                      showOnLayer:showLayer
                              configFinishedBlock:configFinishedBlock];
    }
    else{
        NSError *error = [NSError errorWithDomain:JPVideoPlayerErrorDomain
                                             code:NSURLErrorFileDoesNotExist
                                         userInfo:@{NSLocalizedDescriptionKey : @"The file of given URL not exists"}];
        [self callDownloadDelegateMethodWithFragmentRanges:nil
                                              expectedSize:1
                                                 cacheType:JPVideoPlayerCacheTypeNone
                                                     error:error];
    }
}

@end