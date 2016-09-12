//
//  JPLoaderURLConnection.h
//  JPVideoPlayer
//
//  Created by Chris on 16/8/21.
//  Copyright © 2016年 lavaMusic. All rights reserved.
//

/// 这个connenction的功能是把task缓存到本地的临时数据根据播放器需要的 offset和length去取数据并返回给播放器
/// 如果视频文件比较小，就没有必要存到本地，直接用一个变量存储即可


#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>

@class JPDownloadManager;

@protocol JPLoaderURLConnectionDelegate <NSObject>

@optional

/** 完成下载 */
- (void)didFinishLoadingWithManager:(JPDownloadManager *)manager fileSavePath:(NSString *)filePath;

/** 下载失败(错误码) */
- (void)didFailLoadingWithManager:(JPDownloadManager *)manager WithError:(NSError *)errorCode;

/** 已经存在下载好的这个文件了 */
-(void)manager:(JPDownloadManager *)manager fileExistedWithPath:(NSString *)filePath;

@end


@interface JPLoaderURLConnection : NSURLConnection<AVAssetResourceLoaderDelegate>

@property (nonatomic, strong)JPDownloadManager *manager;

@property (nonatomic, weak  ) id<JPLoaderURLConnectionDelegate> delegate;

- (NSURL *)getSchemeVideoURL:(NSURL *)url;

@end
