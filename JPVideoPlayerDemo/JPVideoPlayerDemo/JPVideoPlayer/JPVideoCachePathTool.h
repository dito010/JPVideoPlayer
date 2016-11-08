//
//  JPVideoCachePathTool.h
//  JPVideoPlayerDemo
//
//  Created by lava on 2016/11/8.
//  Hello! I am NewPan from Guangzhou of China, Glad you could use my framework, If you have any question or wanna to contact me, please open https://github.com/Chris-Pan or http://www.jianshu.com/users/e2f2d779c022/latest_articles

#import <Foundation/Foundation.h>

/**
 * This Tool manager file save path.
 * 这个类负责提供文件的存储路径
 */

/**
 * Save path.
 * 存储路径
 */
static NSString *jp_tempPath = @"/JPVideoPlayer_temp"; // temporary file(临时文件)
static NSString *jp_savePath = @"/JPVideoPlayer_save"; // complete file(完成文件)
@interface JPVideoCachePathTool : NSObject

/**
 * Temporary save path.
 * 临时文件存储路径
 */
+(NSString *)fileCachePath;

/**
 * Complete file save path
 * 完整文件存储路径
 */
+(NSString *)fileSavePath;

@end
