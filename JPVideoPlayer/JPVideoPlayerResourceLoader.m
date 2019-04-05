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
    JPDispatchSyncOnMainQueue(^{
        if (resourceLoader && loadingRequest){
            [self.loadingRequests addObject:loadingRequest];
            JPDebugLog(@"ResourceLoader 接收到新的请求, 当前请求数: %ld <<<<<<<<<<<<<<", self.loadingRequests.count);
            [self _findAndStartNextLoadingRequestIfNeed];
        }
    });
    return YES;
}

- (void)resourceLoader:(AVAssetResourceLoader *)resourceLoader
didCancelLoadingRequest:(AVAssetResourceLoadingRequest *)loadingRequest {
    JPDispatchSyncOnMainQueue(^{
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
    });
}


#pragma mark - JPResourceLoadingRequestTaskDelegate

- (void)requestTask:(JPResourceLoadingRequestTask *)requestTask
didCompleteWithError:(NSError *)error {
    JPDispatchSyncOnMainQueue(^{
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
    });
}


#pragma mark - Finish Request

- (void)finishCurrentRequestWithError:(NSError *)error {
    JPAssertMainThread;
    if (error) {
        JPDebugLog(@"ResourceLoader 完成一个请求 error: %@", error);
        [self.runningRequestTask.loadingRequest finishLoadingWithError:error];
        [self.loadingRequests removeObject:self.runningLoadingRequest];
        [self removeCurrentRequestTaskAndResetAll];
        [self _findAndStartNextLoadingRequestIfNeed];
    }
    else {
        // 要所有的请求都完成了才行.
        [self.requestTasks removeObject:self.runningRequestTask];
        if(!self.requestTasks.count){ // 全部完成.
            JPDebugLog(@"ResourceLoader 当前 tasks 全部完成.");
            [self.runningRequestTask.loadingRequest finishLoading];
            [self.loadingRequests removeObject:self.runningLoadingRequest];
            [self removeCurrentRequestTaskAndResetAll];
            [self _findAndStartNextLoadingRequestIfNeed];
        }
        else { // 完成了一部分, 继续请求.
            JPDebugLog(@"ResourceLoader 完成了一部分, 继续请求.");
            [self startNextTaskIfNeed];
        }
    }
}


#pragma mark - Private

- (void)_findAndStartNextLoadingRequestIfNeed {
//    JPAssertNotMainThread;
    JPAssertMainThread;
    if (!self.loadingRequests.count || self.runningLoadingRequest || self.runningRequestTask) return;
    self.runningLoadingRequest = [self.loadingRequests firstObject];
    [self _componentRequestDataRange:[self _fetchRequestRangeWithAVResourceLoadingRequest:self.runningLoadingRequest]
                      loadingRequest:self.runningLoadingRequest];
}

- (void)_componentRequestDataRange:(NSRange)dataRange
                    loadingRequest:(AVAssetResourceLoadingRequest *)loadingRequest {
    NSUInteger start = dataRange.location;
    NSUInteger end = dataRange.length == NSUIntegerMax ? self.cacheFile.isFileLengthValid ? self.cacheFile.fileLength : NSUIntegerMax : NSMaxRange(dataRange);
    NSRange firstCachedRange;
    NSRange targetRange;
    JPDebugLog(@"开始分解 loadingRequest 致 tasks, dataRange: %@.", NSStringFromRange(dataRange));
    if (end == NSUIntegerMax) {
        [self _addTaskWithLoadingRequest:loadingRequest
                                   range:dataRange
                                  cached:NO];
        start = end;
    }
    while (start < end) {
        firstCachedRange = [self.cacheFile firstCachedRangeInLocation:start];
        /// 找得到就意味着有部分已经缓存完.
        if (JPValidFileRange(firstCachedRange)) {
            /// contain
            /// ------ + ------- * ------- + ------
            if (NSLocationInRange(start, firstCachedRange)) {
                ///                start        end
                /// ------ + ------- * --------- * --------- + ------
                if (end < NSMaxRange(firstCachedRange)) {
                    targetRange = NSMakeRange(start, end - start);
                    if (JPValidFileRange(targetRange)) [self _addTaskWithLoadingRequest:loadingRequest
                                                                                  range:targetRange
                                                                                 cached:YES];
                    start = end;
                }
                    ///                start                    end
                    /// ------ + ------- * -------- + ---------- * ---------
                else {
                    targetRange = NSMakeRange(start, NSMaxRange(firstCachedRange) - start);
                    if (JPValidFileRange(targetRange)) [self _addTaskWithLoadingRequest:loadingRequest
                                                                                  range:targetRange
                                                                                 cached:YES];
                    start = NSMaxRange(firstCachedRange);
                }
            }
                /// after.
                /// ------ * ------- + ------- + ------
            else {
                ///      start                end
                /// ------ * ------- + ------- * ------ + --------
                if (NSLocationInRange(end, firstCachedRange)) {
                    targetRange = NSMakeRange(start, firstCachedRange.location - start);
                    if (JPValidFileRange(targetRange)) [self _addTaskWithLoadingRequest:loadingRequest
                                                                                  range:targetRange
                                                                                 cached:NO];
                    targetRange = NSMakeRange(firstCachedRange.location, end - firstCachedRange.location);
                    if (JPValidFileRange(targetRange)) [self _addTaskWithLoadingRequest:loadingRequest
                                                                                  range:targetRange
                                                                                 cached:YES];
                    start = end;
                }
                else {
                    /// 这里不会出现 end == firstCachedRange.location
                    NSParameterAssert(end != firstCachedRange.location);
                    ///      start       end
                    /// ------ * ------- * ------- + ------ + --------
                    if (end < firstCachedRange.location) {
                        targetRange = NSMakeRange(start, end - start);
                        if (JPValidFileRange(targetRange)) [self _addTaskWithLoadingRequest:loadingRequest
                                                                                      range:targetRange
                                                                                     cached:NO];
                        start = end;
                    }
                        ///      start                         end
                        /// ------ * ------- + ------- + ------ * --------
                    else {
                        targetRange = NSMakeRange(start, firstCachedRange.location - start);
                        if (JPValidFileRange(targetRange)) [self _addTaskWithLoadingRequest:loadingRequest
                                                                                      range:targetRange
                                                                                     cached:NO];
                        if (JPValidFileRange(firstCachedRange)) [self _addTaskWithLoadingRequest:loadingRequest
                                                                                           range:firstCachedRange
                                                                                          cached:YES];
                        start = NSMaxRange(firstCachedRange);
                    }
                }
            }
        }
            /// 找不到就意味着, 完全没开始缓存.
        else {
            targetRange = NSMakeRange(start, end - start);
            if (JPValidFileRange(targetRange)) [self _addTaskWithLoadingRequest:loadingRequest
                                                                          range:targetRange
                                                                         cached:NO];
            start = end;
        }
    }

    NSParameterAssert(self.requestTasks.count);
    // 发起请求.
    [self startNextTaskIfNeed];
}

- (void)_addTaskWithLoadingRequest:(AVAssetResourceLoadingRequest *)loadingRequest
                             range:(NSRange)range
                            cached:(BOOL)cached {
    JPResourceLoadingRequestTask *task;
    if(cached){
        JPDebugLog(@"ResourceLoader 创建了一个本地请求 range: %@", NSStringFromRange(range));
        task = [JPResourceLoadingRequestLocalTask requestTaskWithLoadingRequest:loadingRequest
                                                                   requestRange:range
                                                                      cacheFile:self.cacheFile
                                                                      customURL:self.customURL
                                                                         cached:YES];
    }
    else {
        task = [JPResourceLoadingRequestWebTask requestTaskWithLoadingRequest:loadingRequest
                                                                 requestRange:range
                                                                    cacheFile:self.cacheFile
                                                                    customURL:self.customURL
                                                                       cached:NO];
        JPDebugLog(@"ResourceLoader 创建一个网络请求 range: %@", NSStringFromRange(range));
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
