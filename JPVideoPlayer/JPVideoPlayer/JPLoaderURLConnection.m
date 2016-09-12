//
//  JPLoaderURLConnection.m
//  JPVideoPlayer
//
//  Created by Chris on 16/8/21.
//  Copyright © 2016年 lavaMusic. All rights reserved.
//

#import "JPLoaderURLConnection.h"
#import <MobileCoreServices/MobileCoreServices.h>
#import "JPDownloadManager.h"


@interface JPLoaderURLConnection()<JPDownloadManagerDelegate>

@property (nonatomic, strong) NSMutableArray *pendingRequests;

@property (nonatomic, copy  ) NSString *videoPath;

/** 文件名 */
@property(nonatomic, strong)NSString *suggestFileName;

@end


@implementation JPLoaderURLConnection

- (instancetype)init{
    self = [super init];
    if (self) {
        _pendingRequests = [NSMutableArray array];
    }
    return self;
}


#pragma mark -----------------------------------------
#pragma mark AVAssetResourceLoaderDelegate

/**
 *  必须返回Yes，如果返回NO，则resourceLoader将会加载出现故障的数据
 *  这里会出现很多个loadingRequest请求， 需要为每一次请求作出处理
 *  @param resourceLoader 资源管理器
 *  @param loadingRequest 每一小块数据的请求
 *
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
#pragma mark Publish

- (NSURL *)getSchemeVideoURL:(NSURL *)url{
    NSURLComponents *components = [[NSURLComponents alloc] initWithURL:url resolvingAgainstBaseURL:NO];
    components.scheme = @"streaming";
    NSString *path = [NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES).lastObject stringByAppendingString:@"/LAVideo_cache"];
    NSString *suggestFileName = [[url absoluteString]lastPathComponent];
    path = [path stringByAppendingPathComponent:suggestFileName];
    _videoPath = path;
    return [components URL];
}


#pragma mark -----------------------------------------
#pragma mark Private

- (void)dealLoadingRequest:(AVAssetResourceLoadingRequest *)loadingRequest{
    NSURL *interceptedURL = [loadingRequest.request URL];
    NSRange range = NSMakeRange(loadingRequest.dataRequest.currentOffset, MAXFLOAT);
    
    if (self.manager) {
        if (self.manager.downLoadingOffset > 0)
            [self processPendingRequests];
        
        // 如果新的rang的起始位置比当前缓存的位置还大300k，则重新按照range请求数据
        if (self.manager.offset + self.manager.downLoadingOffset + 1024*300 < range.location
            // 如果往回拖也重新请求
            || self.manager.offset > range.location) {
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
    NSMutableArray *requestsCompleted = [NSMutableArray array];  //请求完成的数组
    //每次下载一块数据都是一次请求，把这些请求放到数组，遍历数组
    for (AVAssetResourceLoadingRequest *loadingRequest in self.pendingRequests) {
        
        //对每次请求加上长度，文件类型等信息
        [self fillInContentInformation:loadingRequest.contentInformationRequest];
        //判断此次请求的数据是否处理完全, 和填充数据
        BOOL didRespondCompletely = [self respondWithDataForRequest:loadingRequest.dataRequest];
        
        //如果完整，把此次请求放进 请求完成的数组
        if (didRespondCompletely) {
            [requestsCompleted addObject:loadingRequest];
            [loadingRequest finishLoading];
        }
    }
    //在所有请求的数组中移除已经完成的
    [self.pendingRequests removeObjectsInArray:[requestsCompleted copy]];
}

//判断此次请求的数据是否处理完全, 和填充数据
- (BOOL)respondWithDataForRequest:(AVAssetResourceLoadingDataRequest *)dataRequest{
    // 请求起始点
    long long startOffset = dataRequest.requestedOffset;
    
    // 当前请求点
    if (dataRequest.currentOffset != 0)
        startOffset = dataRequest.currentOffset;
    
    // 播放器拖拽后大于已经缓存的数据
    if (startOffset > (self.manager.offset + self.manager.downLoadingOffset))
        return NO;
    
    // 播放器拖拽后小于已经缓存的数据
    if (startOffset < self.manager.offset)
        return NO;
    
    NSData *fileData = [NSData dataWithContentsOfFile:_videoPath options:NSDataReadingMappedIfSafe error:nil];
    
    NSInteger unreadBytes = self.manager.downLoadingOffset - self.manager.offset - (NSInteger)startOffset;
    NSUInteger numberOfBytesToRespondWith = MIN((NSUInteger)dataRequest.requestedLength, unreadBytes);
    
    [dataRequest respondWithData:[fileData subdataWithRange:NSMakeRange((NSUInteger)startOffset- self.manager.offset, (NSUInteger)numberOfBytesToRespondWith)]];
    
    long long endOffset = startOffset + dataRequest.requestedOffset;
    
    BOOL didRespondFully = (self.manager.offset + self.manager.downLoadingOffset) >= endOffset;
    
    return didRespondFully;
}

//对每次请求加上长度，文件类型等信息
-(void)fillInContentInformation:(AVAssetResourceLoadingContentInformationRequest *)contentInformationRequest{
    NSString *mimetype = self.manager.mimeType;
    CFStringRef contentType = UTTypeCreatePreferredIdentifierForTag(kUTTagClassMIMEType, (__bridge CFStringRef _Nonnull)(mimetype), NULL);
    
    contentInformationRequest.byteRangeAccessSupported = YES;
    contentInformationRequest.contentType = CFBridgingRelease(contentType);
    contentInformationRequest.contentLength = self.manager.videoLength;
}


#pragma mark -----------------------------------------
#pragma mark JPDownloadManagerDelegate
-(void)manager:(JPDownloadManager *)manager fileExistedWithPath:(NSString *)filePath{
    if ([self.delegate respondsToSelector:@selector(manager:fileExistedWithPath:)]) {
        // 移除所有请求
        [self.pendingRequests enumerateObjectsUsingBlock:^(AVAssetResourceLoadingRequest * obj, NSUInteger idx, BOOL * _Nonnull stop) {
            [obj finishLoading];
            [self.pendingRequests removeObject:obj];
        }];
        [self.delegate manager:manager fileExistedWithPath:filePath];
    }
}

-(void)manager:(JPDownloadManager *)manager didReceiveVideoLength:(NSUInteger)ideoLength mimeType:(NSString *)mimeType{
    
}

-(void)manager:(JPDownloadManager *)manager didReceiveData:(NSData *)data downloadOffset:(NSInteger)offset tempFilePath:(NSString *)filePath{
    [self processPendingRequests];
}

-(void)didFinishLoadingWithManager:(JPDownloadManager *)manager fileSavePath:(NSString *)filePath{
    // 此时文件下载完成, 已经将临时文件存储到filePath中了
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


