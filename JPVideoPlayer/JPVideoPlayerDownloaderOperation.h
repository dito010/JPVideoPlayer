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
- (nonnull instancetype)initWithRequest:(nullable NSURLRequest *)request inSession:(nullable NSURLSession *)session options:(JPVideoPlayerDownloaderOptions)options NS_DESIGNATED_INITIALIZER;

- (void)start;

- (void)cancel;

@end
