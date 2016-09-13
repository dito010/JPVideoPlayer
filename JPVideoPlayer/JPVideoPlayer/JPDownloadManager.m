//
//  JPDownloadManager.m
//  JPVideoPlayer
//
//  Created by lava on 16/8/18.
//  Copyright © 2016年 lavaMusic. All rights reserved.
//

#import "JPDownloadManager.h"

@interface JPDownloadManager()<NSURLSessionDataDelegate>

@property (nonatomic, strong) NSURL *url;

@property (nonatomic) NSUInteger offset;

@property (nonatomic) NSUInteger videoLength;

@property (nonatomic, strong) NSString *mimeType;

@property (nonatomic, strong) NSURLSession *session;

@property (nonatomic, assign) NSUInteger downLoadingOffset;

@property (nonatomic, assign) BOOL once;

@property (nonatomic, strong) NSOutputStream *outputStream;

@property (nonatomic, strong) NSString *tempPath;

/** 文件名 */
@property(nonatomic, strong)NSString *suggestFileName;

@end


@implementation JPDownloadManager

#pragma mark --------------------------------------------------
#pragma mark Public

-(void)cancel{
    [self.session invalidateAndCancel];
}

- (void)clearData
{
    [self.session invalidateAndCancel];
    [self.outputStream close];
    self.outputStream = nil;
    //移除文件
    [[NSFileManager defaultManager] removeItemAtPath:_tempPath error:nil];
}

- (void)setUrl:(NSURL *)url offset:(NSUInteger)offset{
    _url = url;
    _offset = offset;
    
    _downLoadingOffset = 0;
    
    // 检查有没有缓存
    NSString *urlString = [url absoluteString];
    self.suggestFileName = [urlString lastPathComponent];
    
    NSFileManager *manager = [NSFileManager defaultManager];
    NSString *savePath = [self fileSavePath];
    savePath = [savePath stringByAppendingPathComponent:self.suggestFileName];
    if ([manager fileExistsAtPath:savePath]) { // 已经存在这个下载好的文件了
        if ([self.delegate respondsToSelector:@selector(manager:fileExistedWithPath:)]) {
            [self.delegate manager:self fileExistedWithPath:savePath];
        }
        return;
    }

    
    // 类似NSURL, 可以动态修改scheme
    NSURLComponents *actualURLComponents = [[NSURLComponents alloc] initWithURL:url resolvingAgainstBaseURL:NO];
    actualURLComponents.scheme = @"http";

    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:[actualURLComponents URL] cachePolicy:NSURLRequestReloadIgnoringCacheData timeoutInterval:20.0];
    
    if (offset > 0 && self.videoLength > 0) {
        [request addValue:[NSString stringWithFormat:@"bytes=%ld-%ld",(unsigned long)offset, (unsigned long)self.videoLength - 1] forHTTPHeaderField:@"Range"];
    }
    
    [self.session invalidateAndCancel];
    
    self.session = [NSURLSession sessionWithConfiguration:[NSURLSessionConfiguration defaultSessionConfiguration] delegate:self delegateQueue:[NSOperationQueue mainQueue]];
    
    NSURLSessionDataTask *dataTask = [self.session dataTaskWithRequest:request];
    
    [dataTask resume];
}


#pragma mark --------------------------------------------------
#pragma mark NSURLSessionDataDelegate

// 1.接收到服务器响应的时候
-(void)URLSession:(NSURLSession *)session dataTask:(NSURLSessionDataTask *)dataTask didReceiveResponse:(NSURLResponse *)response completionHandler:(void (^)(NSURLSessionResponseDisposition))completionHandler{
    
    NSLog(@"开始下载");
    
    _isFinishLoad = NO;
    
    // 没有下载过完整的文件
    self.tempPath = [self fileCachePath];
    
    NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse*)response;
    NSDictionary *dic = (NSDictionary *)[httpResponse allHeaderFields] ;
    NSString *content = [dic valueForKey:@"Content-Range"];
    NSArray *array = [content componentsSeparatedByString:@"/"];
    NSString *length = array.lastObject;
    
    NSUInteger videoLength;
    if ([length integerValue] == 0) {
        videoLength = (NSUInteger)httpResponse.expectedContentLength;
    } else {
        videoLength = [length integerValue];
    }
    
    self.videoLength = videoLength;
    self.mimeType = @"video/mp4";
    
    if ([self.delegate respondsToSelector:@selector(manager:didReceiveVideoLength:mimeType:)]) {
        [self.delegate manager:self didReceiveVideoLength:self.videoLength mimeType:self.mimeType];
    }
    
    self.outputStream = [[NSOutputStream alloc]initToFileAtPath:_tempPath append:YES];
    [self.outputStream open];
    
//    NSLog(@"%@", self.tempPath);
    
    //通过该回调告诉系统是否要继续接收服务器返回给我们的数据NSURLSessionResponseAllow==接收
    completionHandler(NSURLSessionResponseAllow);
}

// 2.接收到服务器返回数据的时候调用,会调用多次
-(void)URLSession:(NSURLSession *)session dataTask:(NSURLSessionDataTask *)dataTask didReceiveData:(NSData *)data{
    
    _downLoadingOffset += data.length;
    [self.outputStream write:data.bytes maxLength:data.length];
    
//    NSLog(@"%lf", 1.0 * _downLoadingOffset / self.videoLength);
    
    if ([self.delegate respondsToSelector:@selector(manager:didReceiveData:downloadOffset:tempFilePath:)]) {
        [self.delegate manager:self didReceiveData:data downloadOffset:_downLoadingOffset tempFilePath:_tempPath];
    }
    
}

//3.请求结束的时候调用(成功|失败),如果失败那么error有值
-(void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task didCompleteWithError:(NSError *)error{
    if (!error) { // 下载成功
        [self downloadSuccessWithURLSession:session task:task];
    }
    else{ // 下载失败
        [self downloadFailedWithURLSession:session task:task error:error];
    }
}

-(void)downloadSuccessWithURLSession:(NSURLSession *)session task:(NSURLSessionTask *)task{
    
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSString *savePath = [self fileSavePath];
    savePath = [savePath stringByAppendingPathComponent:self.suggestFileName];
    
    if ([fileManager fileExistsAtPath:self.tempPath]) {
        [fileManager moveItemAtPath:self.tempPath toPath:savePath error:nil];
        if ([self.delegate respondsToSelector:@selector(didFinishLoadingWithManager:fileSavePath:)]) {
            [self.delegate didFinishLoadingWithManager:self fileSavePath:savePath];
        }
        [self.outputStream close];
        self.outputStream = nil;
    }
}

//网络中断：-1005
//无网络连接：-1009
//请求超时：-1001
//服务器内部错误：-1004
//找不到服务器：-1003
-(void)downloadFailedWithURLSession:(NSURLSession *)session task:(NSURLSessionTask *)task error:(NSError *)error{
    if (error.code == -1001 && !_once) { // 网络超时，重连一次
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            [self continueLoading];
        });
    }
    
    if ([self.delegate respondsToSelector:@selector(didFailLoadingWithManager:WithError:)]) {
        [self.delegate didFailLoadingWithManager:self WithError:error];
    }
    if (error.code == -1009) {
        NSLog(@"无网络连接");
    }
}

-(void)continueLoading{
    _once = YES;
    NSURLComponents *components = [[NSURLComponents alloc]initWithURL:_url resolvingAgainstBaseURL:NO];
    components.scheme = @"http";
    
    NSMutableURLRequest *requestM = [NSMutableURLRequest requestWithURL:[components URL] cachePolicy:NSURLRequestReloadIgnoringLocalCacheData timeoutInterval:15.0];
    
    [requestM addValue:[NSString stringWithFormat:@"bytes=%ld-%ld",(unsigned long)_downLoadingOffset, (unsigned long)self.videoLength - 1] forHTTPHeaderField:@"Range"];
    
    [self.session invalidateAndCancel];
    self.session = [NSURLSession sessionWithConfiguration:[NSURLSessionConfiguration defaultSessionConfiguration] delegate:self delegateQueue:[NSOperationQueue mainQueue]];
    NSURLSessionDataTask *dataTask = [self.session dataTaskWithRequest:requestM];
    [dataTask resume];
}


#pragma mark --------------------------------------------------
#pragma mark Private

// 缓存存储路径
-(NSString *)fileCachePath{
    
    NSFileManager *fileManager = [NSFileManager defaultManager];
    
    NSString *path = [NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES).lastObject stringByAppendingString:jp_tempPath];
    
    // 创建文件夹
    if (![fileManager fileExistsAtPath:path]) {
        [fileManager createDirectoryAtPath:path withIntermediateDirectories:YES attributes:nil error:nil];
    }
    
    path = [path stringByAppendingPathComponent:self.suggestFileName];
    
    if ([fileManager fileExistsAtPath:path] && !self.once) {
        [fileManager removeItemAtPath:path error:nil];
        [fileManager createFileAtPath:path contents:nil attributes:nil];
    }
    else {
        [fileManager createFileAtPath:path contents:nil attributes:nil];
    }
    return path;
}

// 下载完成以后的存储路径
-(NSString *)fileSavePath{
    NSFileManager *fileManager = [NSFileManager defaultManager];
    
    NSString *path = [NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES).lastObject stringByAppendingString:jp_savePath];
    // 创建文件夹
    if (![fileManager fileExistsAtPath:path]) {
        [fileManager createDirectoryAtPath:path withIntermediateDirectories:YES attributes:nil error:nil];
    }
    
    return path;
}

@end
