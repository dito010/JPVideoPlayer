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

#import "JPResourceLoadingRequestTask.h"
#import "JPVideoPlayerCacheFile.h"
#import "JPVideoPlayerSupportUtils.h"
#import <pthread.h>
#import "JPVideoPlayerCompat.h"

@interface JPResourceLoadingRequestTask()

@property (nonatomic, assign, getter = isExecuting) BOOL executing;

@property (nonatomic, assign, getter = isFinished) BOOL finished;

@property (nonatomic, assign, getter = isCancelled) BOOL cancelled;

@property (nonatomic) pthread_mutex_t lock;

@end

static NSUInteger kJPVideoPlayerFileReadBufferSize = 1024 * 32;
static const NSString *const kJPVideoPlayerContentRangeKey = @"Content-Range";
@implementation JPResourceLoadingRequestTask

- (void)dealloc {
    pthread_mutex_destroy(&_lock);
}

- (instancetype)init {
    NSAssert(NO, @"Please use given initialize method.");
    return [self initWithLoadingRequest:(AVAssetResourceLoadingRequest *)[NSURLRequest new]
                           requestRange:JPInvalidRange
                              cacheFile:[JPVideoPlayerCacheFile new]
                              customURL:[NSURL new]
                                 cached:NO];
}

- (instancetype)initWithLoadingRequest:(AVAssetResourceLoadingRequest *)loadingRequest
                          requestRange:(NSRange)requestRange
                             cacheFile:(JPVideoPlayerCacheFile *)cacheFile
                             customURL:(NSURL *)customURL
                                cached:(BOOL)cached {
    NSParameterAssert(loadingRequest);
    NSParameterAssert(JPValidByteRange(requestRange));
    NSParameterAssert(cacheFile);
    NSParameterAssert(customURL);
    if(!loadingRequest || !JPValidByteRange(requestRange) || !cacheFile || !customURL){
        return nil;
    }

    self = [super init];
    if(self){
        _loadingRequest = loadingRequest;
        _requestRange = requestRange;
        _cacheFile = cacheFile;
        _customURL = customURL;
        _cached = cached;
        _executing = NO;
        _cancelled = NO;
        _finished = NO;
        pthread_mutexattr_t mutexattr;
        pthread_mutexattr_init(&mutexattr);
        pthread_mutexattr_settype(&mutexattr, PTHREAD_MUTEX_RECURSIVE);
        pthread_mutex_init(&_lock, &mutexattr);
    }
    return self;
}

+ (instancetype)requestTaskWithLoadingRequest:(AVAssetResourceLoadingRequest *)loadingRequest
        requestRange:(NSRange)requestRange
        cacheFile:(JPVideoPlayerCacheFile *)cacheFile
        customURL:(NSURL *)customURL
        cached:(BOOL)cached {
    return [[self.class alloc] initWithLoadingRequest:loadingRequest
                                         requestRange:requestRange
                                            cacheFile:cacheFile
                                            customURL:customURL
                                               cached:cached];
}

- (void)requestDidReceiveResponse:(NSURLResponse *)response {
    NSAssert(NO, @"You must subclass this class and override this method");
}

- (void)requestDidReceiveData:(NSData *)data
             storedCompletion:(dispatch_block_t)completion {
    NSAssert(NO, @"You must subclass this class and override this method");
}

- (void)requestDidCompleteWithError:(NSError *_Nullable)error {
    JPDispatchSyncOnMainQueue(^{
        self.executing = NO;
        self.finished = YES;
        if (self.delegate && [self.delegate respondsToSelector:@selector(requestTask:didCompleteWithError:)]) {
            [self.delegate requestTask:self didCompleteWithError:error];
        }
    });
}

- (void)start {
    int lock = pthread_mutex_trylock(&_lock);;
    self.executing = YES;
    if (!lock) {
        pthread_mutex_unlock(&_lock);
    }
}

- (void)startOnQueue:(dispatch_queue_t)queue {
    dispatch_async(queue, ^{
        int lock = pthread_mutex_trylock(&_lock);;
        self.executing = YES;
        if (!lock) {
            pthread_mutex_unlock(&_lock);
        }
    });
}

- (void)cancel {
    JPDebugLog(@"调用了 RequestTask 的取消方法");
    int lock = pthread_mutex_trylock(&_lock);;
    self.executing = NO;
    self.cancelled = YES;
    if (!lock) {
        pthread_mutex_unlock(&_lock);
    }
}


#pragma mark - Private

- (void)setFinished:(BOOL)finished {
    [self willChangeValueForKey:@"isFinished"];
    _finished = finished;
    [self didChangeValueForKey:@"isFinished"];
}

- (void)setCancelled:(BOOL)cancelled {
    [self willChangeValueForKey:@"isCancelled"];
    _cancelled = cancelled;
    [self didChangeValueForKey:@"isCancelled"];
}

- (void)setExecuting:(BOOL)executing {
    [self willChangeValueForKey:@"isExecuting"];
    _executing = executing;
    [self didChangeValueForKey:@"isExecuting"];
}

- (NSString *)internalFetchUUID {
    CFUUIDRef uuidRef = CFUUIDCreate(NULL);
    CFStringRef uuidStringRef = CFUUIDCreateString(NULL, uuidRef);
    CFRelease(uuidRef);

    NSString *uuidValue = (__bridge_transfer NSString *)uuidStringRef;
    uuidValue = [uuidValue lowercaseString];
    uuidValue = [uuidValue stringByReplacingOccurrencesOfString:@"-" withString:@""];
    return uuidValue;
}

@end

@interface JPResourceLoadingRequestLocalTask()

@property (nonatomic) pthread_mutex_t plock;

@end

@implementation JPResourceLoadingRequestLocalTask

- (void)dealloc {
    JPDebugLog(@"Local task dealloc");
    pthread_mutex_destroy(&_plock);
}

- (instancetype)initWithLoadingRequest:(AVAssetResourceLoadingRequest *)loadingRequest
                          requestRange:(NSRange)requestRange
                             cacheFile:(JPVideoPlayerCacheFile *)cacheFile
                             customURL:(NSURL *)customURL
                                cached:(BOOL)cached {
    self = [super initWithLoadingRequest:loadingRequest
                            requestRange:requestRange
                               cacheFile:cacheFile
                               customURL:customURL
                                  cached:cached];
    if(self){
        pthread_mutexattr_t mutexattr;
        pthread_mutexattr_init(&mutexattr);
        pthread_mutexattr_settype(&mutexattr, PTHREAD_MUTEX_RECURSIVE);
        pthread_mutex_init(&_plock, &mutexattr);
        if(cacheFile.responseHeaders && !loadingRequest.contentInformationRequest.contentType){
            [self fillContentInformation];
        }
    }
    return self;
}

- (void)startOnQueue:(dispatch_queue_t)queue {
    [super startOnQueue:queue];
    dispatch_async(queue, ^{
        [self internalStart];
    });
}

- (void)start {
    NSAssert(![NSThread isMainThread], @"Do not use main thread when start a local task");
    [super start];
    [self internalStart];
}

- (void)internalStart {
    if ([self isCancelled]) {
        [self requestDidCompleteWithError:nil];
        return;
    }

    JPDebugLog(@"开始响应本地请求");
    // task fetch data from disk.
    int lock = pthread_mutex_trylock(&_plock);
    NSUInteger offset = self.requestRange.location;
    while (offset < NSMaxRange(self.requestRange)) {
        if ([self isCancelled]) {
            break;
        }
        @autoreleasepool {
            NSRange range = NSMakeRange(offset, MIN(NSMaxRange(self.requestRange) - offset, kJPVideoPlayerFileReadBufferSize));
            NSData *data = [self.cacheFile dataWithRange:range];
            [self.loadingRequest.dataRequest respondWithData:data];
            offset = NSMaxRange(range);
        }
    }
    JPDebugLog(@"完成本地请求");
    if (!lock) {
        pthread_mutex_unlock(&_plock);
    }
    [self requestDidCompleteWithError:nil];
}

- (void)fillContentInformation {
    int lock = pthread_mutex_trylock(&_plock);
    NSMutableDictionary *responseHeaders = [self.cacheFile.responseHeaders mutableCopy];
    BOOL supportRange = responseHeaders[kJPVideoPlayerContentRangeKey] != nil;
    if (supportRange && JPValidByteRange(self.requestRange)) {
        NSUInteger fileLength = [self.cacheFile fileLength];
        NSString *contentRange = [NSString stringWithFormat:@"bytes %tu-%tu/%tu", self.requestRange.location, fileLength, fileLength];
        responseHeaders[kJPVideoPlayerContentRangeKey] = contentRange;
    }
    else {
        [responseHeaders removeObjectForKey:kJPVideoPlayerContentRangeKey];
    }
    NSUInteger contentLength = self.requestRange.length != NSUIntegerMax ? self.requestRange.length : self.cacheFile.fileLength - self.requestRange.location;
    responseHeaders[@"Content-Length"] = [NSString stringWithFormat:@"%tu", contentLength];
    NSInteger statusCode = supportRange ? 206 : 200;
    NSHTTPURLResponse *response = [[NSHTTPURLResponse alloc] initWithURL:self.loadingRequest.request.URL
                                                              statusCode:statusCode
                                                             HTTPVersion:@"HTTP/1.1"
                                                            headerFields:responseHeaders];
    [self.loadingRequest jp_fillContentInformationWithResponse:response];
    if (!lock) {
        pthread_mutex_unlock(&_plock);
    }
}

@end

@interface JPResourceLoadingRequestWebTask()

@property (assign, nonatomic) UIBackgroundTaskIdentifier backgroundTaskId;

@property (strong, nonatomic) NSURLSessionDataTask *dataTask;

@property(nonatomic, assign) NSUInteger offset;

@property(nonatomic, assign) NSUInteger requestLength;

@property(nonatomic, assign) BOOL haveDataSaved;

@property (nonatomic) pthread_mutex_t plock;

@end

@implementation JPResourceLoadingRequestWebTask

- (void)dealloc {
    JPDebugLog(@"Web task dealloc: %@", self);
    pthread_mutex_destroy(&_plock);
}

- (instancetype)initWithLoadingRequest:(AVAssetResourceLoadingRequest *)loadingRequest
                          requestRange:(NSRange)requestRange
                             cacheFile:(JPVideoPlayerCacheFile *)cacheFile
                             customURL:(NSURL *)customURL
                                cached:(BOOL)cached {
    NSParameterAssert(JPValidByteRange(requestRange));
    self = [super initWithLoadingRequest:loadingRequest
                            requestRange:requestRange
                               cacheFile:cacheFile
                               customURL:customURL
                                  cached:cached];
    if(self){
        pthread_mutexattr_t mutexattr;
        pthread_mutexattr_init(&mutexattr);
        pthread_mutexattr_settype(&mutexattr, PTHREAD_MUTEX_RECURSIVE);
        pthread_mutex_init(&_plock, &mutexattr);
        _haveDataSaved = NO;
        _offset = requestRange.location;
        _requestLength = requestRange.length;
    }
    return self;
}

- (void)start {
    [super start];
    JPDispatchSyncOnMainQueue(^{
        [self internalStart];
    });
}

- (void)startOnQueue:(dispatch_queue_t)queue {
    [super startOnQueue:queue];
    dispatch_async(queue, ^{
        [self internalStart];
    });
}

- (void)cancel {
    if (self.isCancelled || self.isFinished) {
        return;
    }
    
    [super cancel];
    [self synchronizeCacheFileIfNeeded];
    if (self.dataTask) {
        // cancel web request.
        JPDebugLog(@"取消了一个网络请求, id 是: %d", self.dataTask.taskIdentifier);
        [self.dataTask cancel];
        JPDispatchSyncOnMainQueue(^{
            [[NSNotificationCenter defaultCenter] postNotificationName:JPVideoPlayerDownloadStopNotification object:self];
        });
    }
}

- (BOOL)shouldContinueWhenAppEntersBackground {
    return self.options & JPVideoPlayerDownloaderContinueInBackground;
}

- (void)internalStart {
    // task request data from web.
    NSParameterAssert(self.unownedSession);
    NSParameterAssert(self.request);
    if(!self.unownedSession || !self.request){
        [self requestDidCompleteWithError:JPErrorWithDescription(@"unownedSession or request can not be nil")];
        return;
    }
    
    if ([self isCancelled]) {
        [self requestDidCompleteWithError:nil];
        return;
    }

    __weak __typeof__ (self) wself = self;
    Class UIApplicationClass = NSClassFromString(@"UIApplication");
    BOOL hasApplication = UIApplicationClass && [UIApplicationClass respondsToSelector:@selector(sharedApplication)];
    if (hasApplication && [self shouldContinueWhenAppEntersBackground]) {
        UIApplication * app = [UIApplicationClass performSelector:@selector(sharedApplication)];
        self.backgroundTaskId = [app beginBackgroundTaskWithExpirationHandler:^{
            __strong __typeof (wself) sself = wself;
            if(!sself) return;
            
            [sself cancel];
            [app endBackgroundTask:sself.backgroundTaskId];
            sself.backgroundTaskId = UIBackgroundTaskInvalid;
        }];
    }
    
    NSURLSession *session = self.unownedSession;
    self.dataTask = [session dataTaskWithRequest:self.request];
    JPDebugLog(@"开始网络请求, 网络请求创建一个 dataTask, id 是: %d", self.dataTask.taskIdentifier);
    [self.dataTask resume];
    if (self.dataTask) {
        [[NSNotificationCenter defaultCenter] postNotificationName:JPVideoPlayerDownloadStartNotification object:self];
    }
    
    if (self.backgroundTaskId != UIBackgroundTaskInvalid) {
        UIApplication * app = [UIApplication performSelector:@selector(sharedApplication)];
        [app endBackgroundTask:self.backgroundTaskId];
        self.backgroundTaskId = UIBackgroundTaskInvalid;
    }
}

- (void)requestDidReceiveResponse:(NSURLResponse *)response {
    if ([response isKindOfClass:[NSHTTPURLResponse class]] && !self.loadingRequest.contentInformationRequest.contentType) {
        NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse *)response;
        [self.cacheFile storeResponse:httpResponse];
        [self.loadingRequest jp_fillContentInformationWithResponse:httpResponse];
        if (![(NSHTTPURLResponse *)response jp_supportRange]) {
            self.offset = 0;
        }
    }
}

- (void)requestDidReceiveData:(NSData *)data
             storedCompletion:(dispatch_block_t)completion {
    if (data.bytes) {
        [self.cacheFile storeVideoData:data
                              atOffset:self.offset
                           synchronize:NO
                      storedCompletion:completion];
        int lock = pthread_mutex_trylock(&_plock);
        self.haveDataSaved = YES;
        self.offset += [data length];
        [self.loadingRequest.dataRequest respondWithData:data];

        static BOOL _needLog = YES;
        if(_needLog) {
            _needLog = NO;
            JPDebugLog(@"收到数据响应, 数据长度为: %u", data.length);
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t) (1.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                _needLog = YES;
            });
        }
        if (!lock) {
            pthread_mutex_unlock(&_plock);
        }
    }
}

- (void)requestDidCompleteWithError:(NSError *_Nullable)error {
    [self synchronizeCacheFileIfNeeded];
    [super requestDidCompleteWithError:error];
}

- (void)synchronizeCacheFileIfNeeded {
    if (self.haveDataSaved) {
        [self.cacheFile synchronize];
    }
}

@end