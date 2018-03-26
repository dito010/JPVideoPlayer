//
// Created by NewPan on 2018/3/6.
// Copyright (c) 2018 NewPan. All rights reserved.
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@protocol JPVideoPlayerProtocol <NSObject>

@optional
/**
 * This method will be called when the downloader fetched the file length or read from disk.
 *
 * @warning This method may be call repeatedly when download a video.
 *
 * @param videoLength The video file length.
 */
- (void)didFetchVideoFileLength:(NSUInteger)videoLength;

/**
 * This method will be called when received new video data from web.
 *
 * @param cacheRanges The ranges of video data cached in disk.
 */
- (void)cacheRangeDidChange:(NSArray<NSValue *> *)cacheRanges;

/**
 * This method will be called when play progress changed.
 *
 * @param elapsedSeconds The elapsed player time.
 * @param totalSeconds   The length of the video.
 */
- (void)playProgressDidChangeElapsedSeconds:(NSTimeInterval)elapsedSeconds
                               totalSeconds:(NSTimeInterval)totalSeconds;

@end

NS_ASSUME_NONNULL_END