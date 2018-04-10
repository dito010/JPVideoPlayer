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

NS_ASSUME_NONNULL_BEGIN

@class JPVideoPlayerDownloader, JPResourceLoadingRequestTask;
@class JPResourceLoadingRequestWebTask;

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
@property (nonatomic, weak, readonly, nullable) JPResourceLoadingRequestWebTask *runningTask;

/**
 * The current downloaderOptions, may nil if no download operation.
 */
@property (nonatomic, assign, readonly) JPVideoPlayerDownloaderOptions downloaderOptions;

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
 * Start download video data for given url.
 *
 * @param requestTask     A abstract instance packageing the loading request.
 * @param downloadOptions The options to be used for this download.
 */
- (void)downloadVideoWithRequestTask:(JPResourceLoadingRequestWebTask *)requestTask
                     downloadOptions:(JPVideoPlayerDownloaderOptions)downloadOptions;

/**
 * Cancel current download task.
 */
- (void)cancel;

@end

NS_ASSUME_NONNULL_END
