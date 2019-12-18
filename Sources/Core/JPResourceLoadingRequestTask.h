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

#import <Foundation/Foundation.h>
#import "JPVideoPlayerCompat.h"

@class AVAssetResourceLoadingRequest,
       JPVideoPlayerCacheFile,
       JPResourceLoadingRequestTask;

NS_ASSUME_NONNULL_BEGIN

@protocol JPResourceLoadingRequestTaskDelegate<NSObject>

@optional

/**
 * This method call when the request received response.
 *
 * @param requestTask The current instance.
 * @param response    The response of request.
 */
- (void)requestTask:(JPResourceLoadingRequestTask *)requestTask
 didReceiveResponse:(NSURLResponse *)response;

/**
 * This method call when the request received data.
 *
 * @param requestTask The current instance.
 * @param data        A fragment video data.
 */
- (void)requestTask:(JPResourceLoadingRequestTask *)requestTask
 didReceiveData:(NSData *)data;

/**
 * This method call when the request task did complete.
 *
 * @param requestTask The current instance.
 * @param error       The request error, nil mean success.
 */
- (void)requestTask:(JPResourceLoadingRequestTask *)requestTask
didCompleteWithError:(NSError *)error;

@end

@interface JPResourceLoadingRequestTask : NSObject

@property (nonatomic, weak) id<JPResourceLoadingRequestTaskDelegate> delegate;

/**
 * The loadingRequest passed in when this class initialize.
 */
@property (nonatomic, strong, readonly) AVAssetResourceLoadingRequest *loadingRequest;

/**
 * The range passed in when this class initialize.
 */
@property(nonatomic, assign, readonly) NSRange requestRange;

/**
 * The cache file take responsibility for save video data to disk and read cached video from disk.
 *
 * @see `JPVideoPlayerCacheFile`.
 */
@property (nonatomic, strong, readonly) JPVideoPlayerCacheFile *cacheFile;

/**
 * The url custom passed in.
 */
@property (nonatomic, strong, readonly) NSURL *customURL;

/**
 * A flag represent the video file of requestRange is cached on disk or not.
 */
@property(nonatomic, assign, readonly, getter=isCached) BOOL cached;

@property (nonatomic, assign, readonly, getter = isExecuting) BOOL executing;

@property (nonatomic, assign, readonly, getter = isFinished) BOOL finished;

@property (nonatomic, assign, readonly, getter = isCancelled) BOOL cancelled;

/**
 * Convenience method to fetch instance of this class.
 *
 * @param loadingRequest The loadingRequest from `AVPlayer`.
 * @param requestRange   The range need request from web.
 * @param cacheFile      The cache file take responsibility for save video data to disk and read cached video from disk.
 * @param customURL      The url custom passed in.
 * @param cached         A flag represent the video file of requestRange is cached on disk or not.
 *
 * @return A instance of this class.
 */
+ (instancetype)requestTaskWithLoadingRequest:(AVAssetResourceLoadingRequest *)loadingRequest
                                 requestRange:(NSRange)requestRange
                                    cacheFile:(JPVideoPlayerCacheFile *)cacheFile
                                    customURL:(NSURL *)customURL
                                       cached:(BOOL)cached;

/**
 * Designated initializer method.
 *
 * @param loadingRequest The loadingRequest from `AVPlayer`.
 * @param requestRange   The range need request from web.
 * @param cacheFile      The cache file take responsibility for save video data to disk and read cached video from disk.
 * @param customURL      The url custom passed in.
 * @param cached         A flag represent the video file of requestRange is cached on disk or not.
 *
 * @return A instance of this class.
 */
- (instancetype)initWithLoadingRequest:(AVAssetResourceLoadingRequest *)loadingRequest
                          requestRange:(NSRange)requestRange
                             cacheFile:(JPVideoPlayerCacheFile *)cacheFile
                             customURL:(NSURL *)customURL
                                cached:(BOOL)cached NS_DESIGNATED_INITIALIZER;

/**
 * The request did receive response.
 *
 * @param response The response of request.
 */
- (void)requestDidReceiveResponse:(NSURLResponse *)response;

/**
 * The request did receive data.
 *
 * @param data       A fragment video data.
 * @param completion Call when store the data finished.
 */
- (void)requestDidReceiveData:(NSData *)data
             storedCompletion:(dispatch_block_t)completion;

/**
 * The request did finish.
 *
 * @param error The request error, if nil mean success.
 */
- (void)requestDidCompleteWithError:(NSError *_Nullable)error NS_REQUIRES_SUPER;

/**
 * Begins the execution of the task, execute on main queue.
 */
- (void)start NS_REQUIRES_SUPER;

/**
 * Begins the execution of the task on given queue.
 *
 * @param queue A dispatch queue.
 */
- (void)startOnQueue:(dispatch_queue_t)queue NS_REQUIRES_SUPER;

/**
 * Advises the task object that it should stop executing its task.
 */
- (void)cancel NS_REQUIRES_SUPER;

@end

@interface JPResourceLoadingRequestLocalTask: JPResourceLoadingRequestTask

@end

@interface JPResourceLoadingRequestWebTask: JPResourceLoadingRequestTask

/**
 * The operation's task.
 */
@property (strong, nonatomic, readonly) NSURLSessionDataTask *dataTask;

/**
 * The request used by the operation's task.
 */
@property (strong, nonatomic, nullable) NSURLRequest *request;

/**
 * The JPVideoPlayerDownloaderOptions for the receiver.
 */
@property (assign, nonatomic) JPVideoPlayerDownloaderOptions options;

/**
 * This is weak because it is injected by whoever manages this session.
 * If this gets nil-ed out, we won't be able to run.
 * the task associated with this operation.
 */
@property (weak, nonatomic, nullable) NSURLSession *unownedSession;

@end

NS_ASSUME_NONNULL_END
