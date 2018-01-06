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

@property (strong, nonatomic, readwrite, nonnull) JPVideoPlayerDownloader *videoDownloader;

@property (strong, nonatomic, nonnull) NSMutableSet<NSURL *> *failedURLs;

@property (strong, nonatomic, nonnull) NSMutableArray<JPVideoPlayerCombinedOperation *> *runningOperations;

@property(nonatomic, getter=isMuted) BOOL mute;

@property (strong, nonatomic, nonnull) NSMutableArray<UIView *> *showViews;

/*
 * showView.
 */
@property(nonatomic, weak) UIView *showView;


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
        _runningOperations = [NSMutableArray array];
        _showViews = [NSMutableArray array];
        pthread_mutex_init(&(_lock), NULL);
    }
    return self;
}


#pragma mark - Public

- (nullable id <JPVideoPlayerOperation>)loadVideoWithURL:(nullable NSURL *)url showOnView:(nullable UIView *)showView options:(JPVideoPlayerOptions)options progress:(nullable JPVideoPlayerDownloaderProgressBlock)progressBlock completion:(nullable JPVideoPlayerCompletionBlock)completedBlock{
    
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
    __weak JPVideoPlayerCombinedOperation *weakOperation = operation;
    
    BOOL isFailedUrl = NO;
    if (url) {
        @synchronized (self.failedURLs) {
            isFailedUrl = [self.failedURLs containsObject:url];
        }
    }
    
    if (url.absoluteString.length == 0 || (!(options & JPVideoPlayerRetryFailed) && isFailedUrl)) {
        [self callCompletionBlockForOperation:operation completion:completedBlock videoPath:nil error:[NSError errorWithDomain:NSURLErrorDomain code:NSURLErrorFileDoesNotExist userInfo:nil] cacheType:JPVideoPlayerCacheTypeNone url:url];
        return operation;
    }
    
    @synchronized (self.runningOperations) {
        [self.runningOperations addObject:operation];
    }
    @synchronized (self.showViews) {
        [self.showViews addObject:showView];
    }
    
    NSString *key = [self cacheKeyForURL:url];
    
    BOOL isFileURL = [url isFileURL];
    
    // show progress view and activity indicator view if need.
    [self showProgressViewAndActivityIndicatorViewForView:showView options:options];
    
    __weak typeof(showView) wShowView = showView;
    if (isFileURL) {
#pragma mark - Local File
        // hide activity view.
        [self hideActivityViewWithURL:url options:options];
        
        // local file.
        NSString *path = [url.absoluteString stringByReplacingOccurrencesOfString:@"file://" withString:@""];
        if ([[NSFileManager defaultManager] fileExistsAtPath:path]) {
            
            BOOL needDisplayProgress = [self needDisplayDownloadingProgressViewWithDownloadingProgressValue:1.0];
            
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
            if (needDisplayProgress) {
                [showView performSelector:NSSelectorFromString(@"jp_progressViewDownloadingStatusChangedWithProgressValue:") withObject:@1];
            }
            
            // display backLayer.
            [showView performSelector:NSSelectorFromString(@"displayBackLayer")];
#pragma clang diagnostic pop
            
            [[JPVideoPlayer sharedManager] playExistedVideoWithURL:url fullVideoCachePath:path options:options showOnView:showView progress:^(double currentSeconds, double totalSeconds) {
                double progress = currentSeconds / totalSeconds;
                __strong typeof(wShowView) sShowView = wShowView;
                if (!sShowView) return;
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
                BOOL needDisplayProgress = [self needDisplayPlayingProgressViewWithPlayingProgressValue:progress];
                if (needDisplayProgress) {
                    [sShowView performSelector:NSSelectorFromString(@"jp_progressViewPlayingStatusChangedWithProgressValue:") withObject:@(progress)];
                }
#pragma clang diagnostic pop
            } error:^(NSError * _Nullable error) {
                if (completedBlock) {
                    completedBlock(nil, error, JPVideoPlayerCacheTypeLocation, url);
                }
            }];
            [JPVideoPlayer sharedManager].delegate = self;
        }
        else{
            [self callCompletionBlockForOperation:operation completion:completedBlock videoPath:nil error:[NSError errorWithDomain:NSURLErrorDomain code:NSURLErrorFileDoesNotExist userInfo:nil] cacheType:JPVideoPlayerCacheTypeNone url:url];
            // hide progress view.
            [self hideProgressViewWithURL:url options:options];
            return operation;
        }
    }
    else{
        operation.cacheOperation = [self.videoCache queryCacheOperationForKey:key done:^(NSString * _Nullable videoPath, JPVideoPlayerCacheType cacheType) {
            
            if (operation.isCancelled) {
                [self safelyRemoveOperationFromRunning:operation];
                return;
            }
            
            // NO cache in disk or the delegate do not responding the `videoPlayerManager:shouldDownloadVideoForURL:`,  or the delegate allow download video.
            if (!videoPath && (![self.delegate respondsToSelector:@selector(videoPlayerManager:shouldDownloadVideoForURL:)] || [self.delegate videoPlayerManager:self shouldDownloadVideoForURL:url])) {
                
                // cache token.
                __block  JPVideoPlayerCacheToken *cacheToken = nil;
                
                // download if no cache, and download allowed by delegate.
                JPVideoPlayerDownloaderOptions downloaderOptions = 0;
                {
                    if (options & JPVideoPlayerContinueInBackground)
                        downloaderOptions |= JPVideoPlayerDownloaderContinueInBackground;
                    if (options & JPVideoPlayerHandleCookies)
                        downloaderOptions |= JPVideoPlayerDownloaderHandleCookies;
                    if (options & JPVideoPlayerAllowInvalidSSLCertificates)
                        downloaderOptions |= JPVideoPlayerDownloaderAllowInvalidSSLCertificates;
                }
                
                // Save received data to disk.
                JPVideoPlayerDownloaderProgressBlock handleProgressBlock = ^(NSData * _Nullable data, NSInteger receivedSize, NSInteger expectedSize, NSString *_Nullable tempVideoCachedPath, NSURL * _Nullable targetURL){
                    
                    cacheToken = [self.videoCache storeVideoData:data expectedSize:expectedSize forKey:key completion:^(NSUInteger storedSize, NSError * _Nullable error, NSString * _Nullable fullVideoCachePath) {
                        __strong __typeof(weakOperation) strongOperation = weakOperation;
                        
                        if (!strongOperation || strongOperation.isCancelled) {
                            // Do nothing if the operation was cancelled
                            // if we would call the completedBlock, there could be a race condition between this block and another completedBlock for the same object, so if this one is called second, we will overwrite the new data.
                        }
                        if (!error) {
                            
                            // refresh progress view.
                            [self progressRefreshWithURL:targetURL options:options receiveSize:storedSize exceptSize:expectedSize];
                            
                            if (!fullVideoCachePath) {
                                if (progressBlock) {
                                    progressBlock(data, storedSize, expectedSize, tempVideoCachedPath, targetURL);
                                }
#pragma mark - Play video from web
                                { // play video from web.
                                    if (![JPVideoPlayer sharedManager].currentVideoPlayerModel) {
                                        __strong typeof(wShowView) sShowView = wShowView;
                                        if (!sShowView) return;
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
                                        // display backLayer.
                                        [sShowView performSelector:NSSelectorFromString(@"displayBackLayer")];
#pragma clang diagnostic pop
                                        [[JPVideoPlayer sharedManager] playVideoWithURL:url tempVideoCachePath:tempVideoCachedPath options:options videoFileExceptSize:expectedSize videoFileReceivedSize:storedSize showOnView:sShowView                                                 progress:^(double currentSeconds, double totalSeconds) {
                                            double progress = currentSeconds / totalSeconds;
                                            BOOL needDisplayProgress = [self needDisplayPlayingProgressViewWithPlayingProgressValue:progress];
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
                                            if (needDisplayProgress) {
                                                [sShowView performSelector:NSSelectorFromString(@"jp_progressViewPlayingStatusChangedWithProgressValue:") withObject:@(progress)];
                                            }
#pragma clang diagnostic pop
                                            
                                        } error:^(NSError * _Nullable error) {
                                            if (error) {
                                                if (completedBlock) {
                                                    [self callCompletionBlockForOperation:strongOperation completion:completedBlock videoPath:videoPath error:error cacheType:JPVideoPlayerCacheTypeNone url:targetURL];
                                                    // hide indicator.
                                                    // [self hideAllIndicatorAndProgressViewsWithURL:url options:options];
                                                    [self safelyRemoveOperationFromRunning:operation];
                                                }
                                            }
                                        }];
                                        [JPVideoPlayer sharedManager].delegate = self;
                                    }
                                    else{
                                        NSString *key = [[JPVideoPlayerManager sharedManager] cacheKeyForURL:targetURL];
                                        if ([JPVideoPlayer sharedManager].currentVideoPlayerModel && [key isEqualToString:[JPVideoPlayer sharedManager].currentVideoPlayerModel.playingKey]) {
                                            [[JPVideoPlayer sharedManager] didReceivedDataCacheInDiskByTempPath:tempVideoCachedPath videoFileExceptSize:expectedSize videoFileReceivedSize:receivedSize];
                                        }
                                    }
                                }
                            }
                            else{
#pragma mark - Cache Finished.
                                // cache finished, and move the full video file from temporary path to full path.
                                [[JPVideoPlayer sharedManager] didCachedVideoDataFinishedFromWebFullVideoCachePath:fullVideoCachePath];
                                [self callCompletionBlockForOperation:strongOperation completion:completedBlock videoPath:fullVideoCachePath error:nil cacheType:JPVideoPlayerCacheTypeNone url:url];
                                [self safelyRemoveOperationFromRunning:strongOperation];
                                
                                if (self.delegate && [self.delegate respondsToSelector:@selector(videoPlayerManager:downloadingProgressDidChanged:)]) {
                                    [self.delegate videoPlayerManager:self downloadingProgressDidChanged:1];
                                }
                            }
                        }
                        else{
                            // some error happens.
                            [self callCompletionBlockForOperation:strongOperation completion:completedBlock videoPath:nil error:error cacheType:JPVideoPlayerCacheTypeNone url:url];
                            
                            // hide indicator view.
                            [self hideAllIndicatorAndProgressViewsWithURL:url options:options];
                            [self safelyRemoveOperationFromRunning:strongOperation];
                        }
                    }];
                };
                
                // delete all temporary first, then download video from web.
                [self.videoCache deleteAllTempCacheOnCompletion:^{
                    [self.videoDownloader downloadVideoWithURL:url options:downloaderOptions progress:handleProgressBlock completion:^(NSError * _Nullable error) {
                        
                        __strong __typeof(weakOperation) strongOperation = weakOperation;
                        if (!strongOperation || strongOperation.isCancelled) {
                            // Do nothing if the operation was cancelled.
                            // if we would call the completedBlock, there could be a race condition between this block and another completedBlock for the same object, so if this one is called second, we will overwrite the new data.
                        }
                        else if (error){
                            [self callCompletionBlockForOperation:strongOperation completion:completedBlock videoPath:nil error:error cacheType:JPVideoPlayerCacheTypeNone url:url];
                            
                            if (   error.code != NSURLErrorNotConnectedToInternet
                                && error.code != NSURLErrorCancelled
                                && error.code != NSURLErrorTimedOut
                                && error.code != NSURLErrorInternationalRoamingOff
                                && error.code != NSURLErrorDataNotAllowed
                                && error.code != NSURLErrorCannotFindHost
                                && error.code != NSURLErrorCannotConnectToHost) {
                                @synchronized (self.failedURLs) {
                                    [self.failedURLs addObject:url];
                                }
                            }
                            
                            [self safelyRemoveOperationFromRunning:strongOperation];
                        }
                        else{
                            if ((options & JPVideoPlayerRetryFailed)) {
                                @synchronized (self.failedURLs) {
                                    if ([self.failedURLs containsObject:url]) {
                                        [self.failedURLs removeObject:url];
                                    }
                                }
                            }
                        }
                    }];
                    
                    operation.cancelBlock = ^{
                        [self.videoCache cancel:cacheToken];
                        [self.videoDownloader cancel];
                        [[JPVideoPlayerManager sharedManager] stopPlay];
                        
                        // hide indicator view.
                        [self hideAllIndicatorAndProgressViewsWithURL:url options:options];
                        
                        __strong __typeof(weakOperation) strongOperation = weakOperation;
                        [self safelyRemoveOperationFromRunning:strongOperation];
                    };
                }];
            }
            else if(videoPath){
#pragma mark - Full video cache file in disk
                // full video cache file in disk.
                __strong __typeof(weakOperation) strongOperation = weakOperation;
                
                // hide activity view.
                [self hideActivityViewWithURL:url options:options];
                
                // play video from disk.
                if (cacheType==JPVideoPlayerCacheTypeDisk) {
                    BOOL needDisplayProgressView = [self needDisplayDownloadingProgressViewWithDownloadingProgressValue:1.0];
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
                    if (needDisplayProgressView) {
                        [showView performSelector:NSSelectorFromString(@"jp_progressViewDownloadingStatusChangedWithProgressValue:") withObject:@1];
                    }
                    // display backLayer.
                    [showView performSelector:NSSelectorFromString(@"displayBackLayer")];
#pragma clang diagnostic pop
                    
                    [[JPVideoPlayer sharedManager] playExistedVideoWithURL:url fullVideoCachePath:videoPath options:options showOnView:showView progress:^(double currentSeconds, double totalSeconds) {
                        double progress = currentSeconds / totalSeconds;
                        __strong typeof(wShowView) sShowView = wShowView;
                        if (!sShowView) return;
                        
                        BOOL needDisplayProgressView = [self needDisplayPlayingProgressViewWithPlayingProgressValue:progress];
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
                        if (needDisplayProgressView) {
                            [sShowView performSelector:NSSelectorFromString(@"jp_progressViewPlayingStatusChangedWithProgressValue:") withObject:@(progress)];
                        }
#pragma clang diagnostic pop
                    } error:^(NSError * _Nullable error) {
                        if (completedBlock) {
                            completedBlock(nil, error, JPVideoPlayerCacheTypeLocation, url);
                        }
                    }];
                    [JPVideoPlayer sharedManager].delegate = self;
                }
                
                [self callCompletionBlockForOperation:strongOperation completion:completedBlock videoPath:videoPath error:nil cacheType:JPVideoPlayerCacheTypeDisk url:url];
                [self safelyRemoveOperationFromRunning:operation];
            }
            else {
                // video not in cache and download disallowed by delegate.
                
                // hide activity and progress view.
                [self hideAllIndicatorAndProgressViewsWithURL:url options:options];
                
                __strong __typeof(weakOperation) strongOperation = weakOperation;
                [self callCompletionBlockForOperation:strongOperation completion:completedBlock videoPath:nil error:nil cacheType:JPVideoPlayerCacheTypeNone url:url];
                [self safelyRemoveOperationFromRunning:operation];
                // hide indicator view.
                [self hideAllIndicatorAndProgressViewsWithURL:url options:options];
            }
        }];
    }
    
    return operation;
}

- (nullable id <JPVideoPlayerOperation>)playVideoWithURL:(nonnull NSURL *)url
                                              showOnView:(nonnull UIView *)showView
                                                 options:(JPVideoPlayerOptions)options
                                                progress:(nullable JPVideoPlayerDownloaderProgressBlock)progressBlock
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
    __weak JPVideoPlayerCombinedOperation *weakOperation = operation;
    
    BOOL isFailedUrl = NO;
    if (url) {
        pthread_mutex_lock(&_lock);
        isFailedUrl = [self.failedURLs containsObject:url];
        pthread_mutex_unlock(&_lock);
    }
    
    if (url.absoluteString.length == 0 || (!(options & JPVideoPlayerRetryFailed) && isFailedUrl)) {
        [self callCompletionBlockForOperation:operation
                                   completion:completionBlock
                                    videoPath:nil
                                        error:[NSError errorWithDomain:JPVideoPlayerErrorDomain code:NSURLErrorFileDoesNotExist userInfo:@{NSLocalizedDescriptionKey : @"the file of given URL not exists"}]
                                    cacheType:JPVideoPlayerCacheTypeNone
                                          url:url];
        return operation;
    }
    
    pthread_mutex_lock(&_lock);
    [self.runningOperations addObject:operation];
    pthread_mutex_unlock(&_lock);
    
    NSString *key = [self cacheKeyForURL:url];
    // show progress view and activity indicator view if need.
    [self showProgressViewAndActivityIndicatorViewForView:showView options:options];
    __weak typeof(showView) wShowView = showView;
    
    BOOL isFileURL = [url isFileURL];
    if (isFileURL) {
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
                [self safelyRemoveOperationFromRunning:operation];
                return;
            }
            
            if (operation.isCancelled) {
                [self safelyRemoveOperationFromRunning:operation];
                return;
            }
            
            if (!videoPath && (![self.delegate respondsToSelector:@selector(videoPlayerManager:shouldDownloadVideoForURL:)] || [self.delegate videoPlayerManager:self shouldDownloadVideoForURL:url])) {
                
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
                                         operation:operation
                                   completionBlock:completionBlock
                                         cacheType:cacheType];
                
            }
            else {
                // video not in cache and download disallowed by delegate.
                [self callCompletionBlockForOperation:strongOperation
                                           completion:completionBlock
                                            videoPath:nil
                                                error:nil
                                            cacheType:JPVideoPlayerCacheTypeNone
                                                  url:url];
                [self safelyRemoveOperationFromRunning:operation];
            }
        }];
    }
    return nil;
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
    [self downloadProgressDidChange:1.0];
    
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
    [showView performSelector:NSSelectorFromString(@"jp_progressViewDownloadingStatusChangedWithProgressValue:") withObject:@1];
    // display backLayer.
    [showView performSelector:NSSelectorFromString(@"displayBackLayer")];
#pragma clang diagnostic pop
    
    [[JPVideoPlayer sharedManager] playExistedVideoWithURL:url
                                             fullVideoCachePath:videoPath
                                                        options:options
                                                     showOnView:showView
                                                       progress:^(double currentSeconds, double totalSeconds) {
                                                           double progress = currentSeconds / totalSeconds;
                                                           BOOL needDisplayProgressView = [self needDisplayPlayingProgressViewWithPlayingProgressValue:progress];
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
    [JPVideoPlayer sharedManager].delegate = self;
    
    [self callCompletionBlockForOperation:operation
                               completion:completionBlock
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
        [self downloadProgressDidChange:1.0];
        
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
        [showView performSelector:NSSelectorFromString(@"jp_progressViewDownloadingStatusChangedWithProgressValue:") withObject:@1];
        
        // display backLayer.
        [showView performSelector:NSSelectorFromString(@"displayBackLayer")];
#pragma clang diagnostic pop
        
        __weak typeof(showView) wShowView = showView;
        [[JPVideoPlayer sharedManager] playExistedVideoWithURL:url
                                                 fullVideoCachePath:path
                                                            options:options
                                                         showOnView:showView
                                                           progress:^(double currentSeconds, double totalSeconds) {
                                                               double progress = currentSeconds / totalSeconds;
                                                               
                                                               __strong typeof(wShowView) sShowView = wShowView;
                                                               if (!sShowView) return;
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
                                                               BOOL needDisplayProgress = [self needDisplayPlayingProgressViewWithPlayingProgressValue:progress];
                                                               if (needDisplayProgress) {
                                                                   [sShowView performSelector:NSSelectorFromString(@"jp_progressViewPlayingStatusChangedWithProgressValue:") withObject:@(progress)];
                                                               }
#pragma clang diagnostic pop
                                                               
                                                           } error:^(NSError * _Nullable error) {
                                                               
                                                               if (completionBlock) {
                                                                   completionBlock(nil, error, JPVideoPlayerCacheTypeLocation, url);
                                                               }
                                                               
                                                           }];
        [JPVideoPlayer sharedManager].delegate = self;
    }
    else{
        [self callCompletionBlockForOperation:operation
                                   completion:completionBlock
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
        if (self.showViews.count) {
            for (UIView *view in self.showViews) {
                [view performSelector:NSSelectorFromString(@"jp_removeVideoLayerViewAndIndicatorView")];
                [view performSelector:NSSelectorFromString(@"jp_hideActivityIndicatorView")];
                [view performSelector:NSSelectorFromString(@"jp_hideProgressView")];
                view.currentPlayingURL = nil;
            }
            [self.showViews removeAllObjects];
        }
        
        [[JPVideoPlayer sharedManager] stopPlay];
    });
#pragma clang diagnostic pop
}

- (void)pause{
    [[JPVideoPlayer sharedManager] pause];
}

- (void)resume{
    [[JPVideoPlayer sharedManager] resume];
}

- (void)setPlayerMute:(BOOL)mute{
    if ([JPVideoPlayer sharedManager].currentVideoPlayerModel) {
        [[JPVideoPlayer sharedManager] setMute:mute];
    }
    self.mute = mute;
}

- (BOOL)playerIsMute{
    return self.mute;
}


#pragma mark - JPVideoPlayerInternalDelegate

- (BOOL)playVideoTool:(JPVideoPlayer *)videoTool shouldAutoReplayVideoForURL:(NSURL *)videoURL{
    if (self.delegate && [self.delegate respondsToSelector:@selector(videoPlayerManager:shouldAutoReplayForURL:)]) {
        return [self.delegate videoPlayerManager:self shouldAutoReplayForURL:videoURL];
    }
    return YES;
}

- (void)playVideoTool:(JPVideoPlayer *)videoTool playingStatuDidChanged:(JPVideoPlayerStatus)playingStatus{
    if (self.delegate && [self.delegate respondsToSelector:@selector(videoPlayerManager:playingStatusDidChanged:)]) {
        [self.delegate videoPlayerManager:self playingStatusDidChanged:playingStatus];
    }
}


#pragma mark - NewPrivate

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

- (void)downloadProgressDidChange:(CGFloat)downloadProgress {
    BOOL respond = self.delegate && [self.delegate respondsToSelector:@selector(videoPlayerManager:downloadingProgressDidChanged:)];
    if (respond) {
        [self.delegate videoPlayerManager:self downloadingProgressDidChanged:downloadProgress];
    }
}

- (void)playProgressDidChange:(CGFloat)playProgress {
    BOOL respond = self.delegate && [self.delegate respondsToSelector:@selector(videoPlayerManager:playingProgressDidChanged:)];
    [self.delegate videoPlayerManager:self playingProgressDidChanged:playProgress];
}


#pragma mark - Private

- (BOOL)needDisplayDownloadingProgressViewWithDownloadingProgressValue:(CGFloat)downloadingProgress{
    BOOL respond = self.delegate && [self.delegate respondsToSelector:@selector(videoPlayerManager:downloadingProgressDidChanged:)];
    [self.delegate videoPlayerManager:self downloadingProgressDidChanged:downloadingProgress];
    return respond;
}

- (BOOL)needDisplayPlayingProgressViewWithPlayingProgressValue:(CGFloat)playingProgress{
    BOOL respond = self.delegate && [self.delegate respondsToSelector:@selector(videoPlayerManager:playingProgressDidChanged:)];
    [self.delegate videoPlayerManager:self playingProgressDidChanged:playingProgress];
    return  respond;
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
            UIView *view = nil;
            for (UIView *v in self.showViews) {
                if (v.currentPlayingURL && [v.currentPlayingURL.absoluteString isEqualToString:url.absoluteString]) {
                    view = v;
                    break;
                }
            }
            if (view) {
                [view performSelector:NSSelectorFromString(@"jp_hideActivityIndicatorView")];
            }
        });
#pragma clang diagnostic pop
    }
}

- (void)hideProgressViewWithURL:(nullable NSURL *)url options:(JPVideoPlayerOptions)options{
    if (![self needDisplayPlayingProgressViewWithPlayingProgressValue:0] || ![self needDisplayDownloadingProgressViewWithDownloadingProgressValue:0]) {
        return;
    }
    
    if (options & JPVideoPlayerShowProgressView){
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
        dispatch_main_async_safe(^{
            UIView *view = nil;
            for (UIView *v in self.showViews) {
                if (v.currentPlayingURL && [v.currentPlayingURL.absoluteString isEqualToString:url.absoluteString]) {
                    view = v;
                    break;
                }
            }
            if (view) {
                [view performSelector:NSSelectorFromString(@"jp_hideProgressView")];
            }
        });
    }
#pragma clang diagnostic pop
}

- (void)progressRefreshWithURL:(nullable NSURL *)url options:(JPVideoPlayerOptions)options receiveSize:(NSUInteger)receiveSize exceptSize:(NSUInteger)expectedSize{
    if (![self needDisplayDownloadingProgressViewWithDownloadingProgressValue:(CGFloat)receiveSize/expectedSize]) {
        return;
    }
    
    if (options & JPVideoPlayerShowProgressView){
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
        dispatch_main_async_safe(^{
            UIView *view = nil;
            for (UIView *v in self.showViews) {
                if (v.currentPlayingURL && [v.currentPlayingURL.absoluteString isEqualToString:url.absoluteString]) {
                    view = v;
                    break;
                }
            }
            if (view) {
                [view performSelector:NSSelectorFromString(@"jp_progressViewDownloadingStatusChangedWithProgressValue:") withObject:@((CGFloat)receiveSize/expectedSize)];
            }
        });
#pragma clang diagnostic pop
    }
}

- (void)showProgressViewAndActivityIndicatorViewForView:(UIView *)view options:(JPVideoPlayerOptions)options{
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
    dispatch_main_async_safe(^{
        BOOL needDisplayProgress = [self needDisplayDownloadingProgressViewWithDownloadingProgressValue:0] || [self needDisplayPlayingProgressViewWithPlayingProgressValue:0];
        
        if ((options & JPVideoPlayerShowProgressView) && needDisplayProgress) {
            [view performSelector:NSSelectorFromString(@"jp_showProgressView")];
        }
        if ((options & JPVideoPlayerShowActivityIndicatorView)) {
            [view performSelector:NSSelectorFromString(@"jp_showActivityIndicatorView")];
        }
    });
#pragma clang diagnostic pop
}

- (void)safelyRemoveOperationFromRunning:(nullable JPVideoPlayerCombinedOperation*)operation {
    @synchronized (self.runningOperations) {
        if (operation) {
            [self.runningOperations removeObject:operation];
        }
    }
}

- (void)callCompletionBlockForOperation:(nullable JPVideoPlayerCombinedOperation*)operation
                             completion:(nullable JPVideoPlayerCompletionBlock)completionBlock
                              videoPath:(nullable NSString *)videoPath
                                  error:(nullable NSError *)error
                              cacheType:(JPVideoPlayerCacheType)cacheType
                                    url:(nullable NSURL *)url {
    dispatch_main_async_safe(^{
        if (operation && !operation.isCancelled && completionBlock) {
            completionBlock(videoPath, error, cacheType, url);
        }
    });
}

- (void)diskVideoExistsForURL:(nullable NSURL *)url completion:(nullable JPVideoPlayerCheckCacheCompletionBlock)completionBlock {
    NSString *key = [self cacheKeyForURL:url];
    [self.videoCache diskVideoExistsWithKey:key completion:^(BOOL isInDiskCache) {
        if (completionBlock) {
            completionBlock(isInDiskCache);
        }
    }];
}

@end
