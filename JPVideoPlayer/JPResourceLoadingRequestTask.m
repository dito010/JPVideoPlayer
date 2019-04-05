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

@interface JPResourceLoadingRequestTask()

@property (nonatomic, assign, getter = isExecuting) BOOL executing;

@property (nonatomic, assign, getter = isFinished) BOOL finished;

@property (nonatomic, assign, getter = isCancelled) BOOL cancelled;

@end

static NSUInteger kJPVideoPlayerFileReadBufferSize = 1024 * 32;
static const NSString *const kJPVideoPlayerContentRangeKey = @"Content-Range";
@implementation JPResourceLoadingRequestTask

+ (instancetype)new {
    NSAssert(NO, @"Please use given initialize method.");
    return nil;
}

- (instancetype)init {
    NSAssert(NO, @"Please use given initialize method.");
    return nil;
}

- (instancetype)initWithLoadingRequest:(AVAssetResourceLoadingRequest *)loadingRequest
                          requestRange:(NSRange)requestRange
                             cacheFile:(JPVideoPlayerCacheFile *)cacheFile
                             customURL:(NSURL *)customURL
                             syncQueue:(dispatch_queue_t)syncQueue
                                cached:(BOOL)cached {
    if(!loadingRequest || !JPValidByteRange(requestRange) || !cacheFile || !customURL || !syncQueue) return nil;

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
        _syncQueue = syncQueue;
    }
    return self;
}

- (void)taskDidCompleteWithError:(NSError *_Nullable)error {
    JPDispatchSyncOnQueue(self.syncQueue, ^{

        self.executing = NO;
        self.finished = YES;

        JPDispatchAsyncOnMainQueue(^{

            if (self.delegate && [self.delegate respondsToSelector:@selector(requestTask:didCompleteWithError:)]) {
                [self.delegate requestTask:self didCompleteWithError:error];
            }

        });

    });
}

- (void)start {
    JPDispatchAsyncOnQueue(self.syncQueue, ^{

        self.executing = YES;

    });
}

- (void)cancel {
    JPDispatchSyncOnQueue(self.syncQueue, ^{

        JPDebugLog(@"调用了 RequestTask 的取消方法");
        self.executing = NO;
        self.cancelled = YES;

    });
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

@end

@interface JPResourceLoadingRequestLocalTask()

@end

@implementation JPResourceLoadingRequestLocalTask

- (instancetype)initWithLoadingRequest:(AVAssetResourceLoadingRequest *)loadingRequest
                          requestRange:(NSRange)requestRange
                             cacheFile:(JPVideoPlayerCacheFile *)cacheFile
                             customURL:(NSURL *)customURL
                             syncQueue:(dispatch_queue_t)syncQueue
                                cached:(BOOL)cached {
    NSAssert(NO, @"请使用指定的初始化方法");
    return nil;
}

- (instancetype)initWithLoadingRequest:(AVAssetResourceLoadingRequest *)loadingRequest
                          requestRange:(NSRange)requestRange
                             cacheFile:(JPVideoPlayerCacheFile *)cacheFile
                             customURL:(NSURL *)customURL
                             syncQueue:(dispatch_queue_t)syncQueue
                               ioQueue:(dispatch_queue_t)ioQueue {
    if (!ioQueue) return nil;
    self = [super initWithLoadingRequest:loadingRequest
                            requestRange:requestRange
                               cacheFile:cacheFile
                               customURL:customURL
                               syncQueue:syncQueue
                                  cached:YES];
    if(self){
        _ioQueue = ioQueue;
        if(cacheFile.responseHeaders && !loadingRequest.contentInformationRequest.contentType){
            [self _fillContentInformation];
        }
    }
    return self;
}

- (void)start {
    JPDispatchAsyncOnQueue(self.ioQueue, ^{

        [super start];
        [self _internalStart];

    });
}

- (void)_internalStart {
    if (!self.isCancelled) {
        JPDebugLog(@"开始响应本地请求");
        // task fetch data from disk.
        NSUInteger offset = self.requestRange.location;
        NSData *data = nil;
        NSRange range;
        while (offset < NSMaxRange(self.requestRange)) {
            @autoreleasepool {
                if ([self isCancelled]) break;
                range = NSMakeRange(offset, MIN(NSMaxRange(self.requestRange) - offset, kJPVideoPlayerFileReadBufferSize));
                data = [self.cacheFile dataWithRange:range];
                NSParameterAssert(data.length == range.length);
                [self.loadingRequest.dataRequest respondWithData:data];
                offset = NSMaxRange(range);
                data = nil;
            }
        }
        JPDebugLog(@"完成本地请求");
    }
    [self taskDidCompleteWithError:nil];
}

- (void)_fillContentInformation {
    @autoreleasepool {
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
    }
}

@end

@interface JPResourceLoadingRequestWebTask()

@property (assign, nonatomic) UIBackgroundTaskIdentifier backgroundTaskId;

@property (strong, nonatomic) NSURLSessionDataTask *dataTask;

@property(nonatomic, assign) NSUInteger offset;

@property(nonatomic, assign) NSUInteger requestLength;

@property(nonatomic, assign) BOOL haveDataSaved;

@end

@implementation JPResourceLoadingRequestWebTask

- (instancetype)initWithLoadingRequest:(AVAssetResourceLoadingRequest *)loadingRequest
                          requestRange:(NSRange)requestRange
                             cacheFile:(JPVideoPlayerCacheFile *)cacheFile
                             customURL:(NSURL *)customURL
                                cached:(BOOL)cached {
    NSAssert(NO, @"请使用指定的初始化方法");
    return nil;
}

- (instancetype)initWithLoadingRequest:(AVAssetResourceLoadingRequest *)loadingRequest
                          requestRange:(NSRange)requestRange
                             cacheFile:(JPVideoPlayerCacheFile *)cacheFile
                             customURL:(NSURL *)customURL
                             syncQueue:(dispatch_queue_t)syncQueue {
    self = [super initWithLoadingRequest:loadingRequest
                            requestRange:requestRange
                               cacheFile:cacheFile
                               customURL:customURL
                               syncQueue:syncQueue
                                  cached:NO];
    if (self) {
        _haveDataSaved = NO;
        _offset = requestRange.location;
        _requestLength = requestRange.length;
    }
    return self;
}

- (void)start {
    JPDispatchAsyncOnQueue(self.syncQueue, ^{

        [super start];
        [self _internalStart];

    });
}

- (void)cancel {
    JPDispatchSyncOnQueue(self.syncQueue, ^{

        if (self.isCancelled || self.isFinished) return;
        [super cancel];
        [self _synchronizeCacheFileIfNeeded];
        if (self.dataTask) {
            // cancel web request.
            JPDebugLog(@"取消了一个网络请求, id 是: %d", self.dataTask.taskIdentifier);
            [self.dataTask cancel];

            JPDispatchAsyncOnMainQueue(^{
                [[NSNotificationCenter defaultCenter] postNotificationName:JPVideoPlayerDownloadStopNotification object:self];
            });
        }

    });
}

- (void)requestDidReceiveResponse:(NSURLResponse *)response {
    JPDispatchSyncOnQueue(self.syncQueue, ^{

        if ([response isKindOfClass:[NSHTTPURLResponse class]] && !self.loadingRequest.contentInformationRequest.contentType) {
            NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse *)response;
            [self.cacheFile storeResponse:httpResponse];
            [self.loadingRequest jp_fillContentInformationWithResponse:httpResponse];
            if (![(NSHTTPURLResponse *)response jp_supportRange]) {
                self.offset = 0;
            }
        }

    });
}

- (void)requestDidReceiveData:(NSData *)data
             storedCompletion:(dispatch_block_t)completion {
    if (!data.bytes) return;

    JPDispatchAsyncOnQueue(self.syncQueue, ^{

        [self.cacheFile storeVideoData:data
                              atOffset:self.offset
                           synchronize:NO
                      storedCompletion:completion];
        self.haveDataSaved = YES;
        self.offset += [data length];
        [self.loadingRequest.dataRequest respondWithData:data];

        static BOOL _needLog = YES;
        static NSUInteger missLogDataLength = 0;
        missLogDataLength += data.length;
        if(_needLog) {
            _needLog = NO;
            JPDebugLog(@"收到数据响应, 数据长度为: %u", missLogDataLength);
            missLogDataLength = 0;
            JPDispatchAsyncOnMainQueue(^{
                JPDispatchAfterTimeIntervalInSecond(1.5, ^{
                    _needLog = YES;
                });
            });
        }

    });
}

- (void)taskDidCompleteWithError:(NSError *_Nullable)error {
    JPDispatchSyncOnMainQueue(^{
        if (self.backgroundTaskId != UIBackgroundTaskInvalid) {
            UIApplication * app = [UIApplication performSelector:@selector(sharedApplication)];
            [app endBackgroundTask:self.backgroundTaskId];
            self.backgroundTaskId = UIBackgroundTaskInvalid;
        }
    });
    JPDispatchSyncOnQueue(self.syncQueue, ^{

        [self _synchronizeCacheFileIfNeeded];
        [super taskDidCompleteWithError:error];

    });
}

- (BOOL)_shouldContinueWhenAppEntersBackground {
    return self.options & JPVideoPlayerDownloaderContinueInBackground;
}

- (void)_internalStart {
    // task request data from web.
    if(!self.unownedSession || !self.request){
        [self taskDidCompleteWithError:JPErrorWithDescription(@"unownedSession or request can not be nil")];
        return;
    }

    if ([self isCancelled]) {
        [self taskDidCompleteWithError:nil];
        return;
    }

    JPDispatchSyncOnMainQueue(^{
        __weak __typeof__ (self) wself = self;
        Class UIApplicationClass = NSClassFromString(@"UIApplication");
        BOOL hasApplication = UIApplicationClass && [UIApplicationClass respondsToSelector:@selector(sharedApplication)];
        if (hasApplication && [self _shouldContinueWhenAppEntersBackground]) {
            UIApplication * app = [UIApplicationClass performSelector:@selector(sharedApplication)];
            self.backgroundTaskId = [app beginBackgroundTaskWithExpirationHandler:^{
                __strong __typeof (wself) sself = wself;
                if(!sself) return;

                [sself cancel];
                [app endBackgroundTask:sself.backgroundTaskId];
                sself.backgroundTaskId = UIBackgroundTaskInvalid;
            }];
        }
    });

    NSURLSession *session = self.unownedSession;
    self.dataTask = [session dataTaskWithRequest:self.request];
    JPDebugLog(@"开始网络请求, 网络请求创建一个 dataTask, id 是: %d", self.dataTask.taskIdentifier);
    [self.dataTask resume];
    if (self.dataTask) {
        JPDispatchAsyncOnMainQueue(^{

            [[NSNotificationCenter defaultCenter] postNotificationName:JPVideoPlayerDownloadStartNotification object:self];

        });
    }
}

- (void)_synchronizeCacheFileIfNeeded {
    if (self.haveDataSaved) {
        [self.cacheFile synchronize];
    }
}

@end