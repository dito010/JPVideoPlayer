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

@interface JPVideoPlayerManager()<JPVideoPlayerInternalDelegate, JPVideoPlayerDownloaderDelegate>

@property (strong, nonatomic, readwrite, nonnull) JPVideoPlayerCache *videoCache;

@property (strong, nonatomic) JPVideoPlayerDownloader *videoDownloader;

@property (strong, nonatomic, nonnull) NSMutableSet<NSURL *> *failedURLs;

@property(nonatomic, strong) NSURL *url;

@property(nonatomic, assign)JPVideoPlayerOptions playerOptions;

@property(nonatomic, getter=isMuted) BOOL mute;

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

    self.url = url;
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

- (void)seekToTime:(CMTime)time {
    [self.videoPlayer seekToTime:time];
}

- (void)stopPlay {
    JPDispatchSyncOnMainQueue(^{
        [self.videoDownloader cancel];
        [self.videoPlayer stopPlay];
        [self reset];
    });
}

- (void)pause {
    [self.videoPlayer pause];
}

- (void)resume {
    [self.videoPlayer resume];
}

- (void)setPlayerMute:(BOOL)mute {
    if (self.videoPlayer.currentPlayerModel) {
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
            if(self.url){
                [self.failedURLs addObject:self.url];
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

- (long long)fetchFileSizeAtPath:(NSString *)filePath{
    NSFileManager* manager = [NSFileManager defaultManager];
    if ([manager fileExistsAtPath:filePath]){
        return [[manager attributesOfItemAtPath:filePath error:nil] fileSize];
    }
    return 0;
}

- (void)reset {
    int lock = pthread_mutex_trylock(&_lock);
    self.url = nil;
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
//                                     if (!self.videoPlayer.currentPlayerModel) {
//#pragma clang diagnostic push
//#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
//                                         // display backLayer.
//                                         [sShowView performSelector:NSSelectorFromString(@"displayBackLayer")];
//#pragma clang diagnostic pop
//                                     }
//                                     NSString *key = [[JPVideoPlayerManager sharedManager] cacheKeyForURL:url];
//                                     if (self.videoPlayer.currentPlayerModel && [key isEqualToString:self.videoPlayer.currentPlayerModel.playingKey]) {
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

- (void)hideAllIndicatorAndProgressViewsWithURL:(nullable NSURL *)url options:(JPVideoPlayerOptions)options{
    [self hideActivityViewWithURL:url options:options];
    [self hideProgressViewWithURL:url options:options];
}

- (void)hideActivityViewWithURL:(nullable NSURL *)url options:(JPVideoPlayerOptions)options{
}

- (void)hideProgressViewWithURL:(nullable NSURL *)url options:(JPVideoPlayerOptions)options{

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

- (void)diskVideoExistsForURL:(nullable NSURL *)url completion:(nullable JPVideoPlayerCheckCacheCompletion)completionBlock {
    NSString *key = [self cacheKeyForURL:url];
    [self.videoCache diskVideoExistsWithKey:key completion:^(BOOL isInDiskCache) {
        if (completionBlock) {
            completionBlock(isInDiskCache);
        }
    }];
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