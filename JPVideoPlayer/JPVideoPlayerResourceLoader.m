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
    }
    return self;
}


#pragma mark - AVAssetResourceLoaderDelegate

- (BOOL)resourceLoader:(AVAssetResourceLoader *)resourceLoader
shouldWaitForLoadingOfRequestedResource:(AVAssetResourceLoadingRequest *)loadingRequest{
    if (resourceLoader && loadingRequest){
        [self.pendingRequests addObject:loadingRequest];
        JPDebugLog(@"ResourceLoader received a new loadingRequest, current loadingRequest number is: %ld", self.pendingRequests.count);
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
        JPDebugLog(@"ResourceLoader cancel a loading Request that loading");
        [self cancelCurrentRequest:NO];
    }
    else {
        JPDebugLog(@"ResourceLoader remove a loading Request that not loading");
        [self.pendingRequests removeObject:loadingRequest];
    }
}


#pragma mark - Private

- (void)findAndStartNextRequestIfNeed {
    if (self.requestTask.loadingRequest || self.pendingRequests.count == 0) {
        return;
    }

    AVAssetResourceLoadingRequest *loadingRequest = [self.pendingRequests firstObject];
    NSRange dataRange;
    // data range.
    if ([loadingRequest.dataRequest respondsToSelector:@selector(requestsAllDataToEndOfResource)] && loadingRequest.dataRequest.requestsAllDataToEndOfResource) {
        dataRange = NSMakeRange((NSUInteger)loadingRequest.dataRequest.requestedOffset, NSUIntegerMax);
    }
    else {
        dataRange = NSMakeRange((NSUInteger)loadingRequest.dataRequest.requestedOffset, loadingRequest.dataRequest.requestedLength);
    }

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
    JPDebugLog(@"Resource loader handle loadingRequest, dataRange is: %@", NSStringFromRange(dataRange));
    self.operationQueue.suspended = YES;
    JPDebugLog(@"Resource loader operation queue is suspended, the operation count is: %d", self.operationQueue.operationCount);
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
                JPDebugLog(@"Never cached for dataRange, request data from web, while circle over, dataRange is: %@", NSStringFromRange(dataRange));
                [self addTaskWithLoadingRequest:loadingRequest
                                          range:dataRange
                                         cached:self.cacheFile.cachedDataBound > 0];
                start = end;
            }
            else if (firstNotCachedRange.location >= end) {
                JPDebugLog(@"All data did cache for dataRange, fetch data from disk, while circle over, dataRange is: %@", NSStringFromRange(dataRange));
                [self addTaskWithLoadingRequest:loadingRequest
                                          range:dataRange
                                         cached:YES];
                start = end;
            }
            else if (firstNotCachedRange.location >= start) {
                if (firstNotCachedRange.location > start) {
                    JPDebugLog(@"Part of the data did cache for dataRange, fetch data from disk, dataRange is: %@", NSStringFromRange(NSMakeRange(start, firstNotCachedRange.location - start)));
                    [self addTaskWithLoadingRequest:loadingRequest
                                              range:NSMakeRange(start, firstNotCachedRange.location - start)
                                             cached:YES];
                }
                NSUInteger notCachedEnd = MIN(NSMaxRange(firstNotCachedRange), end);
                JPDebugLog(@"Part of the data did not cache for dataRange, request data from web, while circle over, dataRange is: %@", NSStringFromRange(NSMakeRange(firstNotCachedRange.location, notCachedEnd - firstNotCachedRange.location)));
                [self addTaskWithLoadingRequest:loadingRequest
                                          range:NSMakeRange(firstNotCachedRange.location, notCachedEnd - firstNotCachedRange.location)
                                         cached:NO];
                start = notCachedEnd;
            }
            else {
                JPDebugLog(@"Other situation for creating task, while circle over, dataRange is: %@", NSStringFromRange(dataRange));
                [self addTaskWithLoadingRequest:loadingRequest
                                          range:dataRange
                                         cached:YES];
                start = end;
            }
        }
    }
    self.operationQueue.suspended = NO;
    JPDebugLog(@"Resource loader operation queue is played, the operation count is: %d", self.operationQueue.operationCount);
}

- (void)addTaskWithLoadingRequest:(AVAssetResourceLoadingRequest *)loadingRequest
                            range:(NSRange)range
                           cached:(BOOL)cached {
    JPResourceLoadingRequestTask *task;
    if(cached){
        JPDebugLog(@"Creat a local request task");
        task = [JPResourceLoadingRequestLocalTask requestTaskWithLoadingRequest:loadingRequest
                                                                   requestRange:range
                                                                      cacheFile:self.cacheFile
                                                                      customURL:self.customURL
                                                                         cached:cached];
    }
    else {
        JPDebugLog(@"Creat a web request task");
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
    JPDebugLog(@"Resource loader add a operations, the operation count is: %d", self.operationQueue.operationCount);
}

- (void)removeCurrentRequestTaskAnResetAll {
    [self.pendingRequests removeObject:self.requestTask.loadingRequest];
    self.response = nil;
    self.requestTask = nil;
    JPDebugLog(@"Remove current request task, current loadingRequest number is: %ld", self.pendingRequests.count);
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
        JPDebugLog(@"Finish loading request with error: %@", error);
        [self.requestTask.loadingRequest finishLoadingWithError:error];
    }
    else {
        JPDebugLog(@"Finish loading request with no error");
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
    JPDebugLog(@"Resource loader call cancel all operations, the operation count is: %d", self.operationQueue.operationCount);
    if (finishCurrentRequest) {
        if (!self.requestTask.isFinished) {
            // Cancel current request task, and then receive message on `requestTask:didCompleteWithError:`
            // to start next request.
            NSError *error = [NSError errorWithDomain:NSURLErrorDomain
                                                 code:NSURLErrorCancelled
                                             userInfo:nil];
            JPDebugLog(@"Downloader cancel the current task, then resource loader send new task");
            [self finishCurrentRequestWithError:error];
        }
    } else {
        [self removeCurrentRequestTaskAnResetAll];
    }
}

@end
