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
#import "JPVideoPlayerDownloaderOperation.h"
#import <pthread.h>
#import "JPVideoPlayerCachePathManager.h"
#import "JPVideoPlayerManager.h"

static NSString *const kProgressCallbackKey = @"www.jpvideplayer.progress.callback";
static NSString *const kErrorCallbackKey = @"www.jpvideplayer.error.callback";
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

@property (copy, nonatomic)JPVideoPlayerDownloaderProgressBlock downloadProgressBlock;

/*
 * downloaddownloadCompletion.
 */
@property(nonatomic, copy) JPVideoPlayerDownloaderCompletion downloadCompletion;

@property (nonatomic) pthread_mutex_t lock;

/*
 * the running operation.
 */
@property(nonatomic, strong, nullable) JPVideoPlayerDownloaderOperation *runningOperation;

/*
 * the fetch expected size downloadCompletion.
 */
@property(nonatomic, copy) JPFetchExpectedSizeCompletion fetchExpectedSizeCompletion;

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
        _downloadProgressBlock = nil;
        _downloadCompletion = nil;
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
                     options:(JPVideoPlayerDownloaderOptions)options
                    progress:(JPVideoPlayerDownloaderProgressBlock)progressBlock
                  completion:(JPVideoPlayerDownloaderCompletion)completion {
    NSParameterAssert(url.absoluteString.length);
    NSParameterAssert(completion);
    
    if (self.runningOperation) {
        [self cancel];
    }
    
    self.downloadProgressBlock = progressBlock;
    self.downloadCompletion = completion;
    
    // The URL will be used as the key to the callbacks dictionary so it cannot be nil. If it is nil immediately call the completed block with no video or data.
    if (url == nil) {
        if (completion) {
            NSError *error = [NSError errorWithDomain:JPVideoPlayerErrorDomain code:0 userInfo:@{NSLocalizedDescriptionKey : @"Please check the URL, because it is nil"}];
            completion(error);
        }
        return;
    }
    
    [self startDownloadOpeartionWithURL:url options:options];
}

- (void)tryToFetchVideoExpectedSizeWithURL:(NSURL *)url
                                   options:(JPVideoPlayerDownloaderOptions)options
                                completion:(JPFetchExpectedSizeCompletion)completion {
    NSParameterAssert(url.absoluteString.length);
    NSParameterAssert(completion);
    
    if (self.runningOperation) {
        [self cancel];
    }
    
    self.fetchExpectedSizeCompletion = completion;
    
    // The URL will be used as the key to the callbacks dictionary so it cannot be nil. If it is nil immediately call the completed block with no video or data.
    if (url == nil) {
        if (completion) {
            NSError *error = [NSError errorWithDomain:JPVideoPlayerErrorDomain code:0 userInfo:@{NSLocalizedDescriptionKey : @"Please check the URL, because it is nil"}];
            completion(url, 0, error);
        }
        return;
    }
    
    [self startDownloadOpeartionWithURL:url options:options];
}

- (void)cancel {
    JPLogDebug(@"Cancel current request");
    pthread_mutex_lock(&_lock);
    if (self.runningOperation) {
        [self.runningOperation cancel];
        self.runningOperation = nil;
        self.expectedSize = 0;
        self.receiveredSize = 0;
    }
    self.downloadProgressBlock = nil;
    self.downloadCompletion = nil;
    self.fetchExpectedSizeCompletion = nil;
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
    JPLogDebug(@"Send new request");
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
            dispatch_async(dispatch_get_main_queue(), ^{
                [[NSNotificationCenter defaultCenter] postNotificationName:JPVideoPlayerDownloadStopNotification object:self];
            });
            
            NSError *error = [NSError errorWithDomain:JPVideoPlayerErrorDomain code:0 userInfo:@{NSLocalizedDescriptionKey : @"No enough size of device to cache the video data"}];
            if (self.downloadCompletion) {
                self.downloadCompletion(error);
            }
            if (self.fetchExpectedSizeCompletion) {
                self.fetchExpectedSizeCompletion(self.runningOperation.request.URL, 0, error);
            }
            if (completionHandler) {
                completionHandler(NSURLSessionResponseCancel);
            }
            [self cancel];
            
            return;
        }
        else{
            if (self.downloadProgressBlock) {
                self.downloadProgressBlock(nil, 0, expected, self.response, response.URL);
            }
            if (self.fetchExpectedSizeCompletion) {
                self.fetchExpectedSizeCompletion(self.runningOperation.request.URL, expected, nil);
                [self cancel];
                return;
            }
        }
        
        if (completionHandler) {
            completionHandler(NSURLSessionResponseAllow);
        }
        dispatch_main_async_safe(^{
            [[NSNotificationCenter defaultCenter] postNotificationName:JPVideoPlayerDownloadReceiveResponseNotification object:self];
        });
    }
    else {
        if (completionHandler) {
            completionHandler(NSURLSessionResponseCancel);
        }
        [self.runningOperation cancel];
        dispatch_main_async_safe(^{
            [[NSNotificationCenter defaultCenter] postNotificationName:JPVideoPlayerDownloadStopNotification object:self];
        });
    }
}

- (void)URLSession:(NSURLSession *)session
          dataTask:(NSURLSessionDataTask *)dataTask
    didReceiveData:(NSData *)data {
    self.receiveredSize += data.length;
    if (self.downloadProgressBlock) {
        self.downloadProgressBlock(data, self.receiveredSize, self.expectedSize, self.response, self.runningOperation.request.URL);
    }
}

//- (void)URLSession:(NSURLSession *)session
//              task:(NSURLSessionTask *)task
//didCompleteWithError:(NSError *)error{
//    if (self.runningOperation.dataTask != task) {
//        return;
//    }
//
//    dispatch_main_async_safe(^{
//        [[NSNotificationCenter defaultCenter] postNotificationName:JPVideoPlayerDownloadStopNotification object:self];
//        if (!error) {
//            [[NSNotificationCenter defaultCenter] postNotificationName:JPVideoPlayerDownloadFinishNotification object:self];
//        }
//    });
//
//    if (self.downloadCompletion) {
//        self.downloadCompletion(error);
//    }
//
//    [self cancel];
//}

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

@end
