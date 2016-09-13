//
//  JPVideoURLAssetResourceLoader.h
//  JPVideoPlayer
//
//  Created by lava on 16/9/13.
//  Copyright © 2016年 lavaMusic. All rights reserved.
//


/// 这个connenction的功能是把task缓存到本地的临时数据根据播放器需要的 offset和length去取数据并返回给播放器


#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>

@class JPDownloadManager;

@protocol JPVideoURLAssetResourceLoaderDelegate <NSObject>

@optional

/** 完成下载 */
- (void)didFinishLoadingWithManager:(JPDownloadManager *)manager fileSavePath:(NSString *)filePath;

/** 下载失败(错误码) */
- (void)didFailLoadingWithManager:(JPDownloadManager *)manager WithError:(NSError *)errorCode;

/** 已经存在下载好的这个文件了 */
-(void)manager:(JPDownloadManager *)manager fileExistedWithPath:(NSString *)filePath;

@end



@interface JPVideoURLAssetResourceLoader : NSURLConnection<AVAssetResourceLoaderDelegate>

@property (nonatomic, weak  ) id<JPVideoURLAssetResourceLoaderDelegate> delegate;

- (NSURL *)getSchemeVideoURL:(NSURL *)url;

@end
