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
#import "JPVideoPlayerCachePathTool.h"
#import "JPVideoPlayerPlayVideoTool.h"
#import "JPVideoPlayerDownloaderOperation.h"
#import "UIView+WebVideoCacheOperation.h"
#import "UIView+PlayerStatusAndDownloadIndicator.h"
#import "UIView+WebVideoCache.h"

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


@interface JPVideoPlayerManager()<JPVideoPlayerPlayVideoToolDelegate>

@property (strong, nonatomic, readwrite, nonnull) JPVideoPlayerCache *videoCache;

@property (strong, nonatomic, readwrite, nonnull) JPVideoPlayerDownloader *videoDownloader;

@property (strong, nonatomic, nonnull) NSMutableSet<NSURL *> *failedURLs;

@property (strong, nonatomic, nonnull) NSMutableArray<JPVideoPlayerCombinedOperation *> *runningOperations;

@property(nonatomic, getter=isMuted) BOOL mute;

@property (strong, nonatomic, nonnull) NSMutableArray<UIView *> *showViews;

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
    }
    return self;
}


#pragma mark - Public

- (nullable id <JPVideoPlayerOperation>)loadVideoWithURL:(nullable NSURL *)url showOnView:(nullable UIView *)showView options:(JPVideoPlayerOptions)options progress:(nullable JPVideoPlayerDownloaderProgressBlock)progressBlock completed:(nullable JPVideoPlayerCompletionBlock)completedBlock{
    
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
            
            [[JPVideoPlayerPlayVideoTool sharedTool] playExistedVideoWithURL:url fullVideoCachePath:path options:options showOnView:showView playingProgress:^(CGFloat progress) {
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
            [JPVideoPlayerPlayVideoTool sharedTool].delegate = self;
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
                    if (options & JPVideoPlayerShowProgressView)
                        downloaderOptions |= JPVideoPlayerDownloaderShowProgressView;
                    if (options & JPVideoPlayerShowActivityIndicatorView)
                        downloaderOptions |= JPVideoPlayerDownloaderShowActivityIndicatorView;
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
                                { // play video from web.
                                    if (![JPVideoPlayerPlayVideoTool sharedTool].currentPlayVideoItem) {
                                        __strong typeof(wShowView) sShowView = wShowView;
                                        if (!sShowView) return;
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
                                        // display backLayer.
                                        [sShowView performSelector:NSSelectorFromString(@"displayBackLayer")];
#pragma clang diagnostic pop
                                        [[JPVideoPlayerPlayVideoTool sharedTool] playVideoWithURL:url tempVideoCachePath:tempVideoCachedPath options:options videoFileExceptSize:expectedSize videoFileReceivedSize:storedSize showOnView:sShowView playingProgress:^(CGFloat progress) {
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
                                                    [self hideAllIndicatorAndProgressViewsWithURL:url options:options];
                                                    [self safelyRemoveOperationFromRunning:operation];
                                                }
                                            }
                                        }];
                                        [JPVideoPlayerPlayVideoTool sharedTool].delegate = self;
                                    }
                                    else{
                                        NSString *key = [[JPVideoPlayerManager sharedManager] cacheKeyForURL:targetURL];
                                        if ([JPVideoPlayerPlayVideoTool sharedTool].currentPlayVideoItem && [key isEqualToString:[JPVideoPlayerPlayVideoTool sharedTool].currentPlayVideoItem.playingKey]) {
                                            [[JPVideoPlayerPlayVideoTool sharedTool] didReceivedDataCacheInDiskByTempPath:tempVideoCachedPath videoFileExceptSize:expectedSize videoFileReceivedSize:receivedSize];
                                        }
                                    }
                                }
                            }
                            else{
                                // cache finished, and move the full video file from temporary path to full path.
                                [[JPVideoPlayerPlayVideoTool sharedTool] didCachedVideoDataFinishedFromWebFullVideoCachePath:fullVideoCachePath];
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
                    
                    JPVideoPlayerDownloadToken *subOperationToken = [self.videoDownloader downloadVideoWithURL:url options:downloaderOptions progress:handleProgressBlock completed:^(NSError * _Nullable error) {
                        
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
                        [self.videoDownloader cancel:subOperationToken];
                        [[JPVideoPlayerManager sharedManager] stopPlay];
                        
                        // hide indicator view.
                        [self hideAllIndicatorAndProgressViewsWithURL:url options:options];
                        
                        __strong __typeof(weakOperation) strongOperation = weakOperation;
                        [self safelyRemoveOperationFromRunning:strongOperation];
                    };
                }];
            }
            else if(videoPath){
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
                    
                    [[JPVideoPlayerPlayVideoTool sharedTool] playExistedVideoWithURL:url fullVideoCachePath:videoPath options:options showOnView:showView playingProgress:^(CGFloat progress) {
                        __strong typeof(wShowView) sShowView = wShowView;
                        if (!sShowView) return;
                        
                        BOOL needDisplayProgressView = [self needDisplayPlayingProgressViewWithPlayingProgressValue:progress];
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
                        if (needDisplayProgressView) {
                            [showView performSelector:NSSelectorFromString(@"jp_progressViewPlayingStatusChangedWithProgressValue:") withObject:@(progress)];
                        }
#pragma clang diagnostic pop
                    } error:^(NSError * _Nullable error) {
                        if (completedBlock) {
                            completedBlock(nil, error, JPVideoPlayerCacheTypeLocation, url);
                        }
                    }];
                    [JPVideoPlayerPlayVideoTool sharedTool].delegate = self;
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

- (void)cancelAllDownloads{
    [self.videoDownloader cancelAllDownloads];
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
        
        [[JPVideoPlayerPlayVideoTool sharedTool] stopPlay];
    });
#pragma clang diagnostic pop
}

- (void)pause{
    [[JPVideoPlayerPlayVideoTool sharedTool] pause];
}

- (void)resume{
    [[JPVideoPlayerPlayVideoTool sharedTool] resume];
}

- (void)setPlayerMute:(BOOL)mute{
    if ([JPVideoPlayerPlayVideoTool sharedTool].currentPlayVideoItem) {
        [[JPVideoPlayerPlayVideoTool sharedTool] setMute:mute];
    }
    self.mute = mute;
}

- (BOOL)playerIsMute{
    return self.mute;
}


#pragma mark - JPVideoPlayerPlayVideoToolDelegate

- (BOOL)playVideoTool:(JPVideoPlayerPlayVideoTool *)videoTool shouldAutoReplayVideoForURL:(NSURL *)videoURL{
    if (self.delegate && [self.delegate respondsToSelector:@selector(videoPlayerManager:shouldAutoReplayForURL:)]) {
        return [self.delegate videoPlayerManager:self shouldAutoReplayForURL:videoURL];
    }
    return YES;
}

- (void)playVideoTool:(JPVideoPlayerPlayVideoTool *)videoTool playingStatuDidChanged:(JPVideoPlayerPlayingStatus)playingStatus{
    if (self.delegate && [self.delegate respondsToSelector:@selector(videoPlayerManager:playingStatusDidChanged:)]) {
        [self.delegate videoPlayerManager:self playingStatusDidChanged:playingStatus];
    }
}


#pragma mark - Private

- (BOOL)needDisplayDownloadingProgressViewWithDownloadingProgressValue:(CGFloat)downloadingProgress{
    BOOL respond = self.delegate && [self.delegate respondsToSelector:@selector(videoPlayerManager:downloadingProgressDidChanged:)];
    BOOL download = [self.delegate videoPlayerManager:self downloadingProgressDidChanged:downloadingProgress];
    return  respond && download;
}

- (BOOL)needDisplayPlayingProgressViewWithPlayingProgressValue:(CGFloat)playingProgress{
    BOOL respond = self.delegate && [self.delegate respondsToSelector:@selector(videoPlayerManager:playingProgressDidChanged:)];
    BOOL playing = [self.delegate videoPlayerManager:self playingProgressDidChanged:playingProgress];
    return  respond && playing;
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

- (void)callCompletionBlockForOperation:(nullable JPVideoPlayerCombinedOperation*)operation completion:(nullable JPVideoPlayerCompletionBlock)completionBlock videoPath:(nullable NSString *)videoPath error:(nullable NSError *)error cacheType:(JPVideoPlayerCacheType)cacheType url:(nullable NSURL *)url {
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
