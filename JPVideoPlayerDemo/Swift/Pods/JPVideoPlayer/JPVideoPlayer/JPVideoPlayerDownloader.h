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


#import <Foundation/Foundation.h>
#import "JPVideoPlayerCompat.h"

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
    
    /**
     * Use this flag to display progress view when play video from web.
     */
    JPVideoPlayerDownloaderShowProgressView = 1 << 4,
    
    /**
     * Use this flag to display activity indicator view when video player is buffering.
     */
    JPVideoPlayerDownloaderShowActivityIndicatorView = 1 << 5,
};

typedef void(^JPVideoPlayerDownloaderProgressBlock)(NSData * _Nullable data, NSInteger receivedSize, NSInteger expectedSize, NSString *_Nullable tempCachedVideoPath, NSURL * _Nullable targetURL);

typedef void(^JPVideoPlayerDownloaderErrorBlock)(NSError *_Nullable error);

typedef NSDictionary<NSString *, NSString *> JPHTTPHeadersDictionary;

typedef NSMutableDictionary<NSString *, NSString *> JPHTTPHeadersMutableDictionary;

typedef JPHTTPHeadersDictionary * _Nullable (^JPVideoPlayerDownloaderHeadersFilterBlock)(NSURL * _Nullable url, JPHTTPHeadersDictionary * _Nullable headers);

/**
 *  A token associated with each download. Can be used to cancel a download.
 */
@interface JPVideoPlayerDownloadToken : NSObject

@property (nonatomic, strong, nullable) NSURL *url;

@property (nonatomic, strong, nullable) id downloadOperationCancelToken;

@end

@interface JPVideoPlayerDownloader : NSObject

/**
 *  Set the default URL credential to be set for request operations.
 */
@property (strong, nonatomic, nullable) NSURLCredential *urlCredential;

/**
 * Set username
 */
@property (strong, nonatomic, nullable) NSString *username;

/**
 * Set password
 */
@property (strong, nonatomic, nullable) NSString *password;

/**
 * Set filter to pick headers for downloading image HTTP request.
 *
 * This block will be invoked for each downloading image request, returned
 * NSDictionary will be used as headers in corresponding HTTP request.
 */
@property (nonatomic, copy, nullable) JPVideoPlayerDownloaderHeadersFilterBlock headersFilter;

/**
 * Creates an instance of a downloader with specified session configuration.
 * *Note*: `timeoutIntervalForRequest` is going to be overwritten.
 * @return new instance of downloader class
 */
- (nonnull instancetype)initWithSessionConfiguration:(nullable NSURLSessionConfiguration *)sessionConfiguration NS_DESIGNATED_INITIALIZER;

/**
 *  Singleton method, returns the shared instance.
 *
 *  @return global shared instance of downloader class.
 */
+ (nonnull instancetype)sharedDownloader;

/**
 * Set a value for a HTTP header to be appended to each download HTTP request.
 *
 * @param value The value for the header field. Use `nil` value to remove the header.
 * @param field The name of the header field to set.
 */
- (void)setValue:(nullable NSString *)value forHTTPHeaderField:(nullable NSString *)field;

/**
 * Returns the value of the specified HTTP header field.
 *
 * @return The value associated with the header field field, or `nil` if there is no corresponding header field.
 */
- (nullable NSString *)valueForHTTPHeaderField:(nullable NSString *)field;

/**
 *  The timeout value (in seconds) for the download operation. Default: 15.0.
 */
@property (assign, nonatomic) NSTimeInterval downloadTimeout;

/**
 * Creates a JPVideoPlayerDownloader async downloader instance with a given URL.
 *
 * @param url            The URL to the video to download.
 * @param options        The options to be used for this download.
 * @param progressBlock  A block called repeatedly while the video is downloading.
 * @param errorBlock     A block called once the download happens some error.
 *
 * @return A token (@see JPVideoPlayerDownloadToken) that can be passed to -cancel: to cancel this operation.
 */
- (nullable JPVideoPlayerDownloadToken *)downloadVideoWithURL:(nullable NSURL *)url options:(JPVideoPlayerDownloaderOptions)options progress:(nullable JPVideoPlayerDownloaderProgressBlock)progressBlock completed:(nullable JPVideoPlayerDownloaderErrorBlock)errorBlock;

/**
 * Cancels a download that was previously queued using -downloadVideoWithURL:options:progress:completed:
 *
 * @param token The token received from -downloadVideoWithURL:options:progress:completed: that should be canceled.
 */
- (void)cancel:(nullable JPVideoPlayerDownloadToken *)token;

/**
 * Cancels all download operations in the queue.
 */
- (void)cancelAllDownloads;

@end
