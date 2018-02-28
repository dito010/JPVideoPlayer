//
// Created by NewPan on 2018/2/22.
// Copyright (c) 2018 NewPan. All rights reserved.
//

#import "JPResourceLoadingRequestTask.h"
#import "JPVideoPlayerCacheFile.h"
#import "JPVideoPlayerSupportUtils.h"

@interface JPResourceLoadingRequestTask()

@property (assign, nonatomic) UIBackgroundTaskIdentifier backgroundTaskId;

/**
 * The operation's task.
 */
@property (strong, nonatomic) NSURLSessionDataTask *dataTask;

@property (assign, nonatomic, getter = isExecuting) BOOL executing;

@property (assign, nonatomic, getter = isFinished) BOOL finished;

@end

static NSUInteger kJPVideoPlayerFileReadBufferSize = 1024 * 32;
@implementation JPResourceLoadingRequestTask
@synthesize executing = _executing;
@synthesize finished = _finished;

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
    }
    return self;
}

+ (instancetype)requestTaskWithLoadingRequest:(AVAssetResourceLoadingRequest *)loadingRequest
                                 requestRange:(NSRange)requestRange
                                    cacheFile:(JPVideoPlayerCacheFile *)cacheFile
                                    customURL:(NSURL *)customURL
                                       cached:(BOOL)cached {
    return [[[self class] alloc] initWithLoadingRequest:loadingRequest
                                           requestRange:requestRange
                                              cacheFile:cacheFile
                                              customURL:customURL
                                                 cached:cached];
}

- (void)requestDidCompleteWithError:(NSError *_Nullable)error {
    JPDispatchSyncOnMainQueue(^{
        if (self.delegate && [self.delegate respondsToSelector:@selector(requestTask:didCompleteWithError:)]) {
            [self.delegate requestTask:self didCompleteWithError:error];
        }
        [self setExecuting:NO];
        [self setFinished:YES];
    });
}

- (void)cancel {
    [super cancel];
    [self requestDidCompleteWithError:nil];
    JPDebugLog(@"调用了 JPResourceLoadingRequestTask 的取消方法");
}


#pragma mark - Private

- (NSString *)internalFetchUUID {
    CFUUIDRef uuidRef = CFUUIDCreate(NULL);
    CFStringRef uuidStringRef = CFUUIDCreateString(NULL, uuidRef);
    CFRelease(uuidRef);

    NSString *uuidValue = (__bridge_transfer NSString *)uuidStringRef;
    uuidValue = [uuidValue lowercaseString];
    uuidValue = [uuidValue stringByReplacingOccurrencesOfString:@"-" withString:@""];
    return uuidValue;
}

- (void)main {
    @autoreleasepool {
        [self setFinished:NO];
        [self setExecuting:YES];
        [self requestDidCompleteWithError:nil];
    }
}

- (BOOL)shouldContinueWhenAppEntersBackground {
    return self.options & JPVideoPlayerDownloaderContinueInBackground;
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

@end

@implementation JPResourceLoadingRequestLocalTask

- (void)main {
    if ([self isCancelled]) {
        [self requestDidCompleteWithError:nil];
        return;
    }

    JPDebugLog(@"开始发送本地请求");
    [self setFinished:NO];
    [self setExecuting:YES];
    // task fetch data from disk.
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
    [self requestDidCompleteWithError:nil];
}

@end

@implementation JPResourceLoadingRequestWebTask

- (void)main {
    if ([self isCancelled]) {
        [self requestDidCompleteWithError:nil];
        return;
    }

    // task request data from web.
    NSParameterAssert(self.unownedSession);
    NSParameterAssert(self.request);
    if(!self.unownedSession || !self.request){
        [self requestDidCompleteWithError:nil];
        return;
    }

    JPDebugLog(@"开始网络请求");
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

    [self setFinished:NO];
    [self setExecuting:YES];
    NSURLSession *session = self.unownedSession;
    self.dataTask = [session dataTaskWithRequest:self.request];
    self.dataTask.webTask = self;
    JPDebugLog(@"网络请求创建一个 dataTask, id 是: %d", self.dataTask.taskIdentifier);
    [self.dataTask resume];

    if (self.dataTask) {
        JPDispatchSyncOnMainQueue(^{
            [[NSNotificationCenter defaultCenter] postNotificationName:JPVideoPlayerDownloadStartNotification object:self];
        });
    }

    if (self.backgroundTaskId != UIBackgroundTaskInvalid) {
        UIApplication * app = [UIApplication performSelector:@selector(sharedApplication)];
        [app endBackgroundTask:self.backgroundTaskId];
        self.backgroundTaskId = UIBackgroundTaskInvalid;
    }
}

- (void)cancel {
    if (self.isCancelled || self.isFinished) {
        return;
    }
    
    [super cancel];
    if (self.dataTask) {
        // cancel web request.
        JPDebugLog(@"取消了一个网络请求, id 是: %d", self.dataTask.taskIdentifier);
        [self.dataTask cancel];
        JPDispatchSyncOnMainQueue(^{
            [[NSNotificationCenter defaultCenter] postNotificationName:JPVideoPlayerDownloadStopNotification object:self];
        });
    }
}

@end
