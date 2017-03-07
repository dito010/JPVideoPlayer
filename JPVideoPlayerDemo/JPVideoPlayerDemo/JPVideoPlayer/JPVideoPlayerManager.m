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


@interface JPVideoPlayerManager()

@property (strong, nonatomic, readwrite, nonnull) JPVideoPlayerCache *videoCache;

@property (strong, nonatomic, readwrite, nonnull) JPVideoPlayerDownloader *videoDownloader;

@property (strong, nonatomic, nonnull) NSMutableSet<NSURL *> *failedURLs;

@property (strong, nonatomic, nonnull) NSMutableArray<JPVideoPlayerCombinedOperation *> *runningOperations;

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
    JPVideoPlayerCache *cache = [JPVideoPlayerCache sharedImageCache];
    JPVideoPlayerDownloader *downloader = [JPVideoPlayerDownloader sharedDownloader];
    return [self initWithCache:cache downloader:downloader];
}

- (nonnull instancetype)initWithCache:(nonnull JPVideoPlayerCache *)cache downloader:(nonnull JPVideoPlayerDownloader *)downloader {
    if ((self = [super init])) {
        _videoCache = cache;
        _videoDownloader = downloader;
        _failedURLs = [NSMutableSet new];
        _runningOperations = [NSMutableArray array];
    }
    return self;
}


#pragma mark -----------------------------------------
#pragma mark Public

- (id<JPVideoPlayerOperation>)loadVideoWithURL:(NSURL *)url options:(JPVideoPlayerOptions)options progress:(JPVideoPlayerDownloaderProgressBlock)progressBlock completed:(JPVideoPlayerCompletionBlock)completedBlock{
    
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
    
    NSString *key = [self cacheKeyForURL:url];
    
    operation.cacheOperation = [self.videoCache queryCacheOperationForKey:key done:^(NSString * _Nullable videoPath, JPVideoPlayerCacheType cacheType) {
        
        if (operation.isCancelled) {
            [self safelyRemoveOperationFromRunning:operation];
            return;
        }
        
        // NO cache in disk or the delegate do not responding the `videoPlayerManager:shouldDownloadVideoForURL:`,  or the delegate allow download video.
        if (!videoPath && (![self.delegate respondsToSelector:@selector(videoPlayerManager:shouldDownloadVideoForURL:)] || [self.delegate videoPlayerManager:self shouldDownloadVideoForURL:url])) {
            
            // download if no cache, and download allowed by delegate.
            JPVideoPlayerDownloaderOptions downloaderOptions = 0;
            {
                if (options & JPVideoPlayerContinueInBackground) downloaderOptions |= JPVideoPlayerDownloaderContinueInBackground;
                if (options & JPVideoPlayerHandleCookies) downloaderOptions |= JPVideoPlayerDownloaderHandleCookies;
                if (options & JPVideoPlayerAllowInvalidSSLCertificates) downloaderOptions |= JPVideoPlayerDownloaderAllowInvalidSSLCertificates;
            }
            
            // cache token.
            __block  JPVideoPlayerCacheToken *cacheToken = nil;
            
            // Save received data to disk.
            JPVideoPlayerDownloaderProgressBlock handleProgressBlock = ^(NSData * _Nullable data, NSInteger receivedSize, NSInteger expectedSize, NSString *_Nullable tempVideoCachedPath, NSURL * _Nullable targetURL){
                
                cacheToken = [self.videoCache storeVideoData:data expectedSize:expectedSize forKey:key completion:^(NSUInteger storedSize, NSError * _Nullable error, NSString * _Nullable fullVideoCachePath) {
                    __strong __typeof(weakOperation) strongOperation = weakOperation;
                    
                    if (!strongOperation || strongOperation.isCancelled) {
                        // Do nothing if the operation was cancelled
                        // if we would call the completedBlock, there could be a race condition between this block and another completedBlock for the same object, so if this one is called second, we will overwrite the new data.
                    }
                    if (!error) {
                        if (!fullVideoCachePath) {
                            if (progressBlock) {
                                progressBlock(data, storedSize, expectedSize, tempVideoCachedPath, targetURL);
                            }
                        }
                        else{
                            // cache finished, and move the full video file from temporary path to full path.
                            [self callCompletionBlockForOperation:strongOperation completion:completedBlock videoPath:fullVideoCachePath error:nil cacheType:JPVideoPlayerCacheTypeNone url:url];
                        }
                    }
                    else{
                        // some error happens.
                        [self callCompletionBlockForOperation:strongOperation completion:completedBlock videoPath:nil error:error cacheType:JPVideoPlayerCacheTypeNone url:url];
                    }
                    
                    [self safelyRemoveOperationFromRunning:strongOperation];
                }];
            };
            
            // Cancels all download operations.
            // only keep one download operation running.
            [self.videoDownloader cancelAllDownloads];
            
            // delete all temporary first.
            [self.videoCache deleteAllTempCacheOnCompletion:^{
                
                JPVideoPlayerDownloadToken *subOperationToken = [self.videoDownloader downloadVideoWithURL:url options:downloaderOptions progress:handleProgressBlock completed:^(NSError * _Nullable error) {
                    
                    __strong __typeof(weakOperation) strongOperation = weakOperation;
                    if (!strongOperation || strongOperation.isCancelled) {
                        // Do nothing if the operation was cancelled
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
                    
                    [self safelyRemoveOperationFromRunning:strongOperation];
                }];
                
                operation.cancelBlock = ^{
                    [self.videoCache cancel:cacheToken];
                    [self.videoDownloader cancel:subOperationToken];
                    __strong __typeof(weakOperation) strongOperation = weakOperation;
                    [self safelyRemoveOperationFromRunning:strongOperation];
                };
            }];
        }
        else if(videoPath){
            // full video cache file in disk.
            __strong __typeof(weakOperation) strongOperation = weakOperation;
            [self callCompletionBlockForOperation:strongOperation completion:completedBlock videoPath:videoPath error:nil cacheType:JPVideoPlayerCacheTypeDisk url:url];
            [self safelyRemoveOperationFromRunning:operation];
        }
        else {
            // video not in cache and download disallowed by delegate.
            __strong __typeof(weakOperation) strongOperation = weakOperation;
            [self callCompletionBlockForOperation:strongOperation completion:completedBlock videoPath:nil error:nil cacheType:JPVideoPlayerCacheTypeNone url:url];
            [self safelyRemoveOperationFromRunning:operation];
        }
    }];
    
    return operation;
}

-(void)cancelAllDownloads{
    [self.videoDownloader cancelAllDownloads];
}

- (nullable NSString *)cacheKeyForURL:(nullable NSURL *)url {
    if (!url) {
        return @"";
    }
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
    url = [[NSURL alloc] initWithScheme:url.scheme host:url.host path:url.path];
#pragma clang diagnostic pop
    return [url absoluteString];
}


#pragma mark -----------------------------------------
#pragma mark Private

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
