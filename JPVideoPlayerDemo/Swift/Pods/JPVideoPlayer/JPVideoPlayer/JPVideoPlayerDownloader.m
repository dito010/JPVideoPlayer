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

@implementation JPVideoPlayerDownloadToken

@end

@interface JPVideoPlayerDownloader()<NSURLSessionTaskDelegate, NSURLSessionDataDelegate>

@property (strong, nonatomic, nonnull) NSOperationQueue *downloadQueue;

@property (assign, nonatomic, nullable) Class operationClass;

@property (strong, nonatomic, nonnull) NSMutableDictionary<NSURL *, JPVideoPlayerDownloaderOperation *> *URLOperations;

@property (strong, nonatomic, nullable) JPHTTPHeadersMutableDictionary *HTTPHeaders;

// This queue is used to serialize the handling of the network responses of all the download operation in a single queue
@property (nonatomic, nullable) dispatch_queue_t barrierQueue;

// The session in which data tasks will run
@property (strong, nonatomic) NSURLSession *session;

@end

@implementation JPVideoPlayerDownloader

- (nonnull instancetype)init {
    return [self initWithSessionConfiguration:[NSURLSessionConfiguration defaultSessionConfiguration]];
}

- (nonnull instancetype)initWithSessionConfiguration:(nullable NSURLSessionConfiguration *)sessionConfiguration {
    if ((self = [super init])) {
        _operationClass = [JPVideoPlayerDownloaderOperation class];
        _downloadQueue = [NSOperationQueue new];
        _downloadQueue.maxConcurrentOperationCount = 3;
        _downloadQueue.name = @"com.NewPan.JPVideoPlayerDownloader";
        _URLOperations = [NSMutableDictionary new];
        _HTTPHeaders = [@{@"Accept": @"video/mpeg"} mutableCopy];
        _barrierQueue = dispatch_queue_create("com.NewPan.JPVideoPlayerDownloaderBarrierQueue", DISPATCH_QUEUE_CONCURRENT);
        _downloadTimeout = 15.0;
        
        sessionConfiguration.timeoutIntervalForRequest = _downloadTimeout;
        
        /**
         *  Create the session for this task
         *  We send nil as delegate queue so that the session creates a serial operation queue for performing all delegate
         *  method calls and completion handler calls.
         */
        // self.session = [NSURLSession sessionWithConfiguration:sessionConfiguration delegate:self delegateQueue:nil];
    }
    return self;
}

- (void)dealloc {
    [self.session invalidateAndCancel];
    self.session = nil;
    
    [self.downloadQueue cancelAllOperations];
}


#pragma mark - Public

- (void)setValue:(nullable NSString *)value forHTTPHeaderField:(nullable NSString *)field {
    if (value) {
        self.HTTPHeaders[field] = value;
    }
    else {
        [self.HTTPHeaders removeObjectForKey:field];
    }
}

- (nullable NSString *)valueForHTTPHeaderField:(nullable NSString *)field {
    return self.HTTPHeaders[field];
}

+ (nonnull instancetype)sharedDownloader {
    static dispatch_once_t once;
    static id instance;
    dispatch_once(&once, ^{
        instance = [self new];
    });
    return instance;
}

- (nullable JPVideoPlayerDownloadToken *)downloadVideoWithURL:(NSURL *)url options:(JPVideoPlayerDownloaderOptions)options progress:(JPVideoPlayerDownloaderProgressBlock)progressBlock completed:(JPVideoPlayerDownloaderErrorBlock)errorBlock{
    
    __weak typeof(self) weakSelf = self;
    
    return [self addProgressCallback:progressBlock completedBlock:errorBlock forURL:url createCallback:^JPVideoPlayerDownloaderOperation *{
        
        __strong __typeof (weakSelf) sself = weakSelf ;
        NSTimeInterval timeoutInterval = sself.downloadTimeout;
        if (timeoutInterval == 0.0) {
            timeoutInterval = 15.0;
        }
        
        // In order to prevent from potential duplicate caching (NSURLCache + JPVideoPlayerCache) we disable the cache for image requests if told otherwise.
        NSURLComponents *actualURLComponents = [[NSURLComponents alloc] initWithURL:url resolvingAgainstBaseURL:NO];
        actualURLComponents.scheme = url.scheme;
        NSMutableURLRequest *request = [[NSMutableURLRequest alloc] initWithURL:[actualURLComponents URL] cachePolicy:(NSURLRequestReloadIgnoringLocalCacheData) timeoutInterval:timeoutInterval];
        
        request.HTTPShouldHandleCookies = (options & JPVideoPlayerDownloaderHandleCookies);
        request.HTTPShouldUsePipelining = YES;
        if (sself.headersFilter) {
            request.allHTTPHeaderFields = sself.headersFilter(url, [sself.HTTPHeaders copy]);
        }
        
        JPVideoPlayerDownloaderOperation *operation = [[sself.operationClass alloc] initWithRequest:request inSession:sself.session options:options];
        
        if (sself.urlCredential) {
            operation.credential = sself.urlCredential;
        }
        else if (sself.username && sself.password) {
            operation.credential = [NSURLCredential credentialWithUser:sself.username password:sself.password persistence:NSURLCredentialPersistenceForSession];
        }
        
        [sself.downloadQueue addOperation:operation];
        
        return operation;
    }];
}

- (void)cancel:(JPVideoPlayerDownloadToken *)token{
    dispatch_barrier_async(self.barrierQueue, ^{
        JPVideoPlayerDownloaderOperation *operation = self.URLOperations[token.url];
        BOOL canceled = [operation cancel:token.downloadOperationCancelToken];
        if (canceled) {
            [self.URLOperations removeObjectForKey:token.url];
        }
    });
}

- (void)cancelAllDownloads {
    [self.downloadQueue cancelAllOperations];
}


#pragma mark - Private

- (nullable JPVideoPlayerDownloadToken *)addProgressCallback:(JPVideoPlayerDownloaderProgressBlock)progressBlock completedBlock:(JPVideoPlayerDownloaderErrorBlock)errorBlock forURL:(nullable NSURL *)url createCallback:(JPVideoPlayerDownloaderOperation *(^)())createCallback {
    
    // The URL will be used as the key to the callbacks dictionary so it cannot be nil. If it is nil immediately call the completed block with no video or data.
    if (url == nil) {
        if (errorBlock) {
            errorBlock([NSError errorWithDomain:@"Please check the URL, because it is nil" code:0 userInfo:nil]);
        }
        return nil;
    }
    
    __block JPVideoPlayerDownloadToken *token = nil;
    
    dispatch_barrier_sync(self.barrierQueue, ^{
        JPVideoPlayerDownloaderOperation *operation = self.URLOperations[url];
        if (!operation) {
            operation = createCallback();
            self.URLOperations[url] = operation;
            
            __weak JPVideoPlayerDownloaderOperation *woperation = operation;
            operation.completionBlock = ^{
                JPVideoPlayerDownloaderOperation *soperation = woperation;
                if (!soperation) return;
                if (self.URLOperations.allKeys.count>0) {
                    if (self.URLOperations[url] == soperation) {
                        [self.URLOperations removeObjectForKey:url];
                    };
                }
            };
        }
        id downloadOperationCancelToken = [operation addHandlersForProgress:progressBlock error:errorBlock];
        
        token = [JPVideoPlayerDownloadToken new];
        token.url = url;
        token.downloadOperationCancelToken = downloadOperationCancelToken;
    });
    
    return token;
}

@end
