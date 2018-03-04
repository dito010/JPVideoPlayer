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
#import <pthread.h>

@interface JPVideoPlayerResourceLoader()<JPResourceLoadingRequestTaskDelegate>

@property (nonatomic, strong)NSArray<AVAssetResourceLoadingRequest *> *loadingRequests;

@property (nonatomic, strong) AVAssetResourceLoadingRequest *runningLoadingRequest;

@property (nonatomic, strong) JPVideoPlayerCacheFile *cacheFile;

@property (nonatomic, strong) JPResourceLoadingRequestTask *runningRequestTask;

@property (nonatomic, strong) NSArray<JPResourceLoadingRequestTask *> *requestTasks;

@property (nonatomic) pthread_mutex_t lock;

@property (nonatomic, strong, nonnull) dispatch_queue_t ioQueue;

@end


@implementation JPVideoPlayerResourceLoader

- (void)dealloc {
//    [self.operationQueue cancelAllTasks];
    pthread_mutex_destroy(&_lock);
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
        pthread_mutexattr_t mutexattr;
        pthread_mutexattr_init(&mutexattr);
        pthread_mutexattr_settype(&mutexattr, PTHREAD_MUTEX_RECURSIVE);
        pthread_mutex_init(&_lock, &mutexattr);
        _customURL = customURL;
        _loadingRequests = [@[] mutableCopy];
        NSString *key = [JPVideoPlayerManager.sharedManager cacheKeyForURL:customURL];
        _cacheFile = [JPVideoPlayerCacheFile cacheFileWithFilePath:[JPVideoPlayerCachePath videoCacheTemporaryPathForKey:key]
                                                     indexFilePath:[JPVideoPlayerCachePath videoCacheIndexSavePathForKey:key]];
        _ioQueue = dispatch_queue_create("com.NewPan.jpvideoplayer.resource.loader.www", DISPATCH_QUEUE_SERIAL);
    }
    return self;
}


#pragma mark - AVAssetResourceLoaderDelegate

- (BOOL)resourceLoader:(AVAssetResourceLoader *)resourceLoader
shouldWaitForLoadingOfRequestedResource:(AVAssetResourceLoadingRequest *)loadingRequest{
    if (resourceLoader && loadingRequest){
        NSMutableArray *loadingRequests = self.loadingRequests.mutableCopy;
        if(!loadingRequests){
           loadingRequests = [@[] mutableCopy];
        }
        [loadingRequests addObject:loadingRequest];
        self.loadingRequests = loadingRequests.copy;
        JPDebugLog(@"ResourceLoader 接收到新的请求, 当前请求数: %ld <<<<<<<<<<<<<<", self.loadingRequests.count);
        [self findAndStartNextLoadingRequestIfNeed];
    }
    return YES;
}

- (void)resourceLoader:(AVAssetResourceLoader *)resourceLoader
didCancelLoadingRequest:(AVAssetResourceLoadingRequest *)loadingRequest{
    if (self.runningRequestTask.loadingRequest == loadingRequest) {
        JPDebugLog(@"ResourceLoader 取消了一个正在请求的请求");
        [self.runningRequestTask cancel];
        [self removeCurrentRequestTaskAnResetAll];
    }
    else {
        JPDebugLog(@"ResourceLoader 取消了一个不在请求的请求");
        NSMutableArray *loadingRequests = self.loadingRequests.mutableCopy;
        NSParameterAssert(loadingRequests);
        [loadingRequests removeObject:loadingRequests];
    }
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
        [self finishCurrentRequestWithError:nil];
    }
}


#pragma mark - Finish Request

- (void)finishCurrentRequestWithError:(NSError *)error {
    if (error) {
        JPDebugLog(@"ResourceLoader 完成一个请求 error: %@", error);
        [self.runningRequestTask.loadingRequest finishLoadingWithError:error];
        [self removeCurrentRequestTaskAnResetAll];
        [self findAndStartNextLoadingRequestIfNeed];
    }
    else {
        JPDebugLog(@"ResourceLoader 完成一个请求, 没有错误");
        // 要所有的请求都完成了才行.
        if(!self.requestTasks.count){ // 全部完成.
            [self.runningRequestTask.loadingRequest finishLoading];
            [self removeCurrentRequestTaskAnResetAll];
            [self findAndStartNextLoadingRequestIfNeed];
        }
        else { // 完成了一部分, 继续请求.
            [self startNextTaskIfNeed];
        }
    }
}


#pragma mark - Private

- (void)findAndStartNextLoadingRequestIfNeed {
    if(self.runningRequestTask){
        [self.runningRequestTask cancel];
        [self removeCurrentRequestTaskAnResetAll];
        return;
    }
    if (self.loadingRequests.count == 0) {
        return;
    }

    self.runningLoadingRequest = [self.loadingRequests firstObject];
    NSMutableArray *loadingRequests = self.loadingRequests.mutableCopy;
    NSParameterAssert(loadingRequests);
    [loadingRequests removeObject:self.runningLoadingRequest];
    self.loadingRequests = loadingRequests;

    NSRange dataRange = [self fetchRequestRangeWithRequest:self.runningLoadingRequest];
    if (dataRange.length == NSUIntegerMax) {
        dataRange.length = [self.cacheFile fileLength] - dataRange.location;
    }
    [self startCurrentRequestWithLoadingRequest:self.runningLoadingRequest
                                          range:dataRange];
}

- (void)startCurrentRequestWithLoadingRequest:(AVAssetResourceLoadingRequest *)loadingRequest
                                        range:(NSRange)dataRange {
    JPDebugLog(@"ResourceLoader 处理新的请求, 数据范围是: %@", NSStringFromRange(dataRange));
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

    // 发起请求.
    [self startNextTaskIfNeed];
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
        if (self.delegate && [self.delegate respondsToSelector:@selector(resourceLoader:didReceiveLoadingRequestTask:)]) {
            [self.delegate resourceLoader:self didReceiveLoadingRequestTask:task];
        }
    }
    task.delegate = self;
    int lock = pthread_mutex_trylock(&_lock);;
    NSMutableArray *requestTasks = [self.requestTasks mutableCopy];
    if(!requestTasks){
        requestTasks = [@[] mutableCopy];
    }
    [requestTasks addObject:task];
    self.requestTasks = requestTasks.copy;
    if (!lock) {
        pthread_mutex_unlock(&_lock);
    }
}

- (void)removeCurrentRequestTaskAnResetAll {
    self.runningLoadingRequest = nil;
    self.requestTasks = nil;
    self.runningRequestTask = nil;
}

- (void)startNextTaskIfNeed {
    int lock = pthread_mutex_trylock(&_lock);;
    self.runningRequestTask = self.requestTasks.firstObject;
    NSMutableArray *requestTasks = [self.requestTasks mutableCopy];
    NSParameterAssert(requestTasks.count);
    [requestTasks removeObject:self.runningRequestTask];
    self.requestTasks = requestTasks.copy;
    if ([self.runningRequestTask isKindOfClass:[JPResourceLoadingRequestLocalTask class]]) {
        [self.runningRequestTask startOnQueue:self.ioQueue];
    }
    else {
        [self.runningRequestTask start];
    }
    if (!lock) {
        pthread_mutex_unlock(&_lock);
    }
}

- (NSRange)fetchRequestRangeWithRequest:(AVAssetResourceLoadingRequest *)loadingRequest {
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
    return NSMakeRange(location, length);
}

@end
