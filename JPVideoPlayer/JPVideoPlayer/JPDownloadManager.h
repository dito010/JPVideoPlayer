//
//  JPDownloadManager.h
//  JPVideoPlayer
//
//  Created by lava on 16/8/18.
//  Copyright © 2016年 lavaMusic. All rights reserved.
//


/// 这个task的功能是从网络请求数据，并把数据保存到本地的一个临时文件，网络请求结束的时候，如果数据完整，则把数据缓存到指定的路径，不完整就删除

#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>

@class JPDownloadManager;

@protocol JPDownloadManagerDelegate <NSObject>

@optional

/** 开始下载数据(包括长度和类型) */
- (void)manager:(JPDownloadManager *)manager didReceiveVideoLength:(NSUInteger)ideoLength mimeType:(NSString *)mimeType;

/** 完成下载 */
- (void)didFinishLoadingWithManager:(JPDownloadManager *)manager fileSavePath:(NSString *)filePath;

/** 下载失败(错误码) */
- (void)didFailLoadingWithManager:(JPDownloadManager *)manager WithError:(NSError *)errorCode;

/** 已经存在下载好的这个文件了 */
-(void)manager:(JPDownloadManager *)manager fileExistedWithPath:(NSString *)filePath;

/** 正在下载 */
-(void)manager:(JPDownloadManager *)manager didReceiveData:(NSData *)data downloadOffset:(NSInteger)offset tempFilePath:(NSString *)filePath;

@end


@interface JPDownloadManager : NSObject

@property (nonatomic, strong, readonly) NSURL *url;

@property (nonatomic, readonly) NSUInteger offset;

@property (nonatomic, readonly) NSUInteger videoLength;

@property (nonatomic, readonly) NSUInteger downLoadingOffset;

@property (nonatomic, strong, readonly) NSString *mimeType;

@property (nonatomic, assign)BOOL  isFinishLoad;

@property(nonatomic, weak)id<JPDownloadManagerDelegate> delegate;


- (void)setUrl:(NSURL *)url offset:(NSUInteger)offset;

- (void)cancel;

- (void)continueLoading;

- (void)clearData;

@end
