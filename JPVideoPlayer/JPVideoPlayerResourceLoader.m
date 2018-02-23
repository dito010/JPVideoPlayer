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

@interface JPVideoPlayerResourceLoader()<JPResourceLoadingRequestTaskDelegate>

/**
 * The request queues.
 * It save the requests waiting for being given video data.
 */
@property (nonatomic, strong, nullable)NSMutableArray<AVAssetResourceLoadingRequest *> *pendingRequests;

@property (nonatomic, strong) JPVideoPlayerCacheFile *cacheFile;

@property (nonatomic, strong) AVAssetResourceLoadingRequest *currentRequest;

@property(nonatomic, assign) NSRange currentDataRange;

@property (nonatomic, strong) NSHTTPURLResponse *response;

@end

static const NSString *const kJPVideoPlayerMimeType = @"video/mp4";
static const NSString *const kJPVideoPlayerContentRangeKey = @"Content-Range";
@implementation JPVideoPlayerResourceLoader

- (instancetype)init {
    self = [super init];
    if (self) {
    }
    return self;
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
        JPLogDebug(@"Add a new loadingRequest");
        [self cancelCurrentRequest:YES];
        [self.pendingRequests addObject:loadingRequest];
        [self findAndStartNextRequestIfNeed];
    }
    return YES;
}

- (void)resourceLoader:(AVAssetResourceLoader *)resourceLoader
didCancelLoadingRequest:(AVAssetResourceLoadingRequest *)loadingRequest{
    JPLogDebug(@"Cancel a loadingRequest");
    if (self.currentRequest == loadingRequest) {
        [self cancelCurrentRequest:NO];
    }
    else {
        [self.pendingRequests removeObject:loadingRequest];
    }
}


#pragma mark - Private

- (void)findAndStartNextRequestIfNeed {
    if (self.currentRequest || self.pendingRequests.count == 0) {
        return;
    }

    self.currentRequest = [self.pendingRequests firstObject];
    // data range.
    if ([self.currentRequest.dataRequest respondsToSelector:@selector(requestsAllDataToEndOfResource)] && self.currentRequest.dataRequest.requestsAllDataToEndOfResource) {
        self.currentDataRange = NSMakeRange((NSUInteger)self.currentRequest.dataRequest.requestedOffset, NSUIntegerMax);
    }
    else {
        self.currentDataRange = NSMakeRange((NSUInteger)self.currentRequest.dataRequest.requestedOffset, self.currentRequest.dataRequest.requestedLength);
    }

    // response.
    if (!self.response && self.cacheFile.responseHeaders.count > 0) {
        if (self.currentDataRange.length == NSUIntegerMax) {
            _currentDataRange.length = [self.cacheFile fileLength] - self.currentDataRange.location;
        }

        NSMutableDictionary *responseHeaders = [self.cacheFile.responseHeaders mutableCopy];
        BOOL supportRange = responseHeaders[kJPVideoPlayerContentRangeKey] != nil;
        if (supportRange && JPValidByteRange(self.currentDataRange)) {
            responseHeaders[kJPVideoPlayerContentRangeKey] = JPRangeToHTTPRangeReponseHeader(self.currentDataRange, [self.cacheFile fileLength]);
        }
        else {
            [responseHeaders removeObjectForKey:kJPVideoPlayerContentRangeKey];
        }
        responseHeaders[@"Content-Length"] = [NSString stringWithFormat:@"%tu",self.currentDataRange.length];
        NSInteger statusCode = supportRange ? 206 : 200;
        self.response = [[NSHTTPURLResponse alloc] initWithURL:self.currentRequest.request.URL
                                                    statusCode:statusCode
                                                   HTTPVersion:@"HTTP/1.1"
                                                  headerFields:responseHeaders];
        [self.currentRequest jp_fillContentInformationWithResponse:self.response];
    }
    JPLogDebug(@"Find next loading request");
    [self startCurrentRequest];
}

- (void)startCurrentRequest {
    JPLogDebug(@"Start current loading request");
    if (self.currentDataRange.length == NSUIntegerMax) {
        [self addTaskWithRange:NSMakeRange(self.currentDataRange.location, NSUIntegerMax) cached:NO];
    }
    else {
        NSUInteger start = self.currentDataRange.location;
        NSUInteger end = NSMaxRange(self.currentDataRange);
        while (start < end) {
            NSRange firstNotCachedRange = [self.cacheFile firstNotCachedRangeFromPosition:start];
            if (!JPValidFileRange(firstNotCachedRange)) {
                [self addTaskWithRange:NSMakeRange(start, end - start) cached:self.cacheFile.cachedDataBound > 0];
                start = end;
            }
            else if (firstNotCachedRange.location >= end) {
                [self addTaskWithRange:NSMakeRange(start, end - start) cached:YES];
                start = end;
            }
            else if (firstNotCachedRange.location >= start) {
                if (firstNotCachedRange.location > start) {
                    [self addTaskWithRange:NSMakeRange(start, firstNotCachedRange.location - start) cached:YES];
                }
                NSUInteger notCachedEnd = MIN(NSMaxRange(firstNotCachedRange), end);
                [self addTaskWithRange:NSMakeRange(firstNotCachedRange.location, notCachedEnd - firstNotCachedRange.location) cached:NO];
                start = notCachedEnd;
            }
            else {
                [self addTaskWithRange:NSMakeRange(start, end - start) cached:YES];
                start = end;
            }
        }
    }
}

- (void)cancelCurrentRequest:(BOOL)finishCurrentRequest {
    if (finishCurrentRequest) {
        if (!self.currentRequest.isFinished) {
            [self finishCurrentRequestWithError:[NSError errorWithDomain:NSURLErrorDomain code:NSURLErrorCancelled userInfo:nil]];
        }
    }
    else {
        [self cleanUpCurrentRequest];
    }
}

- (void)finishCurrentRequestWithError:(NSError *)error {
    if (error) {
        [self.currentRequest finishLoadingWithError:error];
    }
    else {
        [self.currentRequest finishLoading];
    }
    [self cleanUpCurrentRequest];
    [self findAndStartNextRequestIfNeed];
}

- (void)cleanUpCurrentRequest {
    [self.pendingRequests removeObject:self.currentRequest];
    self.currentRequest = nil;
    self.response = nil;
    self.currentDataRange = JPInvalidRange;
}

- (void)addTaskWithRange:(NSRange)range cached:(BOOL)cached {
    JPResourceLoadingRequestTask *task = [JPResourceLoadingRequestTask requestTaskWithLoadingRequest:self.currentRequest
                                                                                        requestRange:range
                                                                                           cacheFile:self.cacheFile
                                                                                           customURL:self.customURL];
    task.delegate = self;
    if (!cached) {
        task.response = self.response;
    }
    
    JPLogDebug(@"Creat a new request task");
    JPDispatchSyncOnMainQueue(^{
        if (self.delegate && [self.delegate respondsToSelector:@selector(resourceLoader:didReceiveLoadingRequestTask:)]) {
            [self.delegate resourceLoader:self didReceiveLoadingRequestTask:task];
        }
    });
}


#pragma mark - JPResourceLoadingRequestTaskDelegate

- (void)requestTask:(JPResourceLoadingRequestTask *)requestTask didCompleteWithError:(NSError *)error {
    if (requestTask.isCancelled || error.code == NSURLErrorCancelled) {
        return;
    }

    if (error) {
        [self finishCurrentRequestWithError:error];
    }
    else {
        [self finishCurrentRequestWithError:nil];
    }
}

@end
