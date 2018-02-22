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

NS_ASSUME_NONNULL_BEGIN

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

@interface JPVideoPlayerDownloaderOperation : NSObject

/**
 * The request used by the operation's task.
 */
@property (strong, nonatomic, readonly, nullable) NSURLRequest *request;

/**
 * The operation's task
 */
@property (strong, nonatomic, readonly, nullable) NSURLSessionDataTask *dataTask;

/**
 * The JPVideoPlayerDownloaderOptions for the receiver.
 */
@property (assign, nonatomic, readonly) JPVideoPlayerDownloaderOptions options;

/**
 *  Initializes a `JPVideoPlayerDownloaderOperation` object.
 *
 *  @see JPVideoPlayerDownloaderOperation.
 *
 *  @param request        the URL request.
 *  @param session        the URL session in which this operation will run.
 *  @param options        downloader options.
 *
 *  @return the initialized instance.
 */
- (nonnull instancetype)initWithRequest:(nullable NSURLRequest *)request
                              inSession:(nullable NSURLSession *)session
                                options:(JPVideoPlayerDownloaderOptions)options NS_DESIGNATED_INITIALIZER;

- (void)start;

- (void)cancel;

@end

typedef NSDictionary<NSString *, NSString *> JPHTTPHeadersDictionary;

typedef NSMutableDictionary<NSString *, NSString *> JPHTTPHeadersMutableDictionary;

typedef JPHTTPHeadersDictionary * _Nullable (^JPVideoPlayerDownloaderHeadersFilterBlock)(NSURL * _Nullable url, JPHTTPHeadersDictionary * _Nullable headers);

typedef void(^JPFetchExpectedSizeCompletion)(NSURL *url, NSUInteger expectedSize, NSError *_Nullable error);

@class JPVideoPlayerDownloader;

@protocol JPVideoPlayerDownloaderDelegate<NSObject>

@optional

/**
 * This method will be called when received response from web,
 * this method will execute on main-thread.
 *
 * @param downloader The current instance.
 * @param response   The response content.
 */
- (void)downloader:(JPVideoPlayerDownloader *)downloader
didReceiveResponse:(NSURLResponse *)response;

/**
 * This method will be called when received data.
 * this method will execute on any-thread.
 *
 * @param downloader   The current instance.
 * @param data         The received new data.
 * @param receivedSize The size of received data.
 * @param expectedSize The expexted size of request.
 */
- (void)downloader:(JPVideoPlayerDownloader *)downloader
    didReceiveData:(NSData *)data
      receivedSize:(NSUInteger)receivedSize
      expectedSize:(NSUInteger)expectedSize;

/**s
 * This method will be called when request completed or some error happened other situations.
 * this method will execute on main-thread.
 *
 * @param downloader The current instance.
 * @param error      The error when request, maybe nil if successed.
 */
- (void)downloader:(JPVideoPlayerDownloader *)downloader
didCompleteWithError:(NSError *)error;

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
 *  The timeout value (in seconds) for the download operation. Default: 15.0s.
 */
@property (assign, nonatomic) NSTimeInterval downloadTimeout;

/**
 * The current url, may nil if no download operation.
 */
@property (nonatomic, strong, readonly, nullable) NSURL *url;

/**
 * The current downloaderOptions, may nil if no download operation.
 */
@property(nonatomic, assign) JPVideoPlayerDownloaderOptions downloaderOptions;

@property (nonatomic, weak) id<JPVideoPlayerDownloaderDelegate> delegate;

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
 * Start download video data for given url.
 *
 * @param url             The URL of the video to download.
 * @param downloadOptions The options to be used for this download.
 */
- (void)downloadVideoWithURL:(NSURL *)url
             downloadOptions:(JPVideoPlayerDownloaderOptions)downloadOptions;

/**
 * Cancels a download that was previously queued using -downloadVideoWithURL:options:progress:completion:
 */
- (void)cancel;

@end

NS_ASSUME_NONNULL_END
