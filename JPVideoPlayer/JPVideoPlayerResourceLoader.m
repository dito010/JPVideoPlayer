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
#import "JPResourceLoadingRequestTask.h"
#import "JPVideoPlayerSupportUtils.h"

@interface JPVideoPlayerResourceLoader()<JPResourceLoadingRequestTaskDelegate>

@property (nonatomic, strong) JPVideoPlayerCacheFile *cacheFile;

@property (nonatomic, strong)NSMutableArray<AVAssetResourceLoadingRequest *> *loadingRequests;

@property (nonatomic, strong) AVAssetResourceLoadingRequest *runningLoadingRequest;

@property (nonatomic, strong) NSMutableArray<JPResourceLoadingRequestTask *> *requestTasks;

@property (nonatomic, strong) __kindof JPResourceLoadingRequestTask *runningRequestTask;

@property(nonatomic, strong) dispatch_queue_t ioQueue;

@end

@implementation JPVideoPlayerResourceLoader
// TODO: 当拖动进度条时, 一定要全部下载完才开始播放.

- (void)dealloc {
    if(self.runningRequestTask){
        [self.runningRequestTask cancel];
        [self _removeCurrentRequestTaskAndResetAll];
    }
    self.loadingRequests = nil;
}

- (instancetype)init {
    NSAssert(NO, @"请使用指定初始化方法");
    return nil;
}

+ (instancetype)new {
    NSAssert(NO, @"请使用指定初始化方法");
    return nil;
}

+ (instancetype)resourceLoaderWithCustomURL:(NSURL *)customURL
                                  cacheFile:(JPVideoPlayerCacheFile *)cacheFile
                                  syncQueue:(dispatch_queue_t)syncQueue {
    return [[JPVideoPlayerResourceLoader alloc] initWithCustomURL:customURL cacheFile:cacheFile syncQueue:syncQueue];
}

- (instancetype)initWithCustomURL:(NSURL *)customURL
                        cacheFile:(JPVideoPlayerCacheFile *)cacheFile
                        syncQueue:(dispatch_queue_t)syncQueue {
    if(!customURL ||!cacheFile || !syncQueue){
        JPErrorLog(@"customURL, cacheFile and syncQueue can not be nil");
        return nil;
    }

    self = [super init];
    if(self){
        _customURL = customURL;
        _loadingRequests = @[].mutableCopy;
        _requestTasks = @[].mutableCopy;
        _cacheFile = cacheFile;
        _syncQueue = syncQueue;
        _ioQueue = JPNewSyncQueue("com.jpvideoplayer.resourceloader.ioqueue.www");
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
    if (![self.loadingRequests containsObject:loadingRequest]) {
        JPDebugLog(@"要取消的请求已经完成了");
        return;
    }
    if (loadingRequest != self.runningLoadingRequest) {
        JPDebugLog(@"取消了一个等待进行的请求");
        [self.loadingRequests removeObject:loadingRequest];
        return;
    }

    JPDebugLog(@"取消了一个正在进行的请求");
    if(self.runningLoadingRequest && self.runningRequestTask){
        [self.runningRequestTask cancel];
    }
    if([self.loadingRequests containsObject:self.runningLoadingRequest]){
        [self.loadingRequests removeObject:self.runningLoadingRequest];
    }
    [self _removeCurrentRequestTaskAndResetAll];
    [self _findAndStartNextLoadingRequestIfNeed];
}


#pragma mark - JPResourceLoadingRequestTaskDelegate

- (void)requestTask:(JPResourceLoadingRequestTask *)requestTask
didCompleteWithError:(NSError *_Nullable)error {
    JPDispatchAsyncOnQueue(self.syncQueue, ^{
        if (error.code == NSURLErrorCancelled) return;
        if (![self.requestTasks containsObject:requestTask]) {
            JPDebugLog(@"完成的 task 不是正在进行的 task");
            return;
        }
        [self _finishCurrentRequestWithError:error];
    });
}


#pragma mark - Private

- (void)_finishCurrentRequestWithError:(NSError *)error {
    if (error) {
        JPDebugLog(@"ResourceLoader 完成一个请求 error: %@", error);
        [self.runningRequestTask.loadingRequest finishLoadingWithError:error];
        [self.loadingRequests removeObject:self.runningLoadingRequest];
        [self _removeCurrentRequestTaskAndResetAll];
        [self _findAndStartNextLoadingRequestIfNeed];
    }
    else {
        [self.requestTasks removeObject:self.runningRequestTask];
        if(!self.requestTasks.count){ // 全部完成.
            JPDebugLog(@"ResourceLoader 当前 tasks 全部完成.");
            [self.runningRequestTask.loadingRequest finishLoading];
            [self.loadingRequests removeObject:self.runningLoadingRequest];
            [self _removeCurrentRequestTaskAndResetAll];
            [self _findAndStartNextLoadingRequestIfNeed];
        }
        else { // 完成了一部分, 继续请求.
            JPDebugLog(@"ResourceLoader 完成了一部分, 继续请求.");
            [self _startNextTaskIfNeed];
        }
    }
}

- (void)_findAndStartNextLoadingRequestIfNeed {
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
    [self _startNextTaskIfNeed];
}

- (void)_addTaskWithLoadingRequest:(AVAssetResourceLoadingRequest *)loadingRequest
                             range:(NSRange)range
                            cached:(BOOL)cached {
    JPResourceLoadingRequestTask *task;
    if(cached){
        JPDebugLog(@"ResourceLoader 创建了一个本地请求 range: %@", NSStringFromRange(range));
        task = [[JPResourceLoadingRequestLocalTask alloc] initWithLoadingRequest:loadingRequest
                                                                    requestRange:range
                                                                       cacheFile:self.cacheFile
                                                                       customURL:self.customURL
                                                                       syncQueue:self.syncQueue
                                                                         ioQueue:self.ioQueue];
    }
    else {
        task = [[JPResourceLoadingRequestWebTask alloc] initWithLoadingRequest:loadingRequest
                                                                  requestRange:range
                                                                     cacheFile:self.cacheFile
                                                                     customURL:self.customURL
                                                                     syncQueue:self.syncQueue];
        JPDebugLog(@"ResourceLoader 创建一个网络请求 range: %@", NSStringFromRange(range));
        if (self.delegate && [self.delegate respondsToSelector:@selector(resourceLoader:didReceiveLoadingRequestTask:)]) {
            [self.delegate resourceLoader:self didReceiveLoadingRequestTask:(JPResourceLoadingRequestWebTask *)task];
        }
    }
    task.delegate = self;
    [self.requestTasks addObject:task];
}

- (void)_removeCurrentRequestTaskAndResetAll {
    [self.requestTasks removeAllObjects];
    self.runningLoadingRequest = nil;
    self.runningRequestTask = nil;
}

- (void)_startNextTaskIfNeed {
    self.runningRequestTask = self.requestTasks.firstObject;
    [self.runningRequestTask start];
}

- (NSRange)_fetchRequestRangeWithAVResourceLoadingRequest:(AVAssetResourceLoadingRequest *)loadingRequest {
    static NSUInteger location, length;
    location = (NSUInteger)loadingRequest.dataRequest.requestedOffset;
    length = (NSUInteger)loadingRequest.dataRequest.requestedLength;;
    if ([loadingRequest.dataRequest respondsToSelector:@selector(requestsAllDataToEndOfResource)] && loadingRequest.dataRequest.requestsAllDataToEndOfResource) length = NSUIntegerMax;
    if(loadingRequest.dataRequest.currentOffset > 0) location = (NSUInteger)loadingRequest.dataRequest.currentOffset;
    return NSMakeRange(location, length);
}

@end
