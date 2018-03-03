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

#import "JPVideoPlayerResourceLoader.h"
#import "JPVideoPlayerCompat.h"
#import "JPVideoPlayerCacheFile.h"
#import "JPVideoPlayerCachePath.h"
#import "JPVideoPlayerManager.h"
#import "JPResourceLoadingRequestTask.h"
#import "JPVideoPlayerSupportUtils.h"

@interface JPVideoPlayerResourceLoader()<JPResourceLoadingRequestTaskDelegate>

/**
 * The request queues.
 * It save the requests waiting for being given video data.
 */
@property (nonatomic, strong, nullable)NSMutableArray<AVAssetResourceLoadingRequest *> *pendingRequests;

@property (nonatomic, strong) JPVideoPlayerCacheFile *cacheFile;

@property (nonatomic, strong) NSHTTPURLResponse *response;

@property (nonatomic, strong) JPResourceLoadingRequestTask *requestTask;

@property (nonatomic, strong) NSOperationQueue *operationQueue;

@end

static const NSString *const kJPVideoPlayerContentRangeKey = @"Content-Range";
@implementation JPVideoPlayerResourceLoader

- (void)dealloc {
    [self.operationQueue cancelAllOperations];
}

- (instancetype)init {
    NSAssert(NO, @"Please use given initialize method.");
    return [self initWithCustomURL:[NSURL new]];
}

+ (instancetype)resourceLoaderWithCustomURL:(NSURL *)customURL {
    return [[JPVideoPlayerResourceLoader alloc] initWithCustomURL:customURL];
}

- (instancetype)initWithCustomURL:(NSURL *)customURL {
    NSParameterAssert(customURL);
    if(!customURL){
        return nil;
    }

    self = [super init];
    if(self){
        _customURL = customURL;
        _pendingRequests = [@[] mutableCopy];
        _operationQueue = [NSOperationQueue new];
        _operationQueue.maxConcurrentOperationCount = 1;
        NSString *key = [JPVideoPlayerManager.sharedManager cacheKeyForURL:customURL];
        _cacheFile = [JPVideoPlayerCacheFile cacheFileWithFilePath:[JPVideoPlayerCachePath videoCacheTemporaryPathForKey:key]
                                                     indexFilePath:[JPVideoPlayerCachePath videoCacheIndexSavePathForKey:key]];
        [_operationQueue addObserver:self 
                          forKeyPath:@"operationCount" 
                             options:NSKeyValueObservingOptionNew 
                             context:nil];
    }
    return self;
}


#pragma mark - KVO

- (void)observeValueForKeyPath:(nullable NSString *)keyPath 
                      ofObject:(nullable id)object
                        change:(nullable NSDictionary<NSKeyValueChangeKey, id> *)change 
                       context:(nullable void *)context {
    if([keyPath isEqualToString:@"operationCount"]){
        JPDebugLog(@"operationCount 发生变化: %d", self.operationQueue.operationCount);
    }
}


#pragma mark - AVAssetResourceLoaderDelegate

- (BOOL)resourceLoader:(AVAssetResourceLoader *)resourceLoader
shouldWaitForLoadingOfRequestedResource:(AVAssetResourceLoadingRequest *)loadingRequest{
    if (resourceLoader && loadingRequest){
        [self.pendingRequests addObject:loadingRequest];
        JPDebugLog(@"ResourceLoader 接收到新的请求, 当前请求数: %ld <<<<<<<<<", self.pendingRequests.count);
        if (self.requestTask.loadingRequest && !self.requestTask.loadingRequest.isFinished) {
            [self cancelCurrentRequest:YES];
        }
        [self findAndStartNextRequestIfNeed];
    }
    return YES;
}

- (void)resourceLoader:(AVAssetResourceLoader *)resourceLoader
didCancelLoadingRequest:(AVAssetResourceLoadingRequest *)loadingRequest{
    if (self.requestTask.loadingRequest == loadingRequest) {
        JPDebugLog(@"ResourceLoader 取消了一个正在请求的请求");
        [self cancelCurrentRequest:NO];
    }
    else {
        JPDebugLog(@"ResourceLoader 取消了一个不在请求的请求");
        [self.pendingRequests removeObject:loadingRequest];
    }
}


#pragma mark - Private

- (void)findAndStartNextRequestIfNeed {
    if (self.requestTask.loadingRequest || self.pendingRequests.count == 0) {
        return;
    }

    AVAssetResourceLoadingRequest *loadingRequest = [self.pendingRequests firstObject];
    NSUInteger location, length;
    // data range.
    if ([loadingRequest.dataRequest respondsToSelector:@selector(requestsAllDataToEndOfResource)] && loadingRequest.dataRequest.requestsAllDataToEndOfResource) {
        location = (NSUInteger)loadingRequest.dataRequest.requestedOffset;
        length = NSUIntegerMax;
    }
    else {
        location = (NSUInteger)loadingRequest.dataRequest.requestedOffset;
        length = loadingRequest.dataRequest.requestedLength;
    }
    if(loadingRequest.dataRequest.currentOffset > 0){
       location = loadingRequest.dataRequest.currentOffset;
    }
    NSRange dataRange = NSMakeRange(location, length);

    // response.
    if (!self.response && self.cacheFile.responseHeaders.count > 0) {
        if (dataRange.length == NSUIntegerMax) {
            dataRange.length = [self.cacheFile fileLength] - dataRange.location;
        }

        NSMutableDictionary *responseHeaders = [self.cacheFile.responseHeaders mutableCopy];
        BOOL supportRange = responseHeaders[kJPVideoPlayerContentRangeKey] != nil;
        if (supportRange && JPValidByteRange(dataRange)) {
            responseHeaders[kJPVideoPlayerContentRangeKey] = JPRangeToHTTPRangeReponseHeader(dataRange, [self.cacheFile fileLength]);
        }
        else {
            [responseHeaders removeObjectForKey:kJPVideoPlayerContentRangeKey];
        }
        responseHeaders[@"Content-Length"] = [NSString stringWithFormat:@"%tu", dataRange.length];
        NSInteger statusCode = supportRange ? 206 : 200;
        self.response = [[NSHTTPURLResponse alloc] initWithURL:loadingRequest.request.URL
                                                    statusCode:statusCode
                                                   HTTPVersion:@"HTTP/1.1"
                                                  headerFields:responseHeaders];
        [loadingRequest jp_fillContentInformationWithResponse:self.response];
    }
    [self startCurrentRequestWithLoadingRequest:loadingRequest
                                          range:dataRange];
}

- (void)startCurrentRequestWithLoadingRequest:(AVAssetResourceLoadingRequest *)loadingRequest
                                        range:(NSRange)dataRange {
    JPDebugLog(@"ResourceLoader 处理新的请求, 数据范围是: %@", NSStringFromRange(dataRange));
    self.operationQueue.suspended = YES;
    if (dataRange.length == NSUIntegerMax) {
        [self addTaskWithLoadingRequest:loadingRequest
                                  range:NSMakeRange(dataRange.location, NSUIntegerMax)
                                 cached:NO];
    }
    else {
        NSUInteger start = dataRange.location;
        NSUInteger end = NSMaxRange(dataRange);
        while (start < end) {
            NSRange firstNotCachedRange = [self.cacheFile firstNotCachedRangeFromPosition:start];
            if (!JPValidFileRange(firstNotCachedRange)) {
                [self addTaskWithLoadingRequest:loadingRequest
                                          range:dataRange
                                         cached:self.cacheFile.cachedDataBound > 0];
                start = end;
            }
            else if (firstNotCachedRange.location >= end) {
                [self addTaskWithLoadingRequest:loadingRequest
                                          range:dataRange
                                         cached:YES];
                start = end;
            }
            else if (firstNotCachedRange.location >= start) {
                if (firstNotCachedRange.location > start) {
                    [self addTaskWithLoadingRequest:loadingRequest
                                              range:NSMakeRange(start, firstNotCachedRange.location - start)
                                             cached:YES];
                }
                NSUInteger notCachedEnd = MIN(NSMaxRange(firstNotCachedRange), end);
                [self addTaskWithLoadingRequest:loadingRequest
                                          range:NSMakeRange(firstNotCachedRange.location, notCachedEnd - firstNotCachedRange.location)
                                         cached:NO];
                start = notCachedEnd;
            }
            else {
                [self addTaskWithLoadingRequest:loadingRequest
                                          range:dataRange
                                         cached:YES];
                start = end;
            }
        }
    }
    self.operationQueue.suspended = NO;
}

- (void)addTaskWithLoadingRequest:(AVAssetResourceLoadingRequest *)loadingRequest
                            range:(NSRange)range
                           cached:(BOOL)cached {
    JPResourceLoadingRequestTask *task;
    if(cached){
        JPDebugLog(@"ResourceLoader 创建了一个本地请求");
        task = [JPResourceLoadingRequestLocalTask requestTaskWithLoadingRequest:loadingRequest
                                                                   requestRange:range
                                                                      cacheFile:self.cacheFile
                                                                      customURL:self.customURL
                                                                         cached:cached];
    }
    else {
        JPDebugLog(@"ResourceLoader 创建一个网络请求");
        task = [JPResourceLoadingRequestWebTask requestTaskWithLoadingRequest:loadingRequest
                                                                 requestRange:range
                                                                    cacheFile:self.cacheFile
                                                                    customURL:self.customURL
                                                                       cached:cached];
        ((JPResourceLoadingRequestWebTask *)task).response = self.response;
        if (self.delegate && [self.delegate respondsToSelector:@selector(resourceLoader:didReceiveLoadingRequestTask:)]) {
            [self.delegate resourceLoader:self didReceiveLoadingRequestTask:task];
        }
    }
    task.delegate = self;
    self.requestTask = task;
    [self.operationQueue addOperation:task];
}

- (void)removeCurrentRequestTaskAnResetAll {
    [self.pendingRequests removeObject:self.requestTask.loadingRequest];
    self.response = nil;
    self.requestTask = nil;
}


#pragma mark - JPResourceLoadingRequestTaskDelegate

- (void)requestTask:(JPResourceLoadingRequestTask *)requestTask
didCompleteWithError:(NSError *)error {
    if (requestTask.isCancelled || error.code == NSURLErrorCancelled) {
        return;
    }

    if (error) {
        [self finishCurrentRequestWithError:error];
    }
    else {
        if(self.operationQueue.operationCount == 1 || self.operationQueue.operationCount == 0){
            [self finishCurrentRequestWithError:nil];
        }
    }
}


#pragma mark - Finish Request

- (void)finishCurrentRequestWithError:(NSError *)error {
    if (error) {
        JPDebugLog(@"ResourceLoader 完成一个请求 error: %@", error);
        [self.requestTask.loadingRequest finishLoadingWithError:error];
    }
    else {
        JPDebugLog(@"ResourceLoader 完成一个请求, 没有错误");
        [self.requestTask.loadingRequest finishLoading];
    }
    [self removeCurrentRequestTaskAnResetAll];
    [self findAndStartNextRequestIfNeed];
}

- (void)cancelCurrentRequest:(BOOL)finishCurrentRequest {
    if (!self.requestTask) {
        return;
    }

    [self.operationQueue cancelAllOperations];
    JPDebugLog(@"ResourceLoader 取消了所有请求");
    if (finishCurrentRequest) {
        if (!self.requestTask.loadingRequest.isFinished) {
            // Cancel current request task, and then receive message on `requestTask:didCompleteWithError:`
            // to start next request.
            NSError *error = [NSError errorWithDomain:NSURLErrorDomain
                                                 code:NSURLErrorCancelled
                                             userInfo:nil];
            [self finishCurrentRequestWithError:error];
        }
    }
    else {
        [self.requestTask.loadingRequest finishLoading];
        [self removeCurrentRequestTaskAnResetAll];
    }
}

@end
