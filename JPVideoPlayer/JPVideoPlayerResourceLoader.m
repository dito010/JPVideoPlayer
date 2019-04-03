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

#import "JPVideoPlayerResourceLoader.h"
#import "JPVideoPlayerCompat.h"
#import "JPVideoPlayerCacheFile.h"
#import "JPVideoPlayerCachePath.h"
#import "JPVideoPlayerManager.h"
#import "JPResourceLoadingRequestTask.h"
#import "JPVideoPlayerSupportUtils.h"
#import <pthread.h>

@interface JPVideoPlayerResourceLoader()<JPResourceLoadingRequestTaskDelegate>

@property (nonatomic, strong)NSMutableArray<AVAssetResourceLoadingRequest *> *loadingRequests;

@property (nonatomic, strong) AVAssetResourceLoadingRequest *runningLoadingRequest;

@property (nonatomic, strong) JPVideoPlayerCacheFile *cacheFile;

@property (nonatomic, strong) NSMutableArray<JPResourceLoadingRequestTask *> *requestTasks;

@property (nonatomic, strong) JPResourceLoadingRequestTask *runningRequestTask;

@property (nonatomic) pthread_mutex_t lock;

@property (nonatomic, strong) dispatch_queue_t internalSyncQueue;

@end

@implementation JPVideoPlayerResourceLoader

- (void)dealloc {
    if(self.runningRequestTask){
        [self.runningRequestTask cancel];
        [self removeCurrentRequestTaskAndResetAll];
    }
    self.loadingRequests = nil;
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
    if(!customURL){
        JPErrorLog(@"customURL can not be nil");
        return nil;
    }

    self = [super init];
    if(self){
        pthread_mutexattr_t mutexattr;
        pthread_mutexattr_init(&mutexattr);
        pthread_mutexattr_settype(&mutexattr, PTHREAD_MUTEX_RECURSIVE);
        pthread_mutex_init(&_lock, &mutexattr);
        _internalSyncQueue = JPNewSyncQueue("com.NewPan.jpvideoplayer.resource.loader.www");
        _customURL = customURL;
        _loadingRequests = [@[] mutableCopy];
        NSString *key = [JPVideoPlayerManager.sharedManager cacheKeyForURL:customURL];
        _cacheFile = [JPVideoPlayerCacheFile cacheFileWithFilePath:[JPVideoPlayerCachePath createVideoFileIfNeedThenFetchItForKey:key]
                                                     indexFilePath:[JPVideoPlayerCachePath createVideoIndexFileIfNeedThenFetchItForKey:key]];
    }
    return self;
}


#pragma mark - AVAssetResourceLoaderDelegate

- (BOOL)resourceLoader:(AVAssetResourceLoader *)resourceLoader
shouldWaitForLoadingOfRequestedResource:(AVAssetResourceLoadingRequest *)loadingRequest {
    if (resourceLoader && loadingRequest){
        [self.loadingRequests addObject:loadingRequest];
        JPDebugLog(@"ResourceLoader 接收到新的请求, 当前请求数: %ld <<<<<<<<<<<<<<", self.loadingRequests.count);
        [self _findAndStartNextLoadingRequestIfNeed];
    }
    return YES;
}

- (void)resourceLoader:(AVAssetResourceLoader *)resourceLoader
didCancelLoadingRequest:(AVAssetResourceLoadingRequest *)loadingRequest {
    if ([self.loadingRequests containsObject:loadingRequest]) {
        if(loadingRequest == self.runningLoadingRequest){
            JPDebugLog(@"取消了一个正在进行的请求");
            if(self.runningLoadingRequest && self.runningRequestTask){
                [self.runningRequestTask cancel];
            }
            if([self.loadingRequests containsObject:self.runningLoadingRequest]){
                [self.loadingRequests removeObject:self.runningLoadingRequest];
            }
            [self removeCurrentRequestTaskAndResetAll];
            [self _findAndStartNextLoadingRequestIfNeed];
        }
        else {
            JPDebugLog(@"取消了一个等待进行的请求");
            [self.loadingRequests removeObject:loadingRequest];
        }
    }
    else {
        JPDebugLog(@"要取消的请求已经完成了");
    }
}


#pragma mark - JPResourceLoadingRequestTaskDelegate

- (void)requestTask:(JPResourceLoadingRequestTask *)requestTask
didCompleteWithError:(NSError *)error {
    if (error.code == NSURLErrorCancelled) {
        return;
    }
    if (![self.requestTasks containsObject:requestTask]) {
        JPDebugLog(@"完成的 task 不是正在进行的 task");
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
        [self.loadingRequests removeObject:self.runningLoadingRequest];
        [self removeCurrentRequestTaskAndResetAll];
        [self _findAndStartNextLoadingRequestIfNeed];
    }
    else {
        JPDebugLog(@"ResourceLoader 完成一个请求, 没有错误");
        // 要所有的请求都完成了才行.
        [self.requestTasks removeObject:self.runningRequestTask];
        if(!self.requestTasks.count){ // 全部完成.
            [self.runningRequestTask.loadingRequest finishLoading];
            [self.loadingRequests removeObject:self.runningLoadingRequest];
            [self removeCurrentRequestTaskAndResetAll];
            [self _findAndStartNextLoadingRequestIfNeed];
        }
        else { // 完成了一部分, 继续请求.
            [self startNextTaskIfNeed];
        }
    }
}


#pragma mark - Private

- (void)_findAndStartNextLoadingRequestIfNeed {
//    JPAssertNotMainThread;
    if (!self.loadingRequests.count || self.runningLoadingRequest || self.runningRequestTask) return;
    self.runningLoadingRequest = [self.loadingRequests firstObject];
    [self _startLoadingRequest:self.runningLoadingRequest range:[self _fetchRequestRangeWithAVResourceLoadingRequest:self.runningLoadingRequest]];
}

- (void)_startLoadingRequest:(AVAssetResourceLoadingRequest *)loadingRequest
                       range:(NSRange)dataRange {
//    JPAssertNotMainThread;
    /// 是否已经完全缓存完成.
    JPDebugLog(@"ResourceLoader 处理新的请求, 数据范围是: %@, 是否已经缓存完成: %@", NSStringFromRange(dataRange), self.cacheFile.hasCompleted ? @"是" : @"否");
    if (dataRange.length == NSUIntegerMax) {
        [self _addTaskWithLoadingRequest:loadingRequest
                                   range:NSMakeRange(dataRange.location, NSUIntegerMax)
                                  cached:NO];
    }
    else {
        NSUInteger start = dataRange.location;
        NSUInteger end = NSMaxRange(dataRange);
        NSRange firstNotCachedRange;
        while (start < end) {
            @autoreleasepool {
                firstNotCachedRange = [self.cacheFile firstNotCachedRangeFromPosition:start];
                /// 没找到 start 以后有未缓存完的, 整个字节范围缓存完成.
                if (!JPValidFileRange(firstNotCachedRange)) {
                    [self _addTaskWithLoadingRequest:loadingRequest
                                               range:dataRange
                                              cached:NO];
                    start = end;
                }
                /// start 之后未缓存完的区间已经超过当前请求的范围, 整个字节范围缓存完成.
                else if (firstNotCachedRange.location >= end) {
                    [self _addTaskWithLoadingRequest:loadingRequest
                                               range:dataRange
                                              cached:YES];
                    start = end;
                }
                ///
                else if (firstNotCachedRange.location >= start) {
                    if (firstNotCachedRange.location > start) {
                        [self _addTaskWithLoadingRequest:loadingRequest
                                                   range:NSMakeRange(start, firstNotCachedRange.location - start)
                                                  cached:YES];
                    }
                    NSUInteger notCachedEnd = MIN(NSMaxRange(firstNotCachedRange), end);
                    [self _addTaskWithLoadingRequest:loadingRequest
                                               range:NSMakeRange(firstNotCachedRange.location, notCachedEnd - firstNotCachedRange.location)
                                              cached:NO];
                    start = notCachedEnd;
                }
                else {
                    [self _addTaskWithLoadingRequest:loadingRequest
                                               range:dataRange
                                              cached:YES];
                    start = end;
                }
            }
        }
    }

    // 发起请求.
    [self startNextTaskIfNeed];
}

- (void)_addTaskWithLoadingRequest:(AVAssetResourceLoadingRequest *)loadingRequest
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
        task = [JPResourceLoadingRequestWebTask requestTaskWithLoadingRequest:loadingRequest
                                                                 requestRange:range
                                                                    cacheFile:self.cacheFile
                                                                    customURL:self.customURL
                                                                       cached:cached];
        JPDebugLog(@"ResourceLoader 创建一个网络请求: %@", task);
        if (self.delegate && [self.delegate respondsToSelector:@selector(resourceLoader:didReceiveLoadingRequestTask:)]) {
            [self.delegate resourceLoader:self didReceiveLoadingRequestTask:(JPResourceLoadingRequestWebTask *)task];
        }
    }
    int lock = pthread_mutex_trylock(&_lock);
    task.delegate = self;
    if (!self.requestTasks) {
        self.requestTasks = [@[] mutableCopy];
    }
    [self.requestTasks addObject:task];
    if (!lock) {
        pthread_mutex_unlock(&_lock);
    }
}

- (void)removeCurrentRequestTaskAndResetAll {
    self.runningLoadingRequest = nil;
    self.requestTasks = [@[] mutableCopy];
    self.runningRequestTask = nil;
}

- (void)startNextTaskIfNeed {
    int lock = pthread_mutex_trylock(&_lock);;
    self.runningRequestTask = self.requestTasks.firstObject;
    if ([self.runningRequestTask isKindOfClass:[JPResourceLoadingRequestLocalTask class]]) {
        [self.runningRequestTask startOnQueue:self.internalSyncQueue];
    }
    else {
        [self.runningRequestTask start];
    }
    if (!lock) {
        pthread_mutex_unlock(&_lock);
    }
}

- (NSRange)_fetchRequestRangeWithAVResourceLoadingRequest:(AVAssetResourceLoadingRequest *)loadingRequest {
    NSUInteger location = (NSUInteger)loadingRequest.dataRequest.requestedOffset;
    NSUInteger length = (NSUInteger)loadingRequest.dataRequest.requestedLength;;
    if ([loadingRequest.dataRequest respondsToSelector:@selector(requestsAllDataToEndOfResource)] && loadingRequest.dataRequest.requestsAllDataToEndOfResource) length = NSUIntegerMax;
    if(loadingRequest.dataRequest.currentOffset > 0) location = (NSUInteger)loadingRequest.dataRequest.currentOffset;
    return NSMakeRange(location, length);
}

@end
