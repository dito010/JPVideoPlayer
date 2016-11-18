//
//  JPCacheManager.h
//  JPVideoPlayerDemo
//
//  Created by 尹久盼 on 16/11/17.
//  Copyright © 2016年 NewPan. All rights reserved.
//

/**
 * This class be use for manage video cache asynchronously.
 * 这个类用于管理缓存视频文件.
 */

#import <Foundation/Foundation.h>

typedef void(^JPCacheQueryCompletedBlock)(NSUInteger);

@interface JPCacheManager : NSObject

/**
 * Clear video cache for the given url asynchronously.
 * 清除指定URL的缓存视频文件(异步).
 * @param url   the url of video file.
 */
+(void)clearVideoCacheForUrl:(NSURL *)url;

/**
 * Clear complete files and temporary files asynchronously.
 * 清除所有的缓存(异步), 包括完整视频文件和临时视频文件.
 */
+(void)clearAllVideoCache;

/**
 * Get the total size of complete files and temporary files asynchronously.
 * 获取缓存总大小(异步), 包括完整视频文件和临时视频文件.
 */
+(void)getSize:(JPCacheQueryCompletedBlock)completedOperation;

@end
