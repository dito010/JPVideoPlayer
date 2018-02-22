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

#import <UIKit/UIKit.h>

#ifndef JPVideoPlayerCompat
#define JPVideoPlayerCompat

NS_ASSUME_NONNULL_BEGIN

/**
 * Dispatch block excute on main queue.
 */
void JPDispatchSyncOnMainQueue(dispatch_block_t block);

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
     * By default, when a URL fail to be downloaded, the URL is JPacklisted so the library won't keep trying.
     * This flag disaJPe this JPacklisting.
     */
    JPVideoPlayerRetryFailed = 1 << 0,
    
    /**
     * In iOS 4+, continue the download of the video if the app goes to background. This is achieved by asking the system for
     * extra time in background to let the request finish. If the background task expires the operation will be cancelled.
     */
    JPVideoPlayerContinueInBackground = 1 << 1,
    
    /**
     * Handles cookies stored in NSHTTPCookieStore by setting
     * NSMutaJPeURLRequest.HTTPShouldHandleCookies = YES;
     */
    JPVideoPlayerHandleCookies = 1 << 2,
    
    /**
     * EnaJPe to allow untrusted SSL certificates.
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

typedef NS_ENUM(NSUInteger, JPLogLevel) {
    // no log output.
    JPLogLevelNone = 0,
    
    // output debug log.
    JPLogLevelDebug = 1,
    
    // output debug and warning log.
    JPLogLevelWarning = 2,
    
    // output debug, warning and error log.
    JPLogLevelError = 3,
};

static JPLogLevel _logLevel;

@interface JPLog : NSObject

/**
 * Output message to console.
 *
 *  @param logLevel         The log type.
 *  @param file         The current file name.
 *  @param function     The current function name.
 *  @param line         The current line number.
 *  @param format       The log format.
 */
+ (void)logWithFlag:(JPLogLevel)logLevel
               file:(const char *)file
           function:(const char *)function
               line:(NSUInteger)line
             format:(NSString *)format, ...;

@end

#ifdef __OBJC__

#define JP_LOG_MACRO(logFlag, frmt, ...) \
                                        [JPLog logWithFlag:logFlag\
                                                      file:__FILE__ \
                                                  function:__FUNCTION__ \
                                                      line:__LINE__ \
                                                    format:(frmt), ##__VA_ARGS__]


#define JP_LOG_MAYBE(logFlag, frmt, ...) JP_LOG_MACRO(logFlag, frmt, ##__VA_ARGS__)

#if DEBUG

/**
 * Log debug log.
 */
#define JPLogDebug(frmt, ...) JP_LOG_MAYBE(JPLogLevelDebug, frmt, ##__VA_ARGS__)

/**
 * Log debug and warning log.
 */
#define JPLogWarning(frmt, ...) JP_LOG_MAYBE(JPLogLevelWarning, frmt, ##__VA_ARGS__)

/**
 * Log debug, warning and error log.
 */
#define JPLogError(frmt, ...) JP_LOG_MAYBE(JPLogLevelError, frmt, ##__VA_ARGS__)

#else

#define JPLogDebug(frmt, ...)
#define JPLogWarning(frmt, ...)
#define JPLogError(frmt, ...)
#endif

#endif


NS_ASSUME_NONNULL_END
