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
#import "JPVideoPlayerDownloader.h"

extern NSString * _Nonnull const JPVideoPlayerDownloadStartNotification;
extern NSString * _Nonnull const JPVideoPlayerDownloadReceiveResponseNotification;
extern NSString * _Nonnull const JPVideoPlayerDownloadStopNotification;
extern NSString * _Nonnull const JPVideoPlayerDownloadFinishNotification;

@interface JPVideoPlayerDownloaderOperation : NSOperation<NSURLSessionTaskDelegate, NSURLSessionDataDelegate>

/**
 * The request used by the operation's task.
 */
@property (strong, nonatomic, readonly, nullable) NSURLRequest *request;

/**
 * The operation's task
 */
@property (strong, nonatomic, readonly, nullable) NSURLSessionTask *dataTask;

/**
 * The credential used for authentication challenges in `-connection:didReceiveAuthenticationChallenge:`.
 *
 * This will be overridden by any shared credentials that exist for the username or password of the request URL, if present.
 */
@property (nonatomic, strong, nullable) NSURLCredential *credential;

/**
 * The JPVideoPlayerDownloaderOptions for the receiver.
 */
@property (assign, nonatomic, readonly) JPVideoPlayerDownloaderOptions options;

/**
 * The expected size of data.
 */
@property (assign, nonatomic) NSUInteger expectedSize;

/**
 * The response returned by the operation's connection.
 */
@property (strong, nonatomic, nullable) NSURLResponse *response;

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
- (nonnull instancetype)initWithRequest:(nullable NSURLRequest *)request inSession:(nullable NSURLSession *)session options:(JPVideoPlayerDownloaderOptions)options NS_DESIGNATED_INITIALIZER;

/**
 *  Adds handlers for progress and completion. Returns a token that can be passed to -cancel: to cancel this set callbacks.
 *
 *  @param progressBlock  the block executed when a new chunk of data arrives.
 *  @param errorBlock     A block called once the download happens some error.
 *
 *  @return the token to use to cancel this set of handlers.
 */
- (nullable id)addHandlersForProgress:(nullable JPVideoPlayerDownloaderProgressBlock)progressBlock error:(nullable JPVideoPlayerDownloaderErrorBlock)errorBlock;

/**
 *  Cancels a set of callbacks. Once all callbacks are canceled, the operation is cancelled.
 *
 *  @param token the token representing a set of callbacks to cancel
 *
 *  @return YES if the operation was stopped because this was the last token to be canceled. NO otherwise.
 */
- (BOOL)cancel:(nullable id)token;

@end
