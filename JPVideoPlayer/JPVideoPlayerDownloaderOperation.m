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

#import "JPVideoPlayerDownloaderOperation.h"

@interface JPVideoPlayerDownloaderOperation()

// This is weak because it is injected by whoever manages this session. If this gets nil-ed out, we won't be able to run.
// the task associated with this operation.
@property (weak, nonatomic, nullable) NSURLSession *unownedSession;

@property (strong, nonatomic, readwrite, nullable) NSURLSessionDataTask *dataTask;

@property (assign, nonatomic) UIBackgroundTaskIdentifier backgroundTaskId;

@property(nonatomic, assign, getter=isCancelled) BOOL cancelled;


@end

@implementation JPVideoPlayerDownloaderOperation

- (nonnull instancetype)init{
    NSAssert(NO, @"please use given init method");
    return [self initWithRequest:nil inSession:nil options:0];
}

- (nonnull instancetype)initWithRequest:(nullable NSURLRequest *)request
                              inSession:(nullable NSURLSession *)session
                                options:(JPVideoPlayerDownloaderOptions)options {
    if ((self = [super init])) {
        _request = [request copy];
        _options = options;
        _unownedSession = session;
    }
    return self;
}


#pragma mark - Public

- (void)start {
    @synchronized (self) {
        if (self.isCancelled) {
            return;
        }
        Class UIApplicationClass = NSClassFromString(@"UIApplication");
        BOOL hasApplication = UIApplicationClass && [UIApplicationClass respondsToSelector:@selector(sharedApplication)];
        if (hasApplication && [self shouldContinueWhenAppEntersBackground]) {
            __weak __typeof__ (self) wself = self;
            UIApplication * app = [UIApplicationClass performSelector:@selector(sharedApplication)];
            self.backgroundTaskId = [app beginBackgroundTaskWithExpirationHandler:^{
                __strong __typeof (wself) sself = wself;
                
                if (sself) {
                    [sself cancel];
                    [app endBackgroundTask:sself.backgroundTaskId];
                    sself.backgroundTaskId = UIBackgroundTaskInvalid;
                }
            }];
        }
        
        NSURLSession *session = self.unownedSession;
        self.dataTask = [session dataTaskWithRequest:self.request];
    }
    
    [self.dataTask resume];
    
    if (self.dataTask) {
        dispatch_main_async_safe(^{
            [[NSNotificationCenter defaultCenter] postNotificationName:JPVideoPlayerDownloadStartNotification object:self];
        });
    }
    
    if (self.backgroundTaskId != UIBackgroundTaskInvalid) {
        UIApplication * app = [UIApplication performSelector:@selector(sharedApplication)];
        [app endBackgroundTask:self.backgroundTaskId];
        self.backgroundTaskId = UIBackgroundTaskInvalid;
    }
}

- (void)cancel {
    @synchronized (self) {
        self.cancelled = YES;
        [self cancelInternal];
    }
}


#pragma mark - Private

- (void)cancelInternal {
    if (self.dataTask) {
        [self.dataTask cancel];
        dispatch_main_async_safe(^{
            [[NSNotificationCenter defaultCenter] postNotificationName:JPVideoPlayerDownloadStopNotification object:self];
        });
    }
}

- (BOOL)shouldContinueWhenAppEntersBackground {
    return self.options & JPVideoPlayerDownloaderContinueInBackground;
}

@end
