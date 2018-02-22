//
// Created by NewPan on 2018/2/22.
// Copyright (c) 2018 NewPan. All rights reserved.
//

#import <Foundation/Foundation.h>

@class AVAssetResourceLoadingRequest,
       JPVideoPlayerCacheFile;

NS_ASSUME_NONNULL_BEGIN

@interface JPResourceLoadingRequestTask : NSObject

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
 * Convenience method to fetch instance of this class.
 *
 * @param loadingRequest The loadingRequest from `AVPlayer`.
 * @param requestRange   The range need request from web.
 * @param cacheFile      The cache file take responsibility for save video data to disk and read cached video from disk.
 * @param customURL The url custom passed in.
 *
 * @return A instance of this class.
 */
+ (instancetype)requestTaskWithLoadingRequest:(AVAssetResourceLoadingRequest *)loadingRequest
                                 requestRange:(NSRange)requestRange
                                    cacheFile:(JPVideoPlayerCacheFile *)cacheFile
                                    customURL:(NSURL *)customURL NS_DESIGNATED_INITIALIZER;

/**
 * Designated initializer method.
 *
 * @param loadingRequest The loadingRequest from `AVPlayer`.
 * @param requestRange   The range need request from web.
 * @param cacheFile      The cache file take responsibility for save video data to disk and read cached video from disk.
 * @param customURL The url custom passed in.
 *
 * @return A instance of this class.
 */
- (instancetype)initWithLoadingRequest:(AVAssetResourceLoadingRequest *)loadingRequest
                          requestRange:(NSRange)requestRange
                             cacheFile:(JPVideoPlayerCacheFile *)cacheFile
                             customURL:(NSURL *)customURL NS_DESIGNATED_INITIALIZER;

@end

NS_ASSUME_NONNULL_END