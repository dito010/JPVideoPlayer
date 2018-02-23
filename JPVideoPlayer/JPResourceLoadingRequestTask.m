//
// Created by NewPan on 2018/2/22.
// Copyright (c) 2018 NewPan. All rights reserved.
//

#import "JPResourceLoadingRequestTask.h"
#import "JPVideoPlayerCacheFile.h"
#import <pthread.h>

@interface JPResourceLoadingRequestTask()

@property (assign, nonatomic) UIBackgroundTaskIdentifier backgroundTaskId;

@property (nonatomic) pthread_mutex_t lock;

/**
 * The operation's task.
 */
@property (strong, nonatomic) NSURLSessionDataTask *dataTask;

@end

@implementation JPResourceLoadingRequestTask

- (void)dealloc {
    pthread_mutex_destroy(&_lock);
}

- (instancetype)init {
    NSAssert(NO, @"Please use given initialize method.");
    return [self initWithLoadingRequest:(AVAssetResourceLoadingRequest *)[NSURLRequest new]
                           requestRange:JPInvalidRange
                              cacheFile:[JPVideoPlayerCacheFile new]
                              customURL:[NSURL new]];
}

- (instancetype)initWithLoadingRequest:(AVAssetResourceLoadingRequest *)loadingRequest
                          requestRange:(NSRange)requestRange
                             cacheFile:(JPVideoPlayerCacheFile *)cacheFile
                             customURL:(NSURL *)customURL {
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
        _cancelled = NO;
        pthread_mutex_init(&(_lock), NULL);
    }
    return self;
}

+ (instancetype)requestTaskWithLoadingRequest:(AVAssetResourceLoadingRequest *)loadingRequest
                                 requestRange:(NSRange)requestRange
                                    cacheFile:(JPVideoPlayerCacheFile *)cacheFile
                                    customURL:(NSURL *)customURL {
    return [[JPResourceLoadingRequestTask alloc] initWithLoadingRequest:loadingRequest
                                                           requestRange:requestRange
                                                              cacheFile:cacheFile
                                                              customURL:customURL];
}

- (void)requestDidCompleteWithError:(NSError *)error {
    if (self.delegate && [self.delegate respondsToSelector:@selector(requestTask:didCompleteWithError:)]) {
        [self.delegate requestTask:self didCompleteWithError:error];
    }
}

- (void)start {
    NSParameterAssert(self.unownedSession);
    NSParameterAssert(self.request);
    if(!self.unownedSession || !self.request){
        return;
    }

    pthread_mutex_lock(&_lock);
    JPLogDebug(@"Start a new request");
    if (self.isCancelled) {
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
    pthread_mutex_unlock(&_lock);
}

- (void)cancel {
    pthread_mutex_lock(&_lock);
    JPLogDebug(@"Cancel current request");
    self.cancelled = YES;
    [self cancelInternal];
    pthread_mutex_unlock(&_lock);
}


#pragma mark - Private

- (void)cancelInternal {
    if (self.dataTask) {
        [self.dataTask cancel];
        JPDispatchSyncOnMainQueue(^{
            [[NSNotificationCenter defaultCenter] postNotificationName:JPVideoPlayerDownloadStopNotification object:self];
        });
    }
}

- (BOOL)shouldContinueWhenAppEntersBackground {
    return self.options & JPVideoPlayerDownloaderContinueInBackground;
}

@end