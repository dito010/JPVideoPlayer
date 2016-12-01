//
//  JPVideoCachePathTool.m
//  JPVideoPlayerDemo
//
//  Created by lava on 2016/11/8.
//  Hello! I am NewPan from Guangzhou of China, Glad you could use my framework, If you have any question or wanna to contact me, please open https://github.com/Chris-Pan or http://www.jianshu.com/users/e2f2d779c022/latest_articles

#import "JPVideoCachePathTool.h"

@implementation JPVideoCachePathTool

// Combine temporary file path.
// 拼接临时文件缓存存储路径
+(NSString *)fileCachePath{
    return [self getFilePathWithAppendingString:jp_tempPath];
}

// Combine complete file path.
// 拼接完整文件存储路径
+(NSString *)fileSavePath{
    return [self getFilePathWithAppendingString:jp_savePath];
}

+(NSString *)getFilePathWithAppendingString:(NSString *)apdStr{
    
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSString *path = [NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES).lastObject stringByAppendingString:apdStr];
    
    // Make folder.
    // 创建文件夹
    if (![fileManager fileExistsAtPath:path]) {
        [fileManager createDirectoryAtPath:path withIntermediateDirectories:YES attributes:nil error:nil];
    }
    
    return path;
}

// cache file Name.
// 缓存的文件名字
+(NSString *)suggestFileNameWithURL:(NSURL*)url{
    return [url.absoluteString.lastPathComponent componentsSeparatedByString:@"?"].firstObject;
}

@end
