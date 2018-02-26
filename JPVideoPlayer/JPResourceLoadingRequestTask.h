//
// Created by NewPan on 2018/2/22.
// Copyright (c) 2018 NewPan. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "JPVideoPlayerCompat.h"

@class AVAssetResourceLoadingRequest,
       JPVideoPlayerCacheFile,
       JPResourceLoadingRequestTask;

NS_ASSUME_NONNULL_BEGIN

@protocol JPResourceLoadingRequestTaskDelegate<NSObject>

@optional
/**
 * This method call when the request task did complete.
 *
 * @param requestTask The current instance.
 * @param error       The request error, nil mean success.
 */
- (void)requestTask:(JPResourceLoadingRequestTask *)requestTask
didCompleteWithError:(NSError *)error;

@end

@interface JPResourceLoadingRequestTask : NSOperation

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
 * The request did finished.
 *
 * @param error The request error, if nil mean success.
 */
- (void)requestDidCompleteWithError:(NSError *_Nullable)error;

@end

@interface JPResourceLoadingRequestLocalTask: JPResourceLoadingRequestTask

@end

@interface JPResourceLoadingRequestWebTask: JPResourceLoadingRequestTask

/**
 * Response for request.
 */
@property (nonatomic, strong) NSHTTPURLResponse *response;

@end

NS_ASSUME_NONNULL_END
