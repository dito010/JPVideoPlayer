//
//  JPVideoURLAssetResourceLoader.m
//  JPVideoPlayer
//
//  Created by lava on 16/9/13.
//  Hello! I am NewPan from Guangzhou of China, Glad you could use my framework, If you have any question or wanna to contact me, please open https://github.com/Chris-Pan or http://www.jianshu.com/users/e2f2d779c022/latest_articles


#import "JPVideoURLAssetResourceLoader.h"
#import <MobileCoreServices/MobileCoreServices.h>
#import "JPDownloadManager.h"

@interface JPVideoURLAssetResourceLoader()<JPDownloadManagerDelegate>

/** 下载器 */
@property (nonatomic, strong)JPDownloadManager *manager;

/** 请求队列 */
@property (nonatomic, strong)NSMutableArray *pendingRequests;

@property (nonatomic, strong)NSString *videoPath;

/** 文件名 */
@property(nonatomic, strong)NSString *suggestFileName;

@end


@implementation JPVideoURLAssetResourceLoader

- (instancetype)init{
    self = [super init];
    if (self) {
        _pendingRequests = [NSMutableArray array];
    }
    return self;
}


#pragma mark -----------------------------------------
#pragma mark Public

- (NSURL *)getSchemeVideoURL:(NSURL *)url{
    
    // NSURLComponents用来替代NSMutableURL，可以readwrite修改URL
    // 这里通过更改请求策略，将容量巨大的连续媒体数据进行分段，分割为数量众多的小文件进行传递.
    // 采用了一个不断更新的轻量级索引文件来控制分割后小媒体文件的下载和播放，可同时支持直播和点播.
    
    NSURLComponents *components = [[NSURLComponents alloc] initWithURL:url resolvingAgainstBaseURL:NO];
    components.scheme = @"streaming";
    
    NSString *path = [NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES).lastObject stringByAppendingString:jp_tempPath];
    NSString *suggestFileName = [[url absoluteString]lastPathComponent];
    path = [path stringByAppendingPathComponent:suggestFileName];
    _videoPath = path;
    
    return [components URL];
}


#pragma mark -----------------------------------------
#pragma mark AVAssetResourceLoaderDelegate

/**
 *  必须返回Yes，如果返回NO，则resourceLoader将会加载出现故障的数据
 *  这里会出现很多个loadingRequest请求， 需要为每一次请求作出处理
 *  @param resourceLoader 资源管理器
 *  @param loadingRequest 每一小块数据的请求
 */
-(BOOL)resourceLoader:(AVAssetResourceLoader *)resourceLoader shouldWaitForLoadingOfRequestedResource:(AVAssetResourceLoadingRequest *)loadingRequest{
    
    [self.pendingRequests addObject:loadingRequest];
    [self dealLoadingRequest:loadingRequest];
    
    return YES;
}

-(void)resourceLoader:(AVAssetResourceLoader *)resourceLoader didCancelLoadingRequest:(AVAssetResourceLoadingRequest *)loadingRequest{
    [self.pendingRequests removeObject:loadingRequest];
}


#pragma mark -----------------------------------------
#pragma mark Private

- (void)dealLoadingRequest:(AVAssetResourceLoadingRequest *)loadingRequest{
  
    NSURL *interceptedURL = [loadingRequest.request URL];
    NSRange range = NSMakeRange((NSUInteger)loadingRequest.dataRequest.currentOffset, MAXFLOAT);
    
    if (self.manager) {
        if (self.manager.downLoadingOffset > 0)
            [self processPendingRequests];
        
        // If the new location is greater than the total length of cached file
        // Then request new region data
        // 如果新的rang的起始位置比当前缓存的位置还大，则重新按照range请求数据
        if (self.manager.offset + self.manager.downLoadingOffset + 1024*300 < range.location) {
            [self.manager setUrl:interceptedURL offset:range.location];
        }
    }
    else{
        self.manager = [JPDownloadManager new];
        self.manager.delegate = self;
        [self.manager setUrl:interceptedURL offset:0];
    }
}

- (void)processPendingRequests{
    
    // Enumerate all loadingRequest
    // For every singal loadingRequest, combine response-data length and file mimeType
    // Then judge the download file data is contain the loadingRequest's data or not, if Yes, take out the request's data and return to loadingRequest, next to colse this loadingRequest. if No, continue wait for download finished.
    // 遍历所有的请求, 为每个请求加上请求的数据长度和文件类型等信息.
    // 在判断当前下载完的数据长度中有没有要请求的数据, 如果有,就把这段数据取出来,并且把这段数据填充给请求, 然后关闭这个请求
    // 如果没有, 继续等待下载完成.
    
    NSMutableArray *requestsCompleted = [NSMutableArray array];
    for (AVAssetResourceLoadingRequest *loadingRequest in self.pendingRequests) {
        
        [self fillInContentInformation:loadingRequest.contentInformationRequest];
        BOOL didRespondCompletely = [self respondWithDataForRequest:loadingRequest.dataRequest];
        
        if (didRespondCompletely) {
            [requestsCompleted addObject:loadingRequest];
            [loadingRequest finishLoading];
        }
    }
    [self.pendingRequests removeObjectsInArray:[requestsCompleted copy]];
}

- (BOOL)respondWithDataForRequest:(AVAssetResourceLoadingDataRequest *)dataRequest{
    
    long long startOffset = dataRequest.requestedOffset;
    if (dataRequest.currentOffset != 0)
        startOffset = dataRequest.currentOffset;
    
    NSData *fileData = [NSData dataWithContentsOfFile:_videoPath options:NSDataReadingMappedIfSafe error:nil];
    NSInteger unreadBytes = self.manager.downLoadingOffset - self.manager.offset - (NSInteger)startOffset;
    NSUInteger numberOfBytesToRespondWith = MIN((NSUInteger)dataRequest.requestedLength, unreadBytes);
    [dataRequest respondWithData:[fileData subdataWithRange:NSMakeRange((NSUInteger)startOffset- self.manager.offset, (NSUInteger)numberOfBytesToRespondWith)]];
    
    // Thank for @DrunkenMouse(http://www.jianshu.com/users/5d853d21f7da/latest_articles) submmit a bug that my mistake of calculate "endOffset".
    long long endOffset = startOffset + dataRequest.requestedLength;
    BOOL didRespondFully = (self.manager.offset + self.manager.downLoadingOffset) >= endOffset;
    
    return didRespondFully;
}

-(void)fillInContentInformation:(AVAssetResourceLoadingContentInformationRequest *)contentInformationRequest{
    NSString *mimetype = self.manager.mimeType;
    CFStringRef contentType = UTTypeCreatePreferredIdentifierForTag(kUTTagClassMIMEType, (__bridge CFStringRef _Nonnull)(mimetype), NULL);
    contentInformationRequest.byteRangeAccessSupported = YES;
    contentInformationRequest.contentType = CFBridgingRelease(contentType);
    contentInformationRequest.contentLength = self.manager.fileLength;
}


#pragma mark -----------------------------------------
#pragma mark JPDownloadManagerDelegate

-(void)manager:(JPDownloadManager *)manager fileExistedWithPath:(NSString *)filePath{
    
    // File existed, so close and remove all request
    // 移除所有请求
    
    [self.pendingRequests enumerateObjectsUsingBlock:^(AVAssetResourceLoadingRequest * obj, NSUInteger idx, BOOL * _Nonnull stop) {
        [obj finishLoading];
        [self.pendingRequests removeObject:obj];
    }];
    
    if ([self.delegate respondsToSelector:@selector(manager:fileExistedWithPath:)]) {
        [self.delegate manager:manager fileExistedWithPath:filePath];
    }
}

-(void)manager:(JPDownloadManager *)manager didReceiveData:(NSData *)data downloadOffset:(NSInteger)offset tempFilePath:(NSString *)filePath{
    [self processPendingRequests];
}

-(void)didFinishLoadingWithManager:(JPDownloadManager *)manager fileSavePath:(NSString *)filePath{
    
    // File download success, and the downloaded file be auto move to cache path, so must change the _videoPath from temporary path to cache path
    // 此时文件下载完成, 已经将临时文件存储到filePath中了, 所以需要调转获取视频数据的路径到存储完整视频的路径
    
    _videoPath = filePath;
    if ([self.delegate respondsToSelector:@selector(didFinishLoadingWithManager:fileSavePath:)]) {
        [self.delegate didFinishLoadingWithManager:manager fileSavePath:filePath];
    }
}

-(void)didFailLoadingWithManager:(JPDownloadManager *)manager WithError:(NSError *)errorCode{
    if ([self.delegate respondsToSelector:@selector(didFailLoadingWithManager:WithError:)]) {
        [self.delegate didFailLoadingWithManager:manager WithError:errorCode];
    }
}

@end
