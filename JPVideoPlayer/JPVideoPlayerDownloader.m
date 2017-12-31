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
static NSString *const kJPVideoPlayerDownloaderErrorDomain = @"com.jpvideoplayer.error.domain";
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

@property (copy, nonatomic)JPVideoPlayerDownloaderProgressBlock progressBlock;

/*
 * completion.
 */
@property(nonatomic, copy) JPVideoPlayerDownloaderCompletion completion;

@property (nonatomic) pthread_mutex_t lock;

/*
 * the running operation.
 */
@property(nonatomic, strong, nullable) JPVideoPlayerDownloaderOperation *runningOperation;

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
        _HTTPHeaders = [@{@"Accept": @"video/mpeg"} mutableCopy];
        _progressBlock = nil;
        _completion = nil;
        _expectedSize = 0;
        _receiveredSize = 0;
        
        if (!sessionConfiguration) {
            sessionConfiguration = [NSURLSessionConfiguration defaultSessionConfiguration];
        }
        sessionConfiguration.timeoutIntervalForRequest = 15.f;
        
        /**
         *  Create the session for this task
         *  We send nil as delegate queue so that the session creates a serial operation queue for performing all delegate
         *  method calls and completion handler calls.
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
    
    pthread_mutex_lock(&_lock);
    
    self.progressBlock = progressBlock;
    self.completion = completion;
    
    // The URL will be used as the key to the callbacks dictionary so it cannot be nil. If it is nil immediately call the completed block with no video or data.
    if (url == nil) {
        if (completion) {
            NSError *error = [NSError errorWithDomain:kJPVideoPlayerDownloaderErrorDomain code:0 userInfo:@{NSLocalizedDescriptionKey : @"Please check the URL, because it is nil"}];
            completion(error);
        }
        return;
    }
    
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
    pthread_mutex_unlock(&_lock);
}

- (void)cancel {
    pthread_mutex_lock(&_lock);
    if (self.runningOperation) {
        [self.runningOperation cancel];
        self.runningOperation = nil;
        self.expectedSize = 0;
        self.receiveredSize = 0;
    }
    self.progressBlock = nil;
    self.completion = nil;
    pthread_mutex_unlock(&_lock);
}


#pragma mark - Private

- (void)addProgressCallback:(JPVideoPlayerDownloaderProgressBlock)progressBlock completion:(JPVideoPlayerDownloaderCompletion)completion forURL:(nullable NSURL *)url createCallback:(JPVideoPlayerDownloaderOperation *(^)(void))createCallback {
    
    
    
   
}


#pragma mark - NSURLSessionDataDelegate

- (void)URLSession:(NSURLSession *)session dataTask:(NSURLSessionDataTask *)dataTask didReceiveResponse:(NSURLResponse *)response completionHandler:(void (^)(NSURLSessionResponseDisposition))completionHandler{
    
    //'304 Not Modified' is an exceptional one.
    if (![response respondsToSelector:@selector(statusCode)] || (((NSHTTPURLResponse *)response).statusCode < 400 && ((NSHTTPURLResponse *)response).statusCode != 304)) {
        
        NSInteger expected = MAX((NSInteger)response.expectedContentLength, 0);
        self.expectedSize = expected;
        
        // May the free size of the device less than the expected size of the video data.
        if (![[JPVideoPlayerCache sharedCache] haveFreeSizeToCacheFileWithSize:expected]) {
            if (completionHandler) {
                completionHandler(NSURLSessionResponseCancel);
            }
            dispatch_async(dispatch_get_main_queue(), ^{
                [[NSNotificationCenter defaultCenter] postNotificationName:JPVideoPlayerDownloadStopNotification object:self];
            });
            
            NSError *error = [NSError errorWithDomain:kJPVideoPlayerDownloaderErrorDomain code:0 userInfo:@{NSLocalizedDescriptionKey : @"No enough size of device to cache the video data"}];
            if (self.completion) {
                self.completion(error);
            }
            [self cancel];
            
            return;
        }
        else{
            NSString *key = [[JPVideoPlayerManager sharedManager] cacheKeyForURL:self.runningOperation.request.URL];
            if (self.progressBlock) {
                self.progressBlock(nil, 0, expected, [JPVideoPlayerCachePathManager videoCacheTemporaryPathForKey:key], response.URL);
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
        [self.runningOperation cancel];
        dispatch_main_async_safe(^{
            [[NSNotificationCenter defaultCenter] postNotificationName:JPVideoPlayerDownloadStopNotification object:self];
        });
    }
}

- (void)URLSession:(NSURLSession *)session dataTask:(NSURLSessionDataTask *)dataTask didReceiveData:(NSData *)data {
    NSString *key = [[JPVideoPlayerManager sharedManager] cacheKeyForURL:self.runningOperation.request.URL];
    self.receiveredSize += data.length;

    if (self.progressBlock) {
        self.progressBlock(data, self.receiveredSize, self.expectedSize, [JPVideoPlayerCachePathManager videoCacheTemporaryPathForKey:key], self.runningOperation.request.URL);
    }
}

- (void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task didCompleteWithError:(NSError *)error{
    dispatch_main_async_safe(^{
        [[NSNotificationCenter defaultCenter] postNotificationName:JPVideoPlayerDownloadStopNotification object:self];
        if (!error) {
            [[NSNotificationCenter defaultCenter] postNotificationName:JPVideoPlayerDownloadFinishNotification object:self];
        }
    });
    
    if (self.completion) {
        self.completion(error);
    }
    
    [self cancel];
}

- (void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task didReceiveChallenge:(NSURLAuthenticationChallenge *)challenge completionHandler:(void (^)(NSURLSessionAuthChallengeDisposition disposition, NSURLCredential *credential))completionHandler {

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

    if (completionHandler) {
        completionHandler(disposition, credential);
    }
}

- (void)URLSession:(NSURLSession *)session dataTask:(NSURLSessionDataTask *)dataTask willCacheResponse:(NSCachedURLResponse *)proposedResponse completionHandler:(void (^)(NSCachedURLResponse *cachedResponse))completionHandler {

    // If this method is called, it means the response wasn't read from cache
    NSCachedURLResponse *cachedResponse = proposedResponse;

    if (self.runningOperation.request.cachePolicy == NSURLRequestReloadIgnoringLocalCacheData) {
        // Prevents caching of responses
        cachedResponse = nil;
    }
    if (completionHandler) {
        completionHandler(cachedResponse);
    }
}

@end
