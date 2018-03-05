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


@interface JPVideoPlayerManager()<JPVideoPlayerInternalDelegate, JPVideoPlayerDownloaderDelegate>

@property (strong, nonatomic, readwrite, nonnull) JPVideoPlayerCache *videoCache;

@property (strong, nonatomic) JPVideoPlayerDownloader *videoDownloader;

@property (strong, nonatomic, nonnull) NSMutableSet<NSURL *> *failedURLs;

/*
 * url.
 */
@property(nonatomic, strong) NSURL *url;

/**
 * options
 */
@property(nonatomic, assign)JPVideoPlayerOptions playerOptions;

@property(nonatomic, getter=isMuted) BOOL mute;

/*
 * showView.
 */
@property(nonatomic, weak) UIView *showView;

/*
 * player.
 */
@property(nonatomic, strong, nonnull) JPVideoPlayer *videoPlayer;


@property (nonatomic) pthread_mutex_t lock;

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

- (nonnull instancetype)initWithCache:(nonnull JPVideoPlayerCache *)cache downloader:(nonnull JPVideoPlayerDownloader *)downloader {
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
    }
    return self;
}


#pragma mark - Public

+ (void)preferLogLevel:(JPLogLevel)logLevel {
    _logLevel = logLevel;
}

- (void)playVideoWithURL:(NSURL *)url
              showOnView:(UIView *)showView
                 options:(JPVideoPlayerOptions)options {
    NSParameterAssert([[NSThread currentThread] isMainThread]);
    
    // Very common mistake is to send the URL using NSString object instead of NSURL. For some strange reason, XCode won't
    // throw any warning for this type mismatch. Here we failsafe this error by allowing URLs to be passed as NSString.
    if ([url isKindOfClass:NSString.class]) {
        url = [NSURL URLWithString:(NSString *)url];
    }
    
    // Prevents app crashing on argument type error like sending NSNull instead of NSURL
    if (![url isKindOfClass:NSURL.class]) {
        url = nil;
    }

    self.url = url;
    self.playerOptions = options;
    self.showView = showView;
    __weak typeof(showView) wShowView = showView;
    
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
        [self callDownloadDelegateMethodWithReceivedSize:0
                                            expectedSize:1
                                               cacheType:JPVideoPlayerCacheTypeNone
                                                   error:error];
        return;
    }
    
    NSString *key = [self cacheKeyForURL:url];
    BOOL isFileURL = [url isFileURL];
    if (isFileURL) {
        // play file URL.
        [self playLocalVideoWithShowView:showView
                                     url:url
                                 options:options];
        return;
    }
    else {
        [self.videoCache queryCacheOperationForKey:key done:^(NSString * _Nullable videoPath, JPVideoPlayerCacheType cacheType) {
            __strong __typeof(wShowView) sShowView = wShowView;
            if (!sShowView) {
                [self reset];
                return;
            }
            
            if (!videoPath && (![self.delegate respondsToSelector:@selector(videoPlayerManager:shouldDownloadVideoForURL:)] || [self.delegate videoPlayerManager:self shouldDownloadVideoForURL:url])) {
                // play web video.
                [self playWebVideoWithShowView:wShowView
                                           url:url
                                       options:options
                                     cacheType:cacheType];
            }
            else if(videoPath){
                // full video cache file in disk.
                [self playExistedVideoWithShowView:wShowView
                                               url:url
                                         videoPath:videoPath
                                           options:options
                                         cacheType:cacheType];
                
            }
            else {
                // video not in cache and download disallowed by delegate.
                NSError *error = [NSError errorWithDomain:JPVideoPlayerErrorDomain
                                                     code:NSURLErrorFileDoesNotExist
                                                 userInfo:@{NSLocalizedDescriptionKey : @"Video not in cache and download disallowed by delegate"}];
                [self callDownloadDelegateMethodWithReceivedSize:0
                                                    expectedSize:1
                                                       cacheType:JPVideoPlayerCacheTypeNone
                                                           error:error];
                [self reset];
            }
        }];
    }
}

- (void)playWebVideoWithShowView:(UIView *)showView
                             url:(NSURL *)url
                         options:(JPVideoPlayerOptions)options
                       cacheType:(JPVideoPlayerCacheType)cacheType {
    JPDebugLog(@"Start play a web video: %@", url);
    // show progress view if need.
    [self tryToShowProgressViewForView:showView options:options];
    // show activity view if need.
    [self tryToShowActivityIndicatorViewForView:showView options:options];
    [self.videoPlayer playVideoWithURL:url options:options showOnView:showView];
}

- (void)playExistedVideoWithShowView:(UIView *)showView
                                 url:(NSURL *)url
                           videoPath:(NSString *)videoPath
                             options:(JPVideoPlayerOptions)options
                           cacheType:(JPVideoPlayerCacheType)cacheType {
    JPDebugLog(@"Start play a existed video: %@", url);
    // show progress view if need.
    [self tryToShowProgressViewForView:showView options:options];
    [self callDownloadDelegateMethodWithReceivedSize:1
                                        expectedSize:1
                                           cacheType:JPVideoPlayerCacheTypeDisk
                                               error:nil];
    
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
    [showView performSelector:NSSelectorFromString(@"jp_progressViewDownloadingStatusChangedWithProgressValue:") withObject:@1];
    // display backLayer.
    [showView performSelector:NSSelectorFromString(@"displayBackLayer")];
#pragma clang diagnostic pop

    [self.videoPlayer playExistedVideoWithURL:url
                           fullVideoCachePath:videoPath
                                      options:options
                                   showOnView:showView];
}

- (void)playLocalVideoWithShowView:(UIView *)showView
                               url:(NSURL *)url
                           options:(JPVideoPlayerOptions)options {
    JPDebugLog(@"Start play a local video: %@", url);
    // local file.
    NSString *path = [url.absoluteString stringByReplacingOccurrencesOfString:@"file://" withString:@""];
    if ([[NSFileManager defaultManager] fileExistsAtPath:path]) {
        // show progress view if need.
        [self tryToShowProgressViewForView:showView options:options];
        [self callDownloadDelegateMethodWithReceivedSize:1
                                            expectedSize:1
                                               cacheType:JPVideoPlayerCacheTypeLocation
                                                   error:nil];
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
        [showView performSelector:NSSelectorFromString(@"jp_progressViewDownloadingStatusChangedWithProgressValue:") withObject:@1];
        
        // display backLayer.
        [showView performSelector:NSSelectorFromString(@"displayBackLayer")];
#pragma clang diagnostic pop
        
        __weak typeof(showView) wShowView = showView;
        [self.videoPlayer playExistedVideoWithURL:url
                               fullVideoCachePath:path
                                          options:options
                                       showOnView:showView];
    }
    else{
        NSError *error = [NSError errorWithDomain:JPVideoPlayerErrorDomain
                                             code:NSURLErrorFileDoesNotExist
                                         userInfo:@{NSLocalizedDescriptionKey : @"The file of given URL not exists"}];
        [self callDownloadDelegateMethodWithReceivedSize:0
                                            expectedSize:1
                                               cacheType:JPVideoPlayerCacheTypeNone
                                                   error:error];
    }
}

- (nullable NSString *)cacheKeyForURL:(nullable NSURL *)url {
    if (!url) {
        return @"";
    }
    //#pragma clang diagnostic push
    //#pragma clang diagnostic ignored "-Wdeprecated-declarations"
    //    url = [[NSURL alloc] initWithScheme:url.scheme host:url.host path:url.path];
    //#pragma clang diagnostic pop
    return [url absoluteString];
}

- (void)stopPlay{
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
    JPDispatchSyncOnMainQueue(^{
        if (self.showView) {
            [self.showView performSelector:NSSelectorFromString(@"jp_removeVideoLayerViewAndIndicatorView")];
            [self.showView performSelector:NSSelectorFromString(@"jp_hideActivityIndicatorView")];
            [self.showView performSelector:NSSelectorFromString(@"jp_hideProgressView")];
            self.showView.currentPlayingURL = nil;
            self.showView = nil;
        }
        
        [self.videoPlayer stopPlay];
    });
#pragma clang diagnostic pop
    [self reset];
}

- (void)pause{
    [self.videoPlayer pause];
}

- (void)resume{
    [self.videoPlayer resume];
}

- (void)setPlayerMute:(BOOL)mute{
    if (self.videoPlayer.currentVideoPlayerModel) {
        [self.videoPlayer setMute:mute];
    }
    self.mute = mute;
}

- (BOOL)playerIsMute{
    return self.mute;
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
    BOOL needDisplayProgressView = self.playerOptions & JPVideoPlayerShowProgressView;
    if (needDisplayProgressView) {
        double progress = 0;
        if(totalSeconds != 0){
           progress = elapsedSeconds / totalSeconds;
        }
        [self.showView performSelector:NSSelectorFromString(@"jp_progressViewPlayingStatusChangedWithProgressValue:") withObject:@(progress)];
    }

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
}

- (void)downloader:(JPVideoPlayerDownloader *)downloader
    didReceiveData:(NSData *)data
      receivedSize:(NSUInteger)receivedSize
      expectedSize:(NSUInteger)expectedSize {
//    [self storeVideoData:data
//            expectedSize:expectedSize
//                     url:self.runningOperation.url
//                showView:self.showView
//               operation:self.runningOperation
//                 options:options
//                response:response];
}

- (void)downloader:(JPVideoPlayerDownloader *)downloader
didCompleteWithError:(NSError *)error {
    if (error){
        [self callDownloadDelegateMethodWithReceivedSize:0
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
            [self.failedURLs addObject:self.url];
            if (!lock) {
                pthread_mutex_unlock(&_lock);
            }
        }
        [self reset];
    }
    else {
        if ((self.playerOptions & JPVideoPlayerRetryFailed)) {
            int lock = pthread_mutex_trylock(&_lock);
            if ([self.failedURLs containsObject:self.url]) {
                [self.failedURLs removeObject:self.url];
            }
            if (!lock) {
                pthread_mutex_unlock(&_lock);
            }
        }
    }
}


#pragma mark - Private

- (void)reset {
    int lock = pthread_mutex_trylock(&_lock);
    self.url = nil;
    self.playerOptions = 0;
    self.showView = nil;
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

- (void)storeVideoData:(NSData *)videoData
          expectedSize:(NSUInteger)expectedSize
                   url:(NSURL *)url
              showView:(UIView *)showView
               options:(JPVideoPlayerOptions)options
              response:(NSURLResponse *)response {
    __weak __typeof(showView) wshowView = showView;
    
    NSString *key = [[JPVideoPlayerManager sharedManager] cacheKeyForURL:url];
//    [self.videoCache storeVideoData:videoData
//                       expectedSize:expectedSize
//                             forKey:key
//                         completion:^(NSString *key, NSUInteger storedSize, NSString * _Nullable tempVideoCachePath, NSString * _Nullable fullVideoCachePath, NSError * _Nullable error) {
//                             // refresh progress view.
//                             [self callDownloadDelegateMethodWithReceivedSize:storedSize
//                                                                 expectedSize:expectedSize
//                                                                    cacheType:JPVideoPlayerCacheTypeWeb
//                                                                        error:nil];
//                             __strong __typeof(wshowView) sShowView = wshowView;
//                             if (!error) {
//                                 if (!fullVideoCachePath) {
//                                     if (!sShowView) {
//                                         [self reset];
//                                         return;
//                                     }
//
//                                     // play video from web.
//                                     if (!self.videoPlayer.currentVideoPlayerModel) {
//#pragma clang diagnostic push
//#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
//                                         // display backLayer.
//                                         [sShowView performSelector:NSSelectorFromString(@"displayBackLayer")];
//#pragma clang diagnostic pop
//                                     }
//                                     NSString *key = [[JPVideoPlayerManager sharedManager] cacheKeyForURL:url];
//                                     if (self.videoPlayer.currentVideoPlayerModel && [key isEqualToString:self.videoPlayer.currentVideoPlayerModel.playingKey]) {
//                                         [self.videoPlayer didReceivedDataCacheInDiskByTempPath:tempVideoCachePath
//                                                                            videoFileExceptSize:expectedSize
//                                                                          videoFileReceivedSize:storedSize];
//                                     }
//                                 }
//                                 else{
//                                     // cache finished, and move the full video file from temporary path to full path.
//                                     [self.videoPlayer didCachedVideoDataFinishedFromWebFullVideoCachePath:fullVideoCachePath];
//                                 }
//                             }
//                             else{
//                                 // some error happens.
//                                 // hide indicator view.
//                                 [self hideAllIndicatorAndProgressViewsWithURL:url options:options];
//                                 [self reset];
//                             }
//                         }];
}

- (void)tryToShowProgressViewForView:(UIView *)view
                             options:(JPVideoPlayerOptions)options{
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
    JPDispatchSyncOnMainQueue(^{
        if (options & JPVideoPlayerShowProgressView) {
            [view performSelector:NSSelectorFromString(@"jp_showProgressView")];
        }
    });
#pragma clang diagnostic pop
}

- (void)tryToShowActivityIndicatorViewForView:(UIView *)view
                                      options:(JPVideoPlayerOptions)options{
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
    JPDispatchSyncOnMainQueue(^{
        if ((options & JPVideoPlayerShowActivityIndicatorView)) {
            [view performSelector:NSSelectorFromString(@"jp_showActivityIndicatorView")];
        }
    });
#pragma clang diagnostic pop
}

- (void)hideAllIndicatorAndProgressViewsWithURL:(nullable NSURL *)url options:(JPVideoPlayerOptions)options{
    [self hideActivityViewWithURL:url options:options];
    [self hideProgressViewWithURL:url options:options];
}

- (void)hideActivityViewWithURL:(nullable NSURL *)url options:(JPVideoPlayerOptions)options{
    if (options & JPVideoPlayerShowActivityIndicatorView){
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
        JPDispatchSyncOnMainQueue(^{
            if (self.showView) {
                [self.showView performSelector:NSSelectorFromString(@"jp_hideActivityIndicatorView")];
            }
        });
#pragma clang diagnostic pop
    }
}

- (void)hideProgressViewWithURL:(nullable NSURL *)url options:(JPVideoPlayerOptions)options{
    if (options & JPVideoPlayerShowProgressView){
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
        JPDispatchSyncOnMainQueue(^{
            if (self.showView) {
                [self.showView performSelector:NSSelectorFromString(@"jp_hideProgressView")];
            }
        });
    }
#pragma clang diagnostic pop
}

- (void)callDownloadDelegateMethodWithReceivedSize:(NSUInteger)receivedSize
                                      expectedSize:(NSUInteger)expectedSize
                                         cacheType:(JPVideoPlayerCacheType)cacheType
                                             error:(nullable NSError *)error {
    JPDispatchSyncOnMainQueue(^{
        if (self.delegate && [self.delegate respondsToSelector:@selector(videoPlayerManagerDownloadProgressDidChange:cacheType:receivedSize:expectedSize:error:)]) {
            [self.delegate videoPlayerManagerDownloadProgressDidChange:self
                                                             cacheType:cacheType
                                                          receivedSize:receivedSize
                                                          expectedSize:expectedSize
                                                                 error:error];
        }

        if (self.playerOptions & JPVideoPlayerShowProgressView) {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
            JPDispatchSyncOnMainQueue(^{
                SEL sel = NSSelectorFromString(@"jp_progressViewDownloadingStatusChangedWithProgressValue:");
                if (self.showView) {
                    [self.showView performSelector:sel withObject:@((CGFloat)receivedSize/expectedSize)];
                }
            });
#pragma clang diagnostic pop
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

- (void)diskVideoExistsForURL:(nullable NSURL *)url completion:(nullable JPVideoPlayerCheckCacheCompletion)completionBlock {
    NSString *key = [self cacheKeyForURL:url];
    [self.videoCache diskVideoExistsWithKey:key completion:^(BOOL isInDiskCache) {
        if (completionBlock) {
            completionBlock(isInDiskCache);
        }
    }];
}

@end
