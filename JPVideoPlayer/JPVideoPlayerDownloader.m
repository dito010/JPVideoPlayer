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

#import "JPVideoPlayerDownloader.h"
#import <pthread.h>
#import "JPVideoPlayerManager.h"
#import "JPResourceLoadingRequestTask.h"
#import "JPVideoPlayerCacheFile.h"
#import "JPVideoPlayerSupportUtils.h"

@interface JPVideoPlayerDownloader()<NSURLSessionDelegate, NSURLSessionDataDelegate>

// The session in which data tasks will run
@property (strong, nonatomic) NSURLSession *session;

// The size of received data now.
@property(nonatomic, assign)NSUInteger receivedSize;

/*
 * The expected size.
 */
@property(nonatomic, assign) NSUInteger expectedSize;

@property (nonatomic) pthread_mutex_t lock;

/*
 * The running operation.
 */
@property(nonatomic, weak, nullable) JPResourceLoadingRequestWebTask *runningTask;

@end

@implementation JPVideoPlayerDownloader

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
        pthread_mutexattr_t mutexattr;
        pthread_mutexattr_init(&mutexattr);
        pthread_mutexattr_settype(&mutexattr, PTHREAD_MUTEX_RECURSIVE);
        pthread_mutex_init(&_lock, &mutexattr);
        _expectedSize = 0;
        _receivedSize = 0;
        _runningTask = nil;

        if (!sessionConfiguration) {
            sessionConfiguration = [NSURLSessionConfiguration defaultSessionConfiguration];
        }
        sessionConfiguration.timeoutIntervalForRequest = 15.f;

        /**
         *  Create the session for this task.
         *  We send nil as delegate queue so that the session creates a serial operation queue for performing all delegate.
         *  method calls and downloadCompletion handler calls.
         */
        self.session = [NSURLSession sessionWithConfiguration:sessionConfiguration
                                                     delegate:self
                                                delegateQueue:nil];
    }
    return self;
}


#pragma mark - Public

- (void)downloadVideoWithRequestTask:(JPResourceLoadingRequestWebTask *)requestTask
                     downloadOptions:(JPVideoPlayerDownloaderOptions)downloadOptions {
    NSParameterAssert(requestTask);
    // The URL will be used as the key to the callbacks dictionary so it cannot be nil.
    // If it is nil immediately call the completed block with no video or data.
    if (requestTask.customURL == nil) {
        [self callCompleteDelegateIfNeedWithError:JPErrorWithDescription(@"Please check the download URL, because it is nil")];
        return;
    }

    [self reset];
    _runningTask = requestTask;
    _downloaderOptions = downloadOptions;
    [self startDownloadOpeartionWithRequestTask:requestTask
                                        options:downloadOptions];
}

- (void)cancel {
    int lock = pthread_mutex_trylock(&_lock);
    if (self.runningTask) {
        [self.runningTask cancel];
        [self reset];
    }
    if (!lock) {
        pthread_mutex_unlock(&_lock);
    }
}


#pragma mark - Download Operation

- (void)startDownloadOpeartionWithRequestTask:(JPResourceLoadingRequestWebTask *)requestTask
                                      options:(JPVideoPlayerDownloaderOptions)options {
    if (!self.downloadTimeout) {
        self.downloadTimeout = 15.f;
    }

    // In order to prevent from potential duplicate caching (NSURLCache + JPVideoPlayerCache),
    // we disable the cache for video requests if told otherwise.
    NSMutableURLRequest *request = [[NSMutableURLRequest alloc] initWithURL:requestTask.customURL
                                                                cachePolicy:(NSURLRequestReloadIgnoringLocalCacheData)
                                                            timeoutInterval:self.downloadTimeout];

    request.HTTPShouldHandleCookies = (options & JPVideoPlayerDownloaderHandleCookies);
    request.HTTPShouldUsePipelining = YES;
    if (!self.urlCredential && self.username && self.password) {
        self.urlCredential = [NSURLCredential credentialWithUser:self.username
                                                        password:self.password
                                                     persistence:NSURLCredentialPersistenceForSession];
    }
    NSString *rangeValue = JPRangeToHTTPRangeHeader(requestTask.requestRange);
    if (rangeValue) {
        [request setValue:rangeValue forHTTPHeaderField:@"Range"];
    }

    self.runningTask = requestTask;
    requestTask.request = request;
    requestTask.unownedSession = self.session;
    JPDebugLog(@"Downloader 处理完一个请求");
}


#pragma mark - NSURLSessionDataDelegate

- (void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task
willPerformHTTPRedirection:(NSHTTPURLResponse *)response
        newRequest:(NSURLRequest *)request
        completionHandler:(void (^)(NSURLRequest * _Nullable))completionHandler {
    if (response) {
        JPDebugLog(@"URLSession will perform HTTP redirection");
        self.runningTask.loadingRequest.redirect = request;
    }
    if(completionHandler){
        completionHandler(request);
    }
}

- (void)URLSession:(NSURLSession *)session
          dataTask:(NSURLSessionDataTask *)dataTask
didReceiveResponse:(NSURLResponse *)response
 completionHandler:(void (^)(NSURLSessionResponseDisposition disposition))completionHandler {
    JPDebugLog(@"URLSession 收到响应");
    //'304 Not Modified' is an exceptional one.
    if (![response respondsToSelector:@selector(statusCode)] || (((NSHTTPURLResponse *)response).statusCode < 400 && ((NSHTTPURLResponse *)response).statusCode != 304)) {
        NSInteger expected = MAX((NSInteger)response.expectedContentLength, 0);
        self.expectedSize = expected;
        // Support video / audio only.
        BOOL isSupportMIMEType = [response.MIMEType containsString:@"video"] || [response.MIMEType containsString:@"audio"];
        if(!isSupportMIMEType){
            JPErrorLog(@"Not support MIMEType: %@", response.MIMEType);
            JPDispatchSyncOnMainQueue(^{
                [self cancel];
                [self callCompleteDelegateIfNeedWithError:JPErrorWithDescription([NSString stringWithFormat:@"Not support MIMEType: %@", response.MIMEType])];
                [[NSNotificationCenter defaultCenter] postNotificationName:JPVideoPlayerDownloadStopNotification object:self];
            });
            if (completionHandler) {
                completionHandler(NSURLSessionResponseCancel);
            }
            return;
        }

        // May the free size of the device less than the expected size of the video data.
        if (![[JPVideoPlayerCache sharedCache] haveFreeSizeToCacheFileWithSize:expected]) {
            JPDispatchSyncOnMainQueue(^{
                [self cancel];
                [self callCompleteDelegateIfNeedWithError:JPErrorWithDescription(@"No enough size of device to cache the video data")];
                [[NSNotificationCenter defaultCenter] postNotificationName:JPVideoPlayerDownloadStopNotification object:self];
            });
            if (completionHandler) {
                completionHandler(NSURLSessionResponseCancel);
            }
        }
        else{
            JPDispatchSyncOnMainQueue(^{
                if(!self.runningTask){
                    if (completionHandler) {
                        completionHandler(NSURLSessionResponseCancel);
                    }
                    return;
                }
                [self.runningTask requestDidReceiveResponse:response];
                if (self.delegate && [self.delegate respondsToSelector:@selector(downloader:didReceiveResponse:)]) {
                    [self.delegate downloader:self didReceiveResponse:response];
                }
                [[NSNotificationCenter defaultCenter] postNotificationName:JPVideoPlayerDownloadReceiveResponseNotification object:self];
            });
            if (completionHandler) {
                completionHandler(NSURLSessionResponseAllow);
            }
        }
    }
    else {
        JPDispatchSyncOnMainQueue(^{
            [self cancel];
            NSString *errorMsg = [NSString stringWithFormat:@"The statusCode of response is: %ld", (long)((NSHTTPURLResponse *)response).statusCode];
            [self callCompleteDelegateIfNeedWithError:JPErrorWithDescription(errorMsg)];
            [[NSNotificationCenter defaultCenter] postNotificationName:JPVideoPlayerDownloadStopNotification object:self];
        });
        if (completionHandler) {
            completionHandler(NSURLSessionResponseCancel);
        }
    }
}

- (void)URLSession:(NSURLSession *)session
          dataTask:(NSURLSessionDataTask *)dataTask
    didReceiveData:(NSData *)data {
    // may runningTask is dealloc in main-thread and this method called in sub-thread.
    if(!self.runningTask){
        [self reset];
        return;
    }

    self.receivedSize += data.length;
    [self.runningTask requestDidReceiveData:data
                           storedCompletion:^{
                               JPDispatchSyncOnMainQueue(^{
                                   if (self.delegate && [self.delegate respondsToSelector:@selector(downloader:didReceiveData:receivedSize:expectedSize:)]) {
                                       [self.delegate downloader:self
                                                  didReceiveData:data
                                                    receivedSize:self.receivedSize
                                                    expectedSize:self.expectedSize];
                                   }
                               });
                           }];
}

- (void)URLSession:(NSURLSession *)session
              task:(NSURLSessionTask *)task
didCompleteWithError:(NSError *)error {
    JPDispatchSyncOnMainQueue(^{
        JPDebugLog(@"URLSession 完成了一个请求, id 是 %ld, error 是: %@", task.taskIdentifier, error);
        BOOL completeValid = self.runningTask && task.taskIdentifier == self.runningTask.dataTask.taskIdentifier;
        if(!completeValid){
            JPDebugLog(@"URLSession 完成了一个不是正在请求的请求, id 是: %d", task.taskIdentifier);
            return;
        }

        [self.runningTask requestDidCompleteWithError:error];
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
        if (!(self.runningTask.options & JPVideoPlayerDownloaderAllowInvalidSSLCertificates)) {
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

    if (self.runningTask.request.cachePolicy == NSURLRequestReloadIgnoringLocalCacheData) {
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

- (void)reset {
    JPDebugLog(@"调用了 reset");
    self.runningTask = nil;
    self.expectedSize = 0;
    self.receivedSize = 0;
}

@end
