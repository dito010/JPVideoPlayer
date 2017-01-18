//
//  JPVideoURLAssetResourceLoader.m
//  JPVideoPlayer
//
//  Created by lava on 16/9/13.
//  Hello! I am NewPan from Guangzhou of China, Glad you could use my framework, If you have any question or wanna to contact me, please open https://github.com/Chris-Pan or http://www.jianshu.com/users/e2f2d779c022/latest_articles


#import "JPVideoURLAssetResourceLoader.h"
#import <MobileCoreServices/MobileCoreServices.h>
#import "JPDownloadManager.h"
#import "JPVideoCachePathTool.h"

@interface JPVideoURLAssetResourceLoader()<JPDownloadManagerDelegate>

/** 
 The download tool for video file.
 *下载器 
 */
@property (nonatomic, strong)JPDownloadManager *manager;

/**
 * The request queue.
 * It save the request wait for being given video data.
 * 请求队列 
 */
@property (nonatomic, strong)NSMutableArray *pendingRequests;

/**
 * The video path to play.
 * 视频路径
 */
@property (nonatomic, strong)NSString *videoPath;

/** 
 * File name.
 * 文件名 
 */
@property(nonatomic, strong)NSString *suggestFileName;

/**
 * The scheme of the video' url.
 * 视频路径的 scheme
 */
@property(nonatomic, strong)NSString *scheme;

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
    // AVAssetResourceLoader通过你提供的委托对象去调节AVURLAsset所需要的加载资源。
    // 而很重要的一点是，AVAssetResourceLoader仅在AVURLAsset不知道如何去加载这个URL资源时才会被调用
    // 就是说你提供的委托对象在AVURLAsset不知道如何加载资源时才会得到调用。
    // 所以我们又要通过一些方法来曲线解决这个问题，把我们目标视频URL地址的scheme替换为系统不能识别的scheme
    
    NSURLComponents *components = [[NSURLComponents alloc] initWithURL:url resolvingAgainstBaseURL:NO];
    self.scheme = components.scheme;
    components.scheme = @"systemCannotRecognition";
    
    NSString *path = [NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES).lastObject stringByAppendingString:jp_tempPath];
    NSString *suggestFileName = [JPVideoCachePathTool suggestFileNameWithURL:url];
    path = [path stringByAppendingPathComponent:suggestFileName];
    _videoPath = path;
    
    return [components URL];
}

-(void)invalidDownload{
    [self.manager invalidateAndCancel];
    self.manager = nil;
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
    
    if (resourceLoader && loadingRequest) {
        [self.pendingRequests addObject:loadingRequest];
        [self dealLoadingRequest:loadingRequest];
    }
   
    return YES;
}

-(void)resourceLoader:(AVAssetResourceLoader *)resourceLoader didCancelLoadingRequest:(AVAssetResourceLoadingRequest *)loadingRequest{
    [self.pendingRequests removeObject:loadingRequest];
}


#pragma mark -----------------------------------------
#pragma mark Private

- (void)dealLoadingRequest:(AVAssetResourceLoadingRequest *)loadingRequest{
  
    NSURL *interceptedURL = [loadingRequest.request URL];
    
    if (self.manager) {
        if (self.manager.downLoadingOffset > 0)
            [self processPendingRequests];
    }
    else{
        self.manager = [JPDownloadManager new];
        self.manager.delegate = self;
        self.manager.scheme = self.scheme;
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
    
    /* Nick Xu Mark  
     针对这个计算
     long long endOffset = startOffset + dataRequest.requestedLength;
     
     经过测试发现这一句是有bug的 ，每次调用这个方法的时候 ，由于存在
     if (dataRequest.currentOffset != 0) {
     startOffset = dataRequest.currentOffset;
     }
     这个逻辑，对与同一个dataRequest
     dataRequest.currentOffset是实时在增长的，
     dataRequest.requestedLength这个是不变的，
     导致下边计算endOffset会出现问题。我理解的endOffset对于一个dataReqeust来说，应该是不变的
     
     所以，应该用
     long long endOffset = dataRequest.requestedOffset + dataRequest.requestedLength;
     替代
     
     经过测试:使用你原来的计算方法，在下载完一个视频后，pendingRequests里没有remove掉所有的request(我这边通过一个140M左右的视频测试)
     替换了我的计算方法，在下载完一个视频后，pendingRequests的所有reqeust成功remove
     
     这里我不直接修改代码，仅供你参考。
     
     最近也看了很多边下边播的帖子，基本都是错误的计算方法。
     */

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
