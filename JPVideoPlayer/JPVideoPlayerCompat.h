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
#ifndef JPVideoPlayerCompat
#define JPVideoPlayerCompat

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

#define dispatch_main_async_safe(block)\
if (strcmp(dispatch_queue_get_label(DISPATCH_CURRENT_QUEUE_LABEL), dispatch_queue_get_label(dispatch_get_main_queue())) == 0) {\
block();\
} else {\
dispatch_async(dispatch_get_main_queue(), block);\
}

UIKIT_EXTERN NSString * _Nonnull const JPVideoPlayerDownloadStartNotification;
UIKIT_EXTERN NSString * _Nonnull const JPVideoPlayerDownloadReceiveResponseNotification;
UIKIT_EXTERN NSString * _Nonnull const JPVideoPlayerDownloadStopNotification;
UIKIT_EXTERN NSString * _Nonnull const JPVideoPlayerDownloadFinishNotification;

UIKIT_EXTERN NSString *const JPVideoPlayerErrorDomain;

#define JPDEPRECATED_ATTRIBUTE(msg) __attribute__((deprecated(msg)));

typedef NS_ENUM(NSInteger, JPVideoPlayerStatus) {
    JPVideoPlayerStatusUnkown,
    JPVideoPlayerStatusBuffering,
    JPVideoPlayerStatusPlaying,
    JPVideoPlayerStatusPause,
    JPVideoPlayerStatusFailed,
    JPVideoPlayerStatusStop
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
     * Use this flag to display progress view when play video from web.
     */
    JPVideoPlayerShowProgressView = 1 << 4,
    
    /**
     * Use this flag to display activity indicator view when video player is buffering.
     */
    JPVideoPlayerShowActivityIndicatorView = 1 << 5,
    
    /**
     * Playing video muted.
     */
    JPVideoPlayerMutedPlay = 1 << 6,
    
    /**
     * Stretch to fill layer bounds.
     */
    JPVideoPlayerLayerVideoGravityResize = 1 << 7,
    
    /**
     * Preserve aspect ratio; fit within layer bounds.
     * Default value.
     */
    JPVideoPlayerLayerVideoGravityResizeAspect = 1 << 8,
    
    /**
     * Preserve aspect ratio; fill layer bounds.
     */
    JPVideoPlayerLayerVideoGravityResizeAspectFill = 1 << 9,
};

#endif

NS_ASSUME_NONNULL_END
