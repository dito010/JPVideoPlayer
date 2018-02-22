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

#import "JPVideoPlayerDownloader.h"
#import <pthread.h>
#import "JPVideoPlayerCachePath.h"
#import "JPVideoPlayerManager.h"


@interface JPVideoPlayerDownloaderOperation : NSObject

/**
 * The request used by the operation's task.
 */
@property (strong, nonatomic, readonly, nullable) NSURLRequest *request;

/**
 * The operation's task
 */
@property (strong, nonatomic, nullable) NSURLSessionDataTask *dataTask;

/**
 * The JPVideoPlayerDownloaderOptions for the receiver.
 */
@property (assign, nonatomic, readonly) JPVideoPlayerDownloaderOptions options;

// This is weak because it is injected by whoever manages this session. If this gets nil-ed out, we won't be able to run.
// the task associated with this operation.
@property (weak, nonatomic, nullable) NSURLSession *unownedSession;

@property (assign, nonatomic) UIBackgroundTaskIdentifier backgroundTaskId;

@property(nonatomic, assign, getter=isCancelled) BOOL cancelled;

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
        JPDispatchSyncOnMainQueue(^{
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
        JPDispatchSyncOnMainQueue(^{
            [[NSNotificationCenter defaultCenter] postNotificationName:JPVideoPlayerDownloadStopNotification object:self];
        });
    }
}

- (BOOL)shouldContinueWhenAppEntersBackground {
    return self.options & JPVideoPlayerDownloaderContinueInBackground;
}

@end

@interface JPVideoPlayerDownloader()<NSURLSessionDelegate, NSURLSessionDataDelegate>

@property (strong, nonatomic, nullable) JPHTTPHeadersMutableDictionary *HTTPHeaders;

// The session in which data tasks will run
@property (strong, nonatomic) NSURLSession *session;

// The size of receivered data now.
@property(nonatomic, assign)NSUInteger receiveredSize;

/*
 * expectedSize.
 */
@property(nonatomic, assign) NSUInteger expectedSize;

@property (nonatomic) pthread_mutex_t lock;

/*
 * the running operation.
 */
@property(nonatomic, strong, nullable) JPVideoPlayerDownloaderOperation *runningOperation;

/**
 * 请求响应.
 */
@property (nonatomic, strong) NSURLResponse *response;

@end

@implementation JPVideoPlayerDownloader

- (void)dealloc {
    pthread_mutex_destroy(&_lock);
    [self.session invalidateAndCancel];
    self.session = nil;
}

+ (nonnull instancetype)sharedDownloader {
    static dispatch_once_t once;
    static id instance;
    dispatch_once(&once, ^{
        instance = [self new];
    });
    return instance;
}

- (nonnull instancetype)init {
    return [self initWithSessionConfiguration:[NSURLSessionConfiguration defaultSessionConfiguration]];
}

- (nonnull instancetype)initWithSessionConfiguration:(nullable NSURLSessionConfiguration *)sessionConfiguration {
    if ((self = [super init])) {
        pthread_mutex_init(&(_lock), NULL);
        _HTTPHeaders = [@{@"Accept": @"video/mp4"} mutableCopy];
        _expectedSize = 0;
        _receiveredSize = 0;

        if (!sessionConfiguration) {
            sessionConfiguration = [NSURLSessionConfiguration defaultSessionConfiguration];
        }
        sessionConfiguration.timeoutIntervalForRequest = 15.f;

        /**
         *  Create the session for this task
         *  We send nil as delegate queue so that the session creates a serial operation queue for performing all delegate
         *  method calls and downloadCompletion handler calls.
         */
        self.session = [NSURLSession sessionWithConfiguration:sessionConfiguration delegate:self delegateQueue:nil];
    }
    return self;
}


#pragma mark - Public

- (void)setValue:(nullable NSString *)value forHTTPHeaderField:(nullable NSString *)field {
    NSParameterAssert(field);
    if (!field) {
        return;
    }

    value ? self.HTTPHeaders[field] = value : [self.HTTPHeaders removeObjectForKey:field];
}

- (nullable NSString *)valueForHTTPHeaderField:(nullable NSString *)field {
    NSParameterAssert(field);
    if (!field) {
        return nil;
    }

    return self.HTTPHeaders[field];
}

- (void)downloadVideoWithURL:(NSURL *)url
             downloadOptions:(JPVideoPlayerDownloaderOptions)downloadOptions {
    NSParameterAssert(url.absoluteString.length);
    if (self.runningOperation) {
        [self cancel];
    }

    _url = url;
    _downloaderOptions = downloadOptions;

    // The URL will be used as the key to the callbacks dictionary so it cannot be nil. If it is nil immediately call the completed block with no video or data.
    if (url == nil) {
        NSError *error = [NSError errorWithDomain:JPVideoPlayerErrorDomain code:0 userInfo:@{NSLocalizedDescriptionKey : @"Please check the URL, because it is nil"}];
        [self callCompleteDelegateIfNeedWithError:error];
        return;
    }

    [self startDownloadOpeartionWithURL:url options:downloadOptions];
}

- (void) cancel {
    pthread_mutex_lock(&_lock);
    if (self.runningOperation) {
        [self.runningOperation cancel];
        self.runningOperation = nil;
        self.expectedSize = 0;
        self.receiveredSize = 0;
    }
    JPLogDebug(@"Cancel current request");
    pthread_mutex_unlock(&_lock);
}


#pragma mark - Download Operation

- (void)startDownloadOpeartionWithURL:(NSURL *)url options:(JPVideoPlayerDownloaderOptions)options {
    if (!self.downloadTimeout) {
        self.downloadTimeout = 15.f;
    }

    // In order to prevent from potential duplicate caching (NSURLCache + JPVideoPlayerCache) we disable the cache for video requests if told otherwise.
    NSURLComponents *actualURLComponents = [[NSURLComponents alloc] initWithURL:url resolvingAgainstBaseURL:NO];
    actualURLComponents.scheme = url.scheme;
    NSMutableURLRequest *request = [[NSMutableURLRequest alloc] initWithURL:[actualURLComponents URL] cachePolicy:(NSURLRequestReloadIgnoringLocalCacheData) timeoutInterval:self.downloadTimeout];

    request.HTTPShouldHandleCookies = (options & JPVideoPlayerDownloaderHandleCookies);
    request.HTTPShouldUsePipelining = YES;
    if (self.HTTPHeaders.allKeys.count) {
        [self.HTTPHeaders enumerateKeysAndObjectsUsingBlock:^(NSString * _Nonnull key, NSString * _Nonnull obj, BOOL * _Nonnull stop) {

            [request setValue:obj forHTTPHeaderField:key];

        }];
    }

    if (!self.urlCredential && self.username && self.password) {
        self.urlCredential = [NSURLCredential credentialWithUser:self.username password:self.password persistence:NSURLCredentialPersistenceForSession];
    }

    if (!self.runningOperation) {
        self.runningOperation = [[JPVideoPlayerDownloaderOperation alloc] initWithRequest:request inSession:self.session options:options];
    }
    [self.runningOperation start];
    JPLogDebug(@"Send a new request");
}


#pragma mark - NSURLSessionDataDelegate

- (void)URLSession:(NSURLSession *)session
          dataTask:(NSURLSessionDataTask *)dataTask
didReceiveResponse:(NSURLResponse *)response
 completionHandler:(void (^)(NSURLSessionResponseDisposition disposition))completionHandler {

    //'304 Not Modified' is an exceptional one.
    if (![response respondsToSelector:@selector(statusCode)] || (((NSHTTPURLResponse *)response).statusCode < 400 && ((NSHTTPURLResponse *)response).statusCode != 304)) {

        NSInteger expected = MAX((NSInteger)response.expectedContentLength, 0);
        self.expectedSize = expected;
        self.response = response;

        // May the free size of the device less than the expected size of the video data.
        if (![[JPVideoPlayerCache sharedCache] haveFreeSizeToCacheFileWithSize:expected]) {
            if (completionHandler) {
                completionHandler(NSURLSessionResponseCancel);
            }
            JPDispatchSyncOnMainQueue(^{
                [[NSNotificationCenter defaultCenter] postNotificationName:JPVideoPlayerDownloadStopNotification object:self];
                NSError *error = [NSError errorWithDomain:JPVideoPlayerErrorDomain code:0 userInfo:@{NSLocalizedDescriptionKey : @"No enough size of device to cache the video data"}];
                [self callCompleteDelegateIfNeedWithError:error];
            });
            [self cancel];
        }
        else{
            if (completionHandler) {
                completionHandler(NSURLSessionResponseAllow);
            }
            JPDispatchSyncOnMainQueue(^{
                if (self.delegate && [self.delegate respondsToSelector:@selector(downloader:didReceiveResponse:)]) {
                    [self.delegate downloader:self didReceiveResponse:response];
                }
                [[NSNotificationCenter defaultCenter] postNotificationName:JPVideoPlayerDownloadReceiveResponseNotification object:self];
            });
        }

    }
    else {
        if (completionHandler) {
            completionHandler(NSURLSessionResponseCancel);
        }
        [self.runningOperation cancel];
        
        JPDispatchSyncOnMainQueue(^{
            NSString *errorMsg = [NSString stringWithFormat:@"The statusCode of response is: %ld", ((NSHTTPURLResponse *)response).statusCode];
            NSError *error = [NSError errorWithDomain:JPVideoPlayerErrorDomain code:0 userInfo:@{NSLocalizedDescriptionKey : errorMsg}];
            [self callCompleteDelegateIfNeedWithError:error];
            [[NSNotificationCenter defaultCenter] postNotificationName:JPVideoPlayerDownloadStopNotification object:self];
        });
    }
}

- (void)URLSession:(NSURLSession *)session
          dataTask:(NSURLSessionDataTask *)dataTask
    didReceiveData:(NSData *)data {
    self.receiveredSize += data.length;
    if (self.delegate && [self.delegate respondsToSelector:@selector(downloader:didReceiveData:receivedSize:expectedSize:)]) {
        [self.delegate downloader:self
                   didReceiveData:data
                     receivedSize:self.receiveredSize
                     expectedSize:self.expectedSize];
    }

}

- (void)URLSession:(NSURLSession *)session
              task:(NSURLSessionTask *)task
didCompleteWithError:(NSError *)error {
    if (self.runningOperation.dataTask != task) {
        return;
    }

    JPDispatchSyncOnMainQueue(^{
        if (!error) {
            [[NSNotificationCenter defaultCenter] postNotificationName:JPVideoPlayerDownloadFinishNotification object:self];
        }
        if (self.delegate && [self.delegate respondsToSelector:@selector(downloader:didCompleteWithError:)]) {
            [self.delegate downloader:self didCompleteWithError:error];
        }
    });
}

- (void)URLSession:(NSURLSession *)session
              task:(NSURLSessionTask *)task
didReceiveChallenge:(NSURLAuthenticationChallenge *)challenge
        downloadCompletionHandler:(void (^)(NSURLSessionAuthChallengeDisposition disposition, NSURLCredential *credential))downloadCompletionHandler {

    NSURLSessionAuthChallengeDisposition disposition = NSURLSessionAuthChallengePerformDefaultHandling;
    __block NSURLCredential *credential = nil;

    if ([challenge.protectionSpace.authenticationMethod isEqualToString:NSURLAuthenticationMethodServerTrust]) {
        if (!(self.runningOperation.options & JPVideoPlayerDownloaderAllowInvalidSSLCertificates)) {
            disposition = NSURLSessionAuthChallengePerformDefaultHandling;
        }
        else {
            credential = [NSURLCredential credentialForTrust:challenge.protectionSpace.serverTrust];
            disposition = NSURLSessionAuthChallengeUseCredential;
        }
    }
    else {
        if (challenge.previousFailureCount == 0) {
            if (self.urlCredential) {
                credential = self.urlCredential;
                disposition = NSURLSessionAuthChallengeUseCredential;
            }
            else {
                disposition = NSURLSessionAuthChallengeCancelAuthenticationChallenge;
            }
        }
        else {
            disposition = NSURLSessionAuthChallengeCancelAuthenticationChallenge;
        }
    }

    if (downloadCompletionHandler) {
        downloadCompletionHandler(disposition, credential);
    }
}

- (void)URLSession:(NSURLSession *)session
          dataTask:(NSURLSessionDataTask *)dataTask
 willCacheResponse:(NSCachedURLResponse *)proposedResponse
downloadCompletionHandler:(void (^)(NSCachedURLResponse *cachedResponse))downloadCompletionHandler {

    // If this method is called, it means the response wasn't read from cache
    NSCachedURLResponse *cachedResponse = proposedResponse;

    if (self.runningOperation.request.cachePolicy == NSURLRequestReloadIgnoringLocalCacheData) {
        // Prevents caching of responses
        cachedResponse = nil;
    }
    if (downloadCompletionHandler) {
        downloadCompletionHandler(cachedResponse);
    }
}


#pragma mark - Private

- (void)callCompleteDelegateIfNeedWithError:(NSError *)error {
    if (self.delegate && [self.delegate respondsToSelector:@selector(downloader:didCompleteWithError:)]) {
        [self.delegate downloader:self didCompleteWithError:error];
    }
}

@end
