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


#import "JPVideoPlayerDownloaderOperation.h"
#import "JPVideoPlayerCachePathTool.h"
#import "JPVideoPlayerManager.h"

NSString *const JPVideoPlayerDownloadStartNotification = @"www.jpvideplayer.download.start.notification";
NSString *const JPVideoPlayerDownloadReceiveResponseNotification = @"www.jpvideoplayer.download.received.response.notification";
NSString *const JPVideoPlayerDownloadStopNotification = @"www.jpvideplayer.download.stop.notification";
NSString *const JPVideoPlayerDownloadFinishNotification = @"www.jpvideplayer.download.finished.notification";

static NSString *const kProgressCallbackKey = @"www.jpvideplayer.progress.callback";
static NSString *const kErrorCallbackKey = @"www.jpvideplayer.error.callback";

typedef NSMutableDictionary<NSString *, id> JPCallbacksDictionary;

@interface JPVideoPlayerDownloaderOperation()

@property (strong, nonatomic, nonnull)NSMutableArray<JPCallbacksDictionary *> *callbackBlocks;

@property (assign, nonatomic, getter = isExecuting)BOOL executing;

@property (assign, nonatomic, getter = isFinished)BOOL finished;

// This is weak because it is injected by whoever manages this session. If this gets nil-ed out, we won't be able to run.
// the task associated with this operation.
@property (weak, nonatomic, nullable) NSURLSession *unownedSession;

// This is set if we're using not using an injected NSURLSession. We're responsible of invalidating this one.
@property (strong, nonatomic, nullable) NSURLSession *ownedSession;

@property (strong, nonatomic, readwrite, nullable) NSURLSessionTask *dataTask;

@property (strong, nonatomic, nullable) dispatch_queue_t barrierQueue;

@property (assign, nonatomic) UIBackgroundTaskIdentifier backgroundTaskId;

// The size of receivered data now.
@property(nonatomic, assign)NSUInteger receiveredSize;

@end

@implementation JPVideoPlayerDownloaderOperation{
    BOOL responseFromCached;
}

@synthesize executing = _executing;
@synthesize finished = _finished;

- (nonnull instancetype)init{
    return [self initWithRequest:nil inSession:nil options:0];
}


#pragma mark - Public

- (nonnull instancetype)initWithRequest:(nullable NSURLRequest *)request
                              inSession:(nullable NSURLSession *)session
                                options:(JPVideoPlayerDownloaderOptions)options {
    if ((self = [super init])) {
        _request = [request copy];
        _options = options;
        _callbackBlocks = [NSMutableArray new];
        _executing = NO;
        _finished = NO;
        _expectedSize = 0;
        _unownedSession = session;
        responseFromCached = YES; // Initially wrong until `- URLSession:dataTask:willCacheResponse:completionHandler: is called or not called
        _barrierQueue = dispatch_queue_create("com.NewPan.JPVideoPlayerDownloaderOperationBarrierQueue", DISPATCH_QUEUE_CONCURRENT);
    }
    return self;
}

- (nullable id)addHandlersForProgress:(nullable JPVideoPlayerDownloaderProgressBlock)progressBlock error:(nullable JPVideoPlayerDownloaderErrorBlock)errorBlock{
    
    JPCallbacksDictionary *callbacks = [NSMutableDictionary new];
    
    if (progressBlock) callbacks[kProgressCallbackKey] = [progressBlock copy];
    if (errorBlock) callbacks[kErrorCallbackKey] = [errorBlock copy];
    
    dispatch_barrier_async(self.barrierQueue, ^{
        [self.callbackBlocks addObject:callbacks];
    });
    
    return callbacks;
}

- (BOOL)cancel:(nullable id)token {
    __block BOOL shouldCancel = NO;
    dispatch_barrier_sync(self.barrierQueue, ^{
        [self.callbackBlocks removeObjectIdenticalTo:token];
        if (self.callbackBlocks.count == 0) {
            shouldCancel = YES;
        }
    });
    if (shouldCancel) {
        [self cancel];
    }
    return shouldCancel;
}


#pragma mark - NSOperation Required

- (void)start {
    @synchronized (self) {
        if (self.isCancelled) {
            self.finished = YES;
            [self reset];
            return;
        }
        Class UIApplicationClass = NSClassFromString(@"UIApplication");
        BOOL hasApplication = UIApplicationClass && [UIApplicationClass respondsToSelector:@selector(sharedApplication)];
        if (hasApplication && [self shouldContinueWhenAppEntersBackground]) {
            __weak __typeof__ (self) wself = self;
            UIApplication * app = [UIApplicationClass performSelector:@selector(sharedApplication)];
            self.backgroundTaskId = [app beginBackgroundTaskWithExpirationHandler:^{
                __strong __typeof (wself) sself = wself;
                
                if (sself) {
                    [sself cancel];
                    [app endBackgroundTask:sself.backgroundTaskId];
                    sself.backgroundTaskId = UIBackgroundTaskInvalid;
                }
            }];
        }
        else{
            return;
        }
        
        NSURLSession *session = self.unownedSession;
        if (!self.unownedSession) {
            NSURLSessionConfiguration *sessionConfig = [NSURLSessionConfiguration defaultSessionConfiguration];
            sessionConfig.timeoutIntervalForRequest = 15;
            
            /**
             *  Create the session for this task
             *  We send nil as delegate queue so that the session creates a serial operation queue for performing all delegate
             *  method calls and completion handler calls.
             */
            self.ownedSession = [NSURLSession sessionWithConfiguration:sessionConfig delegate:self delegateQueue:nil];
            session = self.ownedSession;
        }
        
        self.dataTask = [session dataTaskWithRequest:self.request];
        self.executing = YES;
    }
    
    [self.dataTask resume];
    
    if (self.dataTask) {
        
        dispatch_main_async_safe(^{
            [[NSNotificationCenter defaultCenter] postNotificationName:JPVideoPlayerDownloadStartNotification object:self];
        });
        @autoreleasepool {
            for (JPVideoPlayerDownloaderProgressBlock progressBlock in [self callbacksForKey:kProgressCallbackKey]) {
                progressBlock(nil, 0, NSURLResponseUnknownLength, nil, self.request.URL);
            }
        }
    }
    else {
        [self callErrorBlocksWithError:[NSError errorWithDomain:NSURLErrorDomain code:0 userInfo:@{NSLocalizedDescriptionKey : @"Connection can't be initialized"}]];
    }
    
    if (self.backgroundTaskId != UIBackgroundTaskInvalid) {
        UIApplication * app = [UIApplication performSelector:@selector(sharedApplication)];
        [app endBackgroundTask:self.backgroundTaskId];
        self.backgroundTaskId = UIBackgroundTaskInvalid;
    }
}

- (void)cancel {
    @synchronized (self) {
        [self cancelInternal];
    }
}


#pragma mark - NSURLSessionDataDelegate

- (void)URLSession:(NSURLSession *)session dataTask:(NSURLSessionDataTask *)dataTask didReceiveResponse:(NSURLResponse *)response completionHandler:(void (^)(NSURLSessionResponseDisposition))completionHandler{
    
    //'304 Not Modified' is an exceptional one.
    if (![response respondsToSelector:@selector(statusCode)] || (((NSHTTPURLResponse *)response).statusCode < 400 && ((NSHTTPURLResponse *)response).statusCode != 304)) {
        
        NSInteger expected = MAX((NSInteger)response.expectedContentLength, 0);
        self.expectedSize = expected;
        
        @autoreleasepool {
            for (JPVideoPlayerDownloaderProgressBlock progressBlock in [self callbacksForKey:kProgressCallbackKey]) {
                
                // May the free size of the device less than the expected size of the video data.
                if (![[JPVideoPlayerCache sharedCache] haveFreeSizeToCacheFileWithSize:expected]) {
                    if (completionHandler) {
                        completionHandler(NSURLSessionResponseCancel);
                    }
                    dispatch_async(dispatch_get_main_queue(), ^{
                        [[NSNotificationCenter defaultCenter] postNotificationName:JPVideoPlayerDownloadStopNotification object:self];
                    });
                    
                    [self callErrorBlocksWithError:[NSError errorWithDomain:@"No enough size of device to cache the video data" code:0 userInfo:nil]];
                    
                    [self done];
                    
                    return;
                }
                else{
                    NSString *key = [[JPVideoPlayerManager sharedManager] cacheKeyForURL:self.request.URL];
                    progressBlock(nil, 0, expected, [JPVideoPlayerCachePathTool videoCacheTemporaryPathForKey:key], response.URL);
                }
            }
        }
        
        if (completionHandler) {
            completionHandler(NSURLSessionResponseAllow);
        }
        self.response = response;
        dispatch_main_async_safe(^{
            [[NSNotificationCenter defaultCenter] postNotificationName:JPVideoPlayerDownloadReceiveResponseNotification object:self];
        });
    }
    else {
        NSUInteger code = ((NSHTTPURLResponse *)response).statusCode;
        
        // This is the case when server returns '304 Not Modified'. It means that remote video is not changed.
        // In case of 304 we need just cancel the operation and return cached video from the cache.
        if (code == 304) {
            [self cancelInternal];
        } else {
            [self.dataTask cancel];
        }
        
        dispatch_main_async_safe(^{
            [[NSNotificationCenter defaultCenter] postNotificationName:JPVideoPlayerDownloadStopNotification object:self];
        });
        
        [self callErrorBlocksWithError:[NSError errorWithDomain:NSURLErrorDomain code:((NSHTTPURLResponse *)response).statusCode userInfo:nil]];
        
        [self done];
    }
}

- (void)URLSession:(NSURLSession *)session dataTask:(NSURLSessionDataTask *)dataTask didReceiveData:(NSData *)data {
    NSString *key = [[JPVideoPlayerManager sharedManager] cacheKeyForURL:self.request.URL];
    self.receiveredSize += data.length;
    
    @autoreleasepool {
        for (JPVideoPlayerDownloaderProgressBlock progressBlock in [self callbacksForKey:kProgressCallbackKey]) {
            progressBlock(data, self.receiveredSize, self.expectedSize, [JPVideoPlayerCachePathTool videoCacheTemporaryPathForKey:key], self.request.URL);
        }
    }
}

- (void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task didCompleteWithError:(NSError *)error{
    @synchronized(self) {
        self.dataTask = nil;
        
        dispatch_main_async_safe(^{
            [[NSNotificationCenter defaultCenter] postNotificationName:JPVideoPlayerDownloadStopNotification object:self];
            if (!error) {
                [[NSNotificationCenter defaultCenter] postNotificationName:JPVideoPlayerDownloadFinishNotification object:self];
            }
        });
    }
    
    if (!error) {
        if (self.completionBlock) {
            self.completionBlock();
        }
    }
    else{
        dispatch_main_async_safe(^{
            [[NSNotificationCenter defaultCenter] postNotificationName:JPVideoPlayerDownloadStopNotification object:self];
        });
        [self callErrorBlocksWithError:error];
    }
    
    [self done];
}

- (void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task didReceiveChallenge:(NSURLAuthenticationChallenge *)challenge completionHandler:(void (^)(NSURLSessionAuthChallengeDisposition disposition, NSURLCredential *credential))completionHandler {
    
    NSURLSessionAuthChallengeDisposition disposition = NSURLSessionAuthChallengePerformDefaultHandling;
    __block NSURLCredential *credential = nil;
    
    if ([challenge.protectionSpace.authenticationMethod isEqualToString:NSURLAuthenticationMethodServerTrust]) {
        if (!(self.options & JPVideoPlayerDownloaderAllowInvalidSSLCertificates)) {
            disposition = NSURLSessionAuthChallengePerformDefaultHandling;
        } else {
            credential = [NSURLCredential credentialForTrust:challenge.protectionSpace.serverTrust];
            disposition = NSURLSessionAuthChallengeUseCredential;
        }
    } else {
        if (challenge.previousFailureCount == 0) {
            if (self.credential) {
                credential = self.credential;
                disposition = NSURLSessionAuthChallengeUseCredential;
            } else {
                disposition = NSURLSessionAuthChallengeCancelAuthenticationChallenge;
            }
        } else {
            disposition = NSURLSessionAuthChallengeCancelAuthenticationChallenge;
        }
    }
    
    if (completionHandler) {
        completionHandler(disposition, credential);
    }
}

- (void)URLSession:(NSURLSession *)session dataTask:(NSURLSessionDataTask *)dataTask willCacheResponse:(NSCachedURLResponse *)proposedResponse completionHandler:(void (^)(NSCachedURLResponse *cachedResponse))completionHandler {
    
    // If this method is called, it means the response wasn't read from cache
    responseFromCached = NO;
    NSCachedURLResponse *cachedResponse = proposedResponse;
    
    if (self.request.cachePolicy == NSURLRequestReloadIgnoringLocalCacheData) {
        // Prevents caching of responses
        cachedResponse = nil;
    }
    if (completionHandler) {
        completionHandler(cachedResponse);
    }
}


#pragma mark - Private

- (void)cancelInternal {
    if (self.isFinished) return;
    [super cancel];
    
    if (self.dataTask) {
        [self.dataTask cancel];
        dispatch_main_async_safe(^{
            [[NSNotificationCenter defaultCenter] postNotificationName:JPVideoPlayerDownloadStopNotification object:self];
        });
        
        // As we cancelled the connection, its callback won't be called and thus won't
        // maintain the isFinished and isExecuting flags.
        if (self.isExecuting) self.executing = NO;
        if (!self.isFinished) self.finished = YES;
    }
    
    [self reset];
}

- (void)done {
    self.finished = YES;
    self.executing = NO;
    [self reset];
}

- (void)callErrorBlocksWithError:(nullable NSError *)error {
    NSArray<id> *errorBlocks = [self callbacksForKey:kErrorCallbackKey];
    dispatch_main_async_safe(^{
        for (JPVideoPlayerDownloaderErrorBlock errorBlock in errorBlocks) {
            errorBlock(error);
        }
    });
}

- (nullable NSArray<id> *)callbacksForKey:(NSString *)key {
    
    __block NSMutableArray<id> *callbacks = nil;
    
    dispatch_sync(self.barrierQueue, ^{
        callbacks = [[self.callbackBlocks valueForKey:key] mutableCopy];
        [callbacks removeObjectIdenticalTo:[NSNull null]];
    });
    return [callbacks copy];    // strip mutability here
}

- (BOOL)shouldContinueWhenAppEntersBackground {
    return self.options & JPVideoPlayerDownloaderContinueInBackground;
}

- (void)reset {
    dispatch_barrier_async(self.barrierQueue, ^{
        [self.callbackBlocks removeAllObjects];
    });
    self.dataTask = nil;
    if (self.ownedSession) {
        [self.ownedSession invalidateAndCancel];
        self.ownedSession = nil;
    }
}

- (void)setFinished:(BOOL)finished {
    [self willChangeValueForKey:@"isFinished"];
    _finished = finished;
    [self didChangeValueForKey:@"isFinished"];
}

- (void)setExecuting:(BOOL)executing {
    [self willChangeValueForKey:@"isExecuting"];
    _executing = executing;
    [self didChangeValueForKey:@"isExecuting"];
}

- (BOOL)isConcurrent {
    return YES;
}

@end
