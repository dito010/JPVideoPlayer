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
#import "JPVideoPlayerCachePathManager.h"
#import "JPVideoPlayer.h"
#import "JPVideoPlayerDownloaderOperation.h"
#import "UIView+WebVideoCacheOperation.h"
#import "UIView+PlayerStatusAndDownloadIndicator.h"
#import "UIView+WebVideoCache.h"
#import <pthread.h>

@interface JPVideoPlayerCombinedOperation : NSObject <JPVideoPlayerOperation>

@property (assign, nonatomic, getter = isCancelled) BOOL cancelled;

@property (copy, nonatomic, nullable) JPVideoPlayerNoParamsBlock cancelBlock;

@property (strong, nonatomic, nullable) NSOperation *cacheOperation;

/*
 * progressBlock.
 */
@property(nonatomic, copy, nonnull) JPVideoPlayerDownloaderProgressBlock progressBlock;

/*
 * completionBlock.
 */
@property(nonatomic, copy, nonnull) JPVideoPlayerCompletionBlock completionBlock;

/*
 * url.
 */
@property(nonatomic, strong, nonnull) NSURL *url;

/**
 * options
 */
@property(nonatomic, assign)JPVideoPlayerOptions playerOptions;

@end

@implementation JPVideoPlayerCombinedOperation

- (void)setCancelBlock:(nullable JPVideoPlayerNoParamsBlock)cancelBlock {
    // check if the operation is already cancelled, then we just call the cancelBlock
    if (self.isCancelled) {
        if (cancelBlock) {
            cancelBlock();
        }
        _cancelBlock = nil; // don't forget to nil the cancelBlock, otherwise we will get crashes
    } else {
        _cancelBlock = [cancelBlock copy];
    }
}

- (void)cancel {
    self.cancelled = YES;
    if (self.cacheOperation) {
        [self.cacheOperation cancel];
        self.cacheOperation = nil;
    }
    if (self.cancelBlock) {
        self.cancelBlock();
        _cancelBlock = nil;
    }
}

@end


@interface JPVideoPlayerManager()<JPVideoPlayerInternalDelegate>

@property (strong, nonatomic, readwrite, nonnull) JPVideoPlayerCache *videoCache;

@property (strong, nonatomic) JPVideoPlayerDownloader *videoDownloader;

@property (strong, nonatomic, nonnull) NSMutableSet<NSURL *> *failedURLs;

@property (strong, nonatomic) JPVideoPlayerCombinedOperation *runningOperation;

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
    return [self initWithCache:cache downloader:downloader];
}

- (nonnull instancetype)initWithCache:(nonnull JPVideoPlayerCache *)cache downloader:(nonnull JPVideoPlayerDownloader *)downloader {
    if ((self = [super init])) {
        _videoCache = cache;
        _videoDownloader = downloader;
        _failedURLs = [NSMutableSet new];
        pthread_mutex_init(&(_lock), NULL);
        _videoPlayer = [JPVideoPlayer new];
        _videoPlayer.delegate = self;
    }
    return self;
}


#pragma mark - Public

+ (void)preferLogLevel:(JPLogLevel)logLevel {
    _logLevel = logLevel;
}

- (nullable id <JPVideoPlayerOperation>)playVideoWithURL:(nonnull NSURL *)url
                                              showOnView:(nonnull UIView *)showView
                                                 options:(JPVideoPlayerOptions)options
                                                progress:(JPVideoPlayerDownloaderProgressBlock)progressBlock
                                              completion:(nullable JPVideoPlayerCompletionBlock)completionBlock {
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
    
    __block JPVideoPlayerCombinedOperation *operation = [JPVideoPlayerCombinedOperation new];
    operation.progressBlock = progressBlock;
    operation.completionBlock = completionBlock;
    operation.url = url;
    operation.playerOptions = options;
    self.runningOperation = operation;
    self.showView = showView;
    __weak JPVideoPlayerCombinedOperation *weakOperation = operation;
    __weak typeof(showView) wShowView = showView;
    
    BOOL isFailedUrl = NO;
    if (url) {
        pthread_mutex_lock(&_lock);
        isFailedUrl = [self.failedURLs containsObject:url];
        pthread_mutex_unlock(&_lock);
    }
    
    if (url.absoluteString.length == 0 || (!(options & JPVideoPlayerRetryFailed) && isFailedUrl)) {
        [self callCompletionBlockWithCompletion:completionBlock
                                      videoPath:nil
                                          error:[NSError errorWithDomain:JPVideoPlayerErrorDomain code:NSURLErrorFileDoesNotExist userInfo:@{NSLocalizedDescriptionKey : @"the file of given URL not exists"}]
                                      cacheType:JPVideoPlayerCacheTypeNone
                                            url:url];
        return operation;
    }
    
    NSString *key = [self cacheKeyForURL:url];
    BOOL isFileURL = [url isFileURL];
    if (isFileURL) {
        // play file URL.
        [self playLocalVideoWithShowView:showView
                                     url:url
                                 options:options
                               operation:operation
                         completionBlock:completionBlock];
        return operation;
    }
    else {
        operation.cacheOperation = [self.videoCache queryCacheOperationForKey:key done:^(NSString * _Nullable videoPath, JPVideoPlayerCacheType cacheType) {
            
            __strong __typeof(weakOperation) strongOperation = weakOperation;
            __strong __typeof(wShowView) sShowView = wShowView;
            if (!strongOperation || !sShowView) {
                self.runningOperation = nil;
                return;
            }
            
            if (operation.isCancelled) {
                self.runningOperation = nil;
                return;
            }
            
            if (!videoPath && (![self.delegate respondsToSelector:@selector(videoPlayerManager:shouldDownloadVideoForURL:)] || [self.delegate videoPlayerManager:self shouldDownloadVideoForURL:url])) {
                // play web video.
                [self playWebVideoWithShowView:wShowView
                                           url:url
                                       options:options
                                     operation:operation
                                      progress:progressBlock
                               completionBlock:completionBlock
                                     cacheType:cacheType];
            }
            else if(videoPath){
                if (cacheType != JPVideoPlayerCacheTypeDisk) {
                    return;
                }
                
                // full video cache file in disk.
                [self playExistedVideoWithShowView:wShowView
                                               url:url
                                         videoPath:videoPath
                                           options:options
                                         operation:weakOperation
                                   completionBlock:completionBlock
                                         cacheType:cacheType];
                
            }
            else {
                // video not in cache and download disallowed by delegate.
                [self callCompletionBlockWithCompletion:completionBlock
                                              videoPath:nil
                                                  error:nil
                                              cacheType:JPVideoPlayerCacheTypeNone
                                                    url:url];
                self.runningOperation = nil;
            }
        }];
    }
    return operation;
}

- (void)playWebVideoWithShowView:(UIView *)showView
                             url:(NSURL *)url
                         options:(JPVideoPlayerOptions)options
                       operation:(JPVideoPlayerCombinedOperation *)operation
                        progress:(JPVideoPlayerDownloaderProgressBlock)progressBlock
                 completionBlock:(JPVideoPlayerCompletionBlock)completionBlock
                       cacheType:(JPVideoPlayerCacheType)cacheType {
    // show progress view if need.
    [self tryToShowProgressViewForView:showView options:options];
    // show activity view if need.
    [self tryToShowActivityIndicatorViewForView:showView options:options];
    [self downloadProgressDidChangeWithURL:url options:options receiveSize:0 exceptSize:1];
    
    __weak __typeof(showView) wshowView = showView;
    JPVideoPlayerDownloaderOptions downloaderOptions = [self fetchDownloadOptionsWithOptions:self.runningOperation.playerOptions];
    [self.videoDownloader tryToFetchVideoExpectedSizeWithURL:[NSURL URLWithString:@"http://static.smartisanos.cn/common/video/proud-driver.mp4"] options:downloaderOptions completion:^(NSURL * _Nonnull url, NSUInteger expectedSize, NSError * _Nullable error) {

        [self.videoCache storeExpectedSize:expectedSize forKey:[self cacheKeyForURL:url] completion:^(NSString * _Nonnull key, NSUInteger expectedSize, NSError * _Nonnull error) {
    
            [self.videoPlayer playVideoWithURL:url
                                       options:options
                                    showOnView:showView
                                      progress:^(double currentSeconds, double totalSeconds) {
                                          
                                          __strong __typeof(wshowView) sShowView = wshowView;
                                          double progress = currentSeconds / totalSeconds;
                                          BOOL needDisplayProgress = options & JPVideoPlayerShowProgressView;
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
                                          if (needDisplayProgress) {
                                              [sShowView performSelector:NSSelectorFromString(@"jp_progressViewPlayingStatusChangedWithProgressValue:") withObject:@(progress)];
                                          }
#pragma clang diagnostic pop
                                          
                                          
                                      } error:^(NSError * _Nullable error) {
                                          
                                          if (error) {
                                              if (completionBlock) {
                                                  [self callCompletionBlockWithCompletion:completionBlock
                                                                                videoPath:nil
                                                                                    error:error
                                                                                cacheType:JPVideoPlayerCacheTypeNone
                                                                                      url:url];
                                                  self.runningOperation = nil;
                                              }
                                          }
                                          
                                      }];
            
        }];

    }];
}

- (void)playExistedVideoWithShowView:(UIView *)showView
                                 url:(NSURL *)url
                           videoPath:(NSString *)videoPath
                             options:(JPVideoPlayerOptions)options
                           operation:(JPVideoPlayerCombinedOperation *)operation
                     completionBlock:(JPVideoPlayerCompletionBlock)completionBlock
                           cacheType:(JPVideoPlayerCacheType)cacheType {
    // show progress view if need.
    [self tryToShowProgressViewForView:showView options:options];
    [self downloadProgressDidChangeWithURL:url options:options receiveSize:1 exceptSize:1];
    
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
    [showView performSelector:NSSelectorFromString(@"jp_progressViewDownloadingStatusChangedWithProgressValue:") withObject:@1];
    // display backLayer.
    [showView performSelector:NSSelectorFromString(@"displayBackLayer")];
#pragma clang diagnostic pop
    
    [self.videoPlayer playExistedVideoWithURL:url
                           fullVideoCachePath:videoPath
                                      options:options
                                   showOnView:showView
                                     progress:^(double currentSeconds, double totalSeconds) {
                                         double progress = currentSeconds / totalSeconds;
                                         BOOL needDisplayProgressView = options & JPVideoPlayerShowProgressView;
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
                                         if (needDisplayProgressView) {
                                             [showView performSelector:NSSelectorFromString(@"jp_progressViewPlayingStatusChangedWithProgressValue:") withObject:@(progress)];
                                         }
#pragma clang diagnostic pop
                                         
                                     } error:^(NSError * _Nullable error) {
                                         
                                         if (completionBlock) {
                                             completionBlock(nil, error, JPVideoPlayerCacheTypeLocation, url);
                                         }
                                         
                                     }];
    
    [self callCompletionBlockWithCompletion:completionBlock
                                  videoPath:videoPath
                                      error:nil
                                  cacheType:JPVideoPlayerCacheTypeDisk
                                        url:url];
}

- (void)playLocalVideoWithShowView:(UIView *)showView
                               url:(NSURL *)url
                           options:(JPVideoPlayerOptions)options
                         operation:(JPVideoPlayerCombinedOperation *)operation
                   completionBlock:(JPVideoPlayerCompletionBlock)completionBlock {
    // local file.
    NSString *path = [url.absoluteString stringByReplacingOccurrencesOfString:@"file://" withString:@""];
    if ([[NSFileManager defaultManager] fileExistsAtPath:path]) {
        // show progress view if need.
        [self tryToShowProgressViewForView:showView options:options];
        [self downloadProgressDidChangeWithURL:url options:options receiveSize:1 exceptSize:1];
        
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
                                       showOnView:showView
                                         progress:^(double currentSeconds, double totalSeconds) {
                                             double progress = currentSeconds / totalSeconds;
                                             
                                             __strong typeof(wShowView) sShowView = wShowView;
                                             if (!sShowView) return;
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
                                             BOOL needDisplayProgressView = options & JPVideoPlayerShowProgressView;
                                             if (needDisplayProgressView) {
                                                 [sShowView performSelector:NSSelectorFromString(@"jp_progressViewPlayingStatusChangedWithProgressValue:") withObject:@(progress)];
                                             }
#pragma clang diagnostic pop
                                             
                                         } error:^(NSError * _Nullable error) {
                                             
                                             if (completionBlock) {
                                                 completionBlock(nil, error, JPVideoPlayerCacheTypeLocation, url);
                                             }
                                             
                                         }];
        self.videoPlayer.delegate = self;
    }
    else{
        [self callCompletionBlockWithCompletion:completionBlock
                                      videoPath:nil
                                          error:[NSError errorWithDomain:JPVideoPlayerErrorDomain code:NSURLErrorFileDoesNotExist userInfo:@{NSLocalizedDescriptionKey : @"the file of given URL not exists"}]
                                      cacheType:JPVideoPlayerCacheTypeNone
                                            url:url];
    }
}


- (void)cancelAllDownloads{
    [self.videoDownloader cancel];
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
    dispatch_main_async_safe(^{
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

- (BOOL)videoPlayer:(JPVideoPlayer *)videoPlayer shouldAutoReplayVideoForURL:(NSURL *)videoURL {
    if (self.delegate && [self.delegate respondsToSelector:@selector(videoPlayerManager:shouldAutoReplayForURL:)]) {
        return [self.delegate videoPlayerManager:self shouldAutoReplayForURL:videoURL];
    }
    return YES;
}

- (void)videoPlayer:(JPVideoPlayer *)videoPlayer playStatusDidChange:(JPVideoPlayerStatus)playingStatus {
    if (self.delegate && [self.delegate respondsToSelector:@selector(videoPlayerManager:playingStatusDidChanged:)]) {
        [self.delegate videoPlayerManager:self playingStatusDidChanged:playingStatus];
    }
}

- (void)videoPlayer:(JPVideoPlayer *)videoPlayer playerRequestRangeDidChange:(NSString *)requestRangeString {
    [self.videoCache reset];
    [self.videoDownloader cancel];
    [self.videoDownloader setValue:requestRangeString forHTTPHeaderField:@"Range"];
    [self startDownloadVideo];
}


#pragma mark - Private

- (void)startDownloadVideo {
    JPVideoPlayerOptions options = self.runningOperation.playerOptions;
    JPVideoPlayerDownloaderOptions downloaderOptions = [self fetchDownloadOptionsWithOptions:options];
    // Save received data to disk.
    JPVideoPlayerDownloaderProgressBlock handleProgressBlock = ^(NSData * _Nullable data,
            NSUInteger receivedSize,
            NSUInteger expectedSize,
            NSURLResponse *response,
            NSURL * _Nullable url){

        NSParameterAssert(self.runningOperation);
        [self storeVideoData:data
                expectedSize:expectedSize
                         url:self.runningOperation.url
                    showView:self.showView
                   operation:self.runningOperation
                     options:options
                    response:response
                    progress:self.runningOperation.progressBlock
                  completion:self.runningOperation.completionBlock];

    };
    
    
    // download video from web.
    [self.videoDownloader downloadVideoWithURL:[NSURL URLWithString:@"http://static.smartisanos.cn/common/video/proud-driver.mp4"]
                                       options:downloaderOptions
                                      progress:handleProgressBlock
                                    completion:^(NSError * _Nullable error) {
        
        if (error){
            [self callCompletionBlockWithCompletion:self.runningOperation.completionBlock
                                          videoPath:nil
                                              error:error
                                          cacheType:JPVideoPlayerCacheTypeNone
                                                url:self.runningOperation.url];
            
            if (error.code != NSURLErrorNotConnectedToInternet
                && error.code != NSURLErrorCancelled
                && error.code != NSURLErrorTimedOut
                && error.code != NSURLErrorInternationalRoamingOff
                && error.code != NSURLErrorDataNotAllowed
                && error.code != NSURLErrorCannotFindHost
                && error.code != NSURLErrorCannotConnectToHost) {
                pthread_mutex_lock(&_lock);
                [self.failedURLs addObject:self.runningOperation.url];
                pthread_mutex_unlock(&_lock);
            }
            
            self.runningOperation = nil;
        }
        else {
            if ((options & JPVideoPlayerRetryFailed)) {
                pthread_mutex_lock(&_lock);
                if ([self.failedURLs containsObject:self.runningOperation.url]) {
                    [self.failedURLs removeObject:self.runningOperation.url];
                }
                pthread_mutex_unlock(&_lock);
            }
        }
    }];
    
    __weak typeof(self) wself = self;
    self.runningOperation.cancelBlock = ^{
        __strong typeof(self) sself = wself;
        [sself.videoDownloader cancel];
        [[JPVideoPlayerManager sharedManager] stopPlay];
        
        // hide indicator view.
        [sself hideAllIndicatorAndProgressViewsWithURL:sself.runningOperation.url options:options];
        sself.runningOperation = nil;
    };
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
             operation:(JPVideoPlayerCombinedOperation *)operation
               options:(JPVideoPlayerOptions)options
              response:(NSURLResponse *)response
              progress:(JPVideoPlayerDownloaderProgressBlock)progressBlock
            completion:(JPVideoPlayerCompletionBlock)completionBlock {
    __weak __typeof(operation) wOperation = operation;
    __weak __typeof(showView) wshowView = showView;
    
    NSString *key = [[JPVideoPlayerManager sharedManager] cacheKeyForURL:url];
    [self.videoCache storeVideoData:videoData
                       expectedSize:expectedSize
                             forKey:key
                         completion:^(NSString *key, NSUInteger storedSize, NSString * _Nullable tempVideoCachePath, NSString * _Nullable fullVideoCachePath, NSError * _Nullable error) {
                             
                             __strong __typeof(wOperation) sOperation = wOperation;
                             __strong __typeof(wshowView) sShowView = wshowView;
                             if (!sOperation || sOperation.isCancelled) {
                                 // Do nothing if the operation was cancelled
                                 // if we would call the completedBlock, there could be a race condition between this block and another completedBlock for the same object, so if this one is called second, we will overwrite the new data.
                             }
                             if (!error) {
                                 // refresh progress view.
                                 [self downloadProgressDidChangeWithURL:url
                                                                options:options
                                                            receiveSize:storedSize
                                                             exceptSize:expectedSize];
                                 
                                 if (!fullVideoCachePath) {
                                     if (progressBlock) {
                                         progressBlock(videoData, storedSize, expectedSize, response, url);
                                     }
                                     if (!sShowView) return;
                                     
                                     // play video from web.
                                     if (!self.videoPlayer.currentVideoPlayerModel) {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
                                         // display backLayer.
                                         [sShowView performSelector:NSSelectorFromString(@"displayBackLayer")];
#pragma clang diagnostic pop
                                     }
                                     NSString *key = [[JPVideoPlayerManager sharedManager] cacheKeyForURL:url];
                                     if (self.videoPlayer.currentVideoPlayerModel && [key isEqualToString:self.videoPlayer.currentVideoPlayerModel.playingKey]) {
                                         [self.videoPlayer didReceivedDataCacheInDiskByTempPath:tempVideoCachePath
                                                                            videoFileExceptSize:expectedSize
                                                                          videoFileReceivedSize:storedSize];
                                     }
                                 }
                                 else{
                                     // cache finished, and move the full video file from temporary path to full path.
                                     [self.videoPlayer didCachedVideoDataFinishedFromWebFullVideoCachePath:fullVideoCachePath];
                                     [self callCompletionBlockWithCompletion:completionBlock
                                                                   videoPath:fullVideoCachePath
                                                                       error:nil
                                                                   cacheType:JPVideoPlayerCacheTypeWeb
                                                                         url:url];
                                     self.runningOperation = nil;
                                     
                                     if (self.delegate && [self.delegate respondsToSelector:@selector(videoPlayerManager:downloadProgressDidChangeReceivedSize:expectedSize:)]) {
                                         [self.delegate videoPlayerManager:self downloadProgressDidChangeReceivedSize:storedSize expectedSize:expectedSize];
                                     }
                                 }
                             }
                             else{
                                 // some error happens.
                                 [self callCompletionBlockWithCompletion:completionBlock
                                                               videoPath:nil
                                                                   error:error
                                                               cacheType:JPVideoPlayerCacheTypeNone
                                                                     url:url];
                                 
                                 // hide indicator view.
                                 [self hideAllIndicatorAndProgressViewsWithURL:url options:options];
                                 self.runningOperation = nil;
                             }
                         }];
}

- (void)tryToShowProgressViewForView:(UIView *)view
                             options:(JPVideoPlayerOptions)options{
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
    dispatch_main_async_safe(^{
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
    dispatch_main_async_safe(^{
        if ((options & JPVideoPlayerShowActivityIndicatorView)) {
            [view performSelector:NSSelectorFromString(@"jp_showActivityIndicatorView")];
        }
    });
#pragma clang diagnostic pop
}

- (void)playProgressDidChangeWithOptions:(JPVideoPlayerOptions)options
                          currentSeconds:(NSUInteger)currentSeconds
                            totalSeconds:(NSUInteger)totalSeconds {
    BOOL respond = self.delegate && [self.delegate respondsToSelector:@selector(videoPlayerManager:playProgressDidChangeCurrentSeconds:totalSeconds:)];
    if (respond) {
        [self.delegate videoPlayerManager:self playProgressDidChangeCurrentSeconds:currentSeconds totalSeconds:totalSeconds];
    }
}

- (void)downloadProgressDidChangeWithURL:(nullable NSURL *)url
                                 options:(JPVideoPlayerOptions)options
                             receiveSize:(NSUInteger)receiveSize
                              exceptSize:(NSUInteger)expectedSize {
    if (self.delegate && [self.delegate respondsToSelector:@selector(videoPlayerManager:downloadProgressDidChangeReceivedSize:expectedSize:)]) {
        [self.delegate videoPlayerManager:self
    downloadProgressDidChangeReceivedSize:receiveSize
                             expectedSize:expectedSize];
    }
    
    if (options & JPVideoPlayerShowProgressView) {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
        dispatch_main_async_safe(^{
            SEL sel = NSSelectorFromString(@"jp_progressViewDownloadingStatusChangedWithProgressValue:");
            if (self.showView) {
                [self.showView performSelector:sel withObject:@((CGFloat)receiveSize/expectedSize)];
            }
        });
#pragma clang diagnostic pop
    }
}

- (void)hideAllIndicatorAndProgressViewsWithURL:(nullable NSURL *)url options:(JPVideoPlayerOptions)options{
    [self hideActivityViewWithURL:url options:options];
    [self hideProgressViewWithURL:url options:options];
}

- (void)hideActivityViewWithURL:(nullable NSURL *)url options:(JPVideoPlayerOptions)options{
    if (options & JPVideoPlayerShowActivityIndicatorView){
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
        dispatch_main_async_safe(^{
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
        dispatch_main_async_safe(^{
            if (self.showView) {
                [self.showView performSelector:NSSelectorFromString(@"jp_hideProgressView")];
            }
        });
    }
#pragma clang diagnostic pop
}

- (void)callCompletionBlockWithCompletion:(nullable JPVideoPlayerCompletionBlock)completionBlock
                                videoPath:(nullable NSString *)videoPath
                                    error:(nullable NSError *)error
                                cacheType:(JPVideoPlayerCacheType)cacheType
                                      url:(nullable NSURL *)url {
    dispatch_main_async_safe(^{
        if (self.runningOperation && !self.runningOperation.isCancelled && completionBlock) {
            completionBlock(videoPath, error, cacheType, url);
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
 
- (void)setRunningOperation:(JPVideoPlayerCombinedOperation *)runningOperation {
    if (runningOperation == nil) {
        return;
    }
    _runningOperation = runningOperation;
}

@end
