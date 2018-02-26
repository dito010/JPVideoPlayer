//
// Created by NewPan on 2018/2/20.
// Copyright (c) 2018 NewPan. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "JPResourceLoadingRequestTask.h"

NS_ASSUME_NONNULL_BEGIN

@interface NSURL (StripQuery)

/*
 * Returns absolute string of URL with the query stripped out.
 * If there is no query, returns a copy of absolute string.
 */

- (NSString *)absoluteStringByStrippingQuery;

@end

@interface UIView (WebVideoCacheOperation)

/**
 * The url of current playing video data.
 */
@property(nonatomic, nullable)NSURL *currentPlayingURL;

@end

@class JPVideoPlayerProgressView;

@interface UIView (PlayerStatusAndDownloadIndicator)

/**
 * The view of video layer display on.
 */
@property(nonatomic, readonly, nullable)UIView *jp_videoLayerView;

/**
 * The background layer for video layer.
 */
@property(nonatomic, readonly, nullable)CALayer *jp_backgroundLayer;

/**
 *  The indicator view to add progress view and activity view.
 */
@property(nonatomic, readonly, nullable)UIView *jp_indicatorView;

/**
 * The download progress value.
 */
@property(nonatomic, readonly)CGFloat jp_downloadProgressValue;

/**
 * The playing progress value.
 */
@property(nonatomic, readonly)CGFloat jp_playingProgressValue;

/**
 * Call this method to custom the dowload indicator color of progress view(@optional).
 *
 * @param color a `UIColor` instance to custom the dowload indicator progress view color.
 */
- (void)jp_perfersDownloadProgressViewColor:(UIColor * _Nonnull)color;

/**
 * Call this method to custom the playing indicator color of progress view(@optional).
 *
 * @param color a `UIColor` instance to custom the playing indicator progress view color.
 */
- (void)jp_perfersPlayingProgressViewColor:(UIColor * _Nonnull)color;

@end

@interface NSHTTPURLResponse (JPVideoPlayer)

/**
 * Fetch the file length of response.
 *
 * @return The file length of response.
 */
- (long long)jp_fileLength;

/**
 * Check the response support streaming or not.
 *
 * @return The response support streaming or not.
 */
- (BOOL)jp_supportRange;

@end

@interface AVAssetResourceLoadingRequest (JPVideoPlayer)

/**
 * Fill content information for current request use response conent.
 *
 * @param response A response.
 */
- (void)jp_fillContentInformationWithResponse:(NSHTTPURLResponse *)response;

@end

@interface NSFileHandle (JPVideoPlayer)

- (BOOL)jp_safeWriteData:(NSData *)data;

@end

@interface NSURLSessionTask(JPVideoPlayer)

@property(nonatomic) JPResourceLoadingRequestWebTask * webTask;

@end

NS_ASSUME_NONNULL_END
