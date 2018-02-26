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

@property(nonatomic, assign) NSUInteger offset;

@property(nonatomic, assign) NSUInteger requestLength;

@property(nonatomic, assign) BOOL haveDataSaved;

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
        pthread_mutex_init(&(_lock), NULL);
        _expectedSize = 0;
        _receivedSize = 0;
        _runningTask = nil;
        _haveDataSaved = NO;
        _offset = 0;
        _requestLength = NO;

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

- (void)downloadVideoWithRequestTask:(JPResourceLoadingRequestWebTask *)requestTask
                     downloadOptions:(JPVideoPlayerDownloaderOptions)downloadOptions {
    JPDebugLog(@"Downloader received a request task");
    NSParameterAssert(requestTask);
    // The URL will be used as the key to the callbacks dictionary so it cannot be nil.
    // If it is nil immediately call the completed block with no video or data.
    if (requestTask.customURL == nil) {
        NSError *error = [NSError errorWithDomain:JPVideoPlayerErrorDomain
                                             code:0
                                         userInfo:@{NSLocalizedDescriptionKey : @"Please check the download URL, because it is nil"}];
        [self callCompleteDelegateIfNeedWithError:error];
        return;
    }

    [self reset];
    _requestTask = requestTask;
    _downloaderOptions = downloadOptions;
    [self startDownloadOpeartionWithRequestTask:requestTask
                                        options:downloadOptions];
}

- (void)cancel {
    pthread_mutex_lock(&_lock);
    if (self.runningTask) {
        [self.runningTask cancel];
        [self reset];
    }
    pthread_mutex_unlock(&_lock);
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

    self.offset = 0;
    self.requestLength = 0;
    if (!(requestTask.response && ![requestTask.response jp_supportRange])) {
        NSString *rangeValue = JPRangeToHTTPRangeHeader(requestTask.requestRange);
        if (rangeValue) {
            [request setValue:rangeValue forHTTPHeaderField:@"Range"];
            self.offset = requestTask.requestRange.location;
            self.requestLength = requestTask.requestRange.length;
        }
    }
    if (!self.runningTask) {
        self.runningTask = requestTask;
        requestTask.request = request;
        requestTask.unownedSession = self.session;
    }
}


#pragma mark - NSURLSessionDataDelegate

- (void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task
willPerformHTTPRedirection:(NSHTTPURLResponse *)response
        newRequest:(NSURLRequest *)request
        completionHandler:(void (^)(NSURLRequest * _Nullable))completionHandler {
    if (response) {
        JPDebugLog(@"URLSession will perform HTTP redirection");
        self.requestTask.loadingRequest.redirect = request;
    }
    if(completionHandler){
        completionHandler(request);
    }
}

- (void)URLSession:(NSURLSession *)session
          dataTask:(NSURLSessionDataTask *)dataTask
didReceiveResponse:(NSURLResponse *)response
 completionHandler:(void (^)(NSURLSessionResponseDisposition disposition))completionHandler {
    JPDebugLog(@"URLSession did receive response");
    //'304 Not Modified' is an exceptional one.
    if (![response respondsToSelector:@selector(statusCode)] || (((NSHTTPURLResponse *)response).statusCode < 400 && ((NSHTTPURLResponse *)response).statusCode != 304)) {

        NSInteger expected = MAX((NSInteger)response.expectedContentLength, 0);
        self.expectedSize = expected;

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

            if (!self.requestTask.response && response) {
                if ([response isKindOfClass:[NSHTTPURLResponse class]]) {
                    self.requestTask.response = (NSHTTPURLResponse *)response;
                    [self.requestTask.cacheFile storeResponse:self.requestTask.response];
                    [self.requestTask.loadingRequest jp_fillContentInformationWithResponse:self.requestTask.response];
                }
                if (![(NSHTTPURLResponse *)response jp_supportRange]) {
                    self.offset = 0;
                }
                if (self.offset == NSUIntegerMax) {
                    self.offset = (NSUInteger)self.requestTask.response.jp_fileLength - self.requestLength;
                }
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
        [self.runningTask cancel];
        
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
    self.receivedSize += data.length;
    if (data.bytes && [self.requestTask.cacheFile storeVideoData:data atOffset:self.offset synchronize:NO]) {
        self.haveDataSaved = YES;
        self.offset += [data length];
        [self.requestTask.loadingRequest.dataRequest respondWithData:data];

        static BOOL _needLog = YES;
        if(_needLog) {
            _needLog = NO;
            JPDebugLog(@"Did respond loadingRequest dataRequest with data, data length is: %u", data.length);
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t) (1.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                _needLog = YES;
            });
        }
    }

    JPDispatchSyncOnMainQueue(^{
        if (self.delegate && [self.delegate respondsToSelector:@selector(downloader:didReceiveData:receivedSize:expectedSize:)]) {
            [self.delegate downloader:self
                       didReceiveData:data
                         receivedSize:self.receivedSize
                         expectedSize:self.expectedSize];
        }
    });
}

- (void)URLSession:(NSURLSession *)session
              task:(NSURLSessionTask *)task
didCompleteWithError:(NSError *)error {
    [self synchronizeCacheFileIfNeeded];
    if(task.taskIdentifier != self.requestTask.dataTask.taskIdentifier){
        JPDebugLog(@"URLSession did complete a dataTask, but not flying dataTask, id is: %d", task.taskIdentifier);
        [task.webTask requestDidCompleteWithError:error];
        return;
    }

    JPDebugLog(@"URLSession did complete a dataTask, id is %ld, with error: %@", task.taskIdentifier, error);
    JPDispatchSyncOnMainQueue(^{
        [self.requestTask requestDidCompleteWithError:error];
        [self reset];
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

- (void)synchronizeCacheFileIfNeeded {
    if (self.haveDataSaved) {
        [self.requestTask.cacheFile synchronize];
    }
}

- (void)reset {
    self.runningTask = nil;
    self.expectedSize = 0;
    self.receivedSize = 0;
}

@end
