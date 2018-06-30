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

#import <UIKit/UIKit.h>
#import <AVFoundation/AVAssetResourceLoader.h>
#import <objc/runtime.h>

@class JPVideoPlayerModel;

#ifndef JPVideoPlayerCompat
#define JPVideoPlayerCompat

NS_ASSUME_NONNULL_BEGIN

#define JPMainThreadAssert NSParameterAssert([[NSThread currentThread] isMainThread])

typedef NS_ENUM(NSInteger, JPVideoPlayViewInterfaceOrientation) {
    JPVideoPlayViewInterfaceOrientationUnknown = 0,
    JPVideoPlayViewInterfaceOrientationPortrait,
    JPVideoPlayViewInterfaceOrientationLandscape,
};

typedef NS_ENUM(NSUInteger, JPVideoPlayerStatus)  {
    JPVideoPlayerStatusUnknown = 0,
    JPVideoPlayerStatusBuffering,
    JPVideoPlayerStatusReadyToPlay,
    JPVideoPlayerStatusPlaying,
    JPVideoPlayerStatusPause,
    JPVideoPlayerStatusFailed,
    JPVideoPlayerStatusStop,
};

typedef NS_ENUM(NSUInteger, JPLogLevel) {
    // no log output.
    JPLogLevelNone = 0,

    // output debug, warning and error log.
    JPLogLevelError = 1,

    // output debug and warning log.
    JPLogLevelWarning = 2,

    // output debug log.
    JPLogLevelDebug = 3,
};

typedef NS_OPTIONS(NSUInteger, JPVideoPlayerOptions) {
    /**
     * By default, when a URL fail to be downloaded, the URL is blacklisted so the library won't keep trying.
     * This flag disable this blacklisting.
     */
    JPVideoPlayerRetryFailed = 1 << 0,

    /**
     * In iOS 4+, continue the download of the video if the app goes to background. This is achieved by asking the system for
     * extra time in background to let the request finish. If the background task expires the operation will be cancelled.
     */
    JPVideoPlayerContinueInBackground = 1 << 1,

    /**
     * Handles cookies stored in NSHTTPCookieStore by setting
     * NSMutableURLRequest.HTTPShouldHandleCookies = YES;
     */
    JPVideoPlayerHandleCookies = 1 << 2,

    /**
     * Enable to allow untrusted SSL certificates.
     * Useful for testing purposes. Use with caution in production.
     */
    JPVideoPlayerAllowInvalidSSLCertificates = 1 << 3,

    /**
     * Playing video muted.
     */
    JPVideoPlayerMutedPlay = 1 << 4,

    /**
     * Stretch to fill layer bounds.
     */
    JPVideoPlayerLayerVideoGravityResize = 1 << 5,

    /**
     * Preserve aspect ratio; fit within layer bounds.
     * Default value.
     */
    JPVideoPlayerLayerVideoGravityResizeAspect = 1 << 6,

    /**
     * Preserve aspect ratio; fill layer bounds.
     */
    JPVideoPlayerLayerVideoGravityResizeAspectFill = 1 << 7,

    // TODO: Disable cache if need.
};

typedef NS_OPTIONS(NSUInteger, JPVideoPlayerDownloaderOptions) {
    /**
     * Call completion block with nil video/videoData if the image was read from NSURLCache
     * (to be combined with `JPVideoPlayerDownloaderUseNSURLCache`).
     */
    JPVideoPlayerDownloaderIgnoreCachedResponse = 1 << 0,

    /**
     * In iOS 4+, continue the download of the video if the app goes to background. This is achieved by asking the system for
     * extra time in background to let the request finish. If the background task expires the operation will be cancelled.
     */
    JPVideoPlayerDownloaderContinueInBackground = 1 << 1,

    /**
     * Handles cookies stored in NSHTTPCookieStore by setting
     * NSMutableURLRequest.HTTPShouldHandleCookies = YES;
     */
    JPVideoPlayerDownloaderHandleCookies = 1 << 2,

    /**
     * Enable to allow untrusted SSL certificates.
     * Useful for testing purposes. Use with caution in production.
     */
    JPVideoPlayerDownloaderAllowInvalidSSLCertificates = 1 << 3,
};

typedef void(^JPPlayVideoConfiguration)(UIView *_Nonnull view, JPVideoPlayerModel *_Nonnull playerModel);

UIKIT_EXTERN NSString * _Nonnull const JPVideoPlayerDownloadStartNotification;
UIKIT_EXTERN NSString * _Nonnull const JPVideoPlayerDownloadReceiveResponseNotification;
UIKIT_EXTERN NSString * _Nonnull const JPVideoPlayerDownloadStopNotification;
UIKIT_EXTERN NSString * _Nonnull const JPVideoPlayerDownloadFinishNotification;
UIKIT_EXTERN NSString *const JPVideoPlayerErrorDomain;
FOUNDATION_EXTERN const NSRange JPInvalidRange;
static JPLogLevel _logLevel;

#define JPDEPRECATED_ATTRIBUTE(msg) __attribute__((deprecated(msg)));

/**
 * Dispatch block excute on main queue.
 */
void JPDispatchSyncOnMainQueue(dispatch_block_t block);

/**
 * Call this method to check range valid or not.
 *
 * @param range The range wanna check valid.
 *
 * @return Yes means valid, otherwise NO.
 */
BOOL JPValidByteRange(NSRange range);

/**
 * Call this method to check range is valid file range or not.
 *
 * @param range The range wanna check valid.
 *
 * @return Yes means valid, otherwise NO.
 */
BOOL JPValidFileRange(NSRange range);

/**
 * Call this method to check the end point of range1 is equal to the start point of range2,
 * or the end point of range2 is equal to the start point of range2,
 * or this two range have intersection and the intersection greater than 0.
 *
 * @param range1 A file range.
 * @param range2 A file range.
 *
 * @return YES means those two range can be merge, otherwise NO.
 */
BOOL JPRangeCanMerge(NSRange range1, NSRange range2);

/**
 * Convert a range to HTTP range header string.
 *
 * @param range A range.
 *
 * @return HTTP range header string
 */
NSString* JPRangeToHTTPRangeHeader(NSRange range);

/**
 * Generate error object with error message.
 *
 * @param description The error message.
 *
 * @return A `NSError` object.
 */
NSError *JPErrorWithDescription(NSString *description);

#endif

NS_ASSUME_NONNULL_END
