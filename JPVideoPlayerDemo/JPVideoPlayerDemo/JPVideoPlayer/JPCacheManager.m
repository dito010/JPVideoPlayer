//
//  JPCacheManager.m
//  JPVideoPlayerDemo
//
//  Created by 尹久盼 on 16/11/17.
//  Copyright © 2016年 NewPan. All rights reserved.
//

#import "JPCacheManager.h"
#import "JPVideoCachePathTool.h"
#import "JPVideoURLAssetResourceLoader.h"

@implementation JPCacheManager

+(void)clearVideoCacheForUrl:(NSURL *)url{
    
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSString *savePa = [JPVideoCachePathTool fileSavePath];
    NSString *suggestFileName = [JPVideoCachePathTool suggestFileNameWithURL:url];
    savePa = [savePa stringByAppendingPathComponent:suggestFileName];
    if ([fileManager fileExistsAtPath:savePa]) {
        dispatch_async(dispatch_get_global_queue(0, 0), ^{
            [fileManager removeItemAtPath:savePa error:nil];
        });
    }
}

+(void)clearAllVideoCache{
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSString *savePa = [JPVideoCachePathTool fileSavePath];
    NSString *tempPa = [JPVideoCachePathTool fileCachePath];
    dispatch_async(dispatch_get_global_queue(0, 0), ^{
        [fileManager removeItemAtPath:savePa error:nil];
        [fileManager removeItemAtPath:tempPa error:nil];
        // For test
        // NSLog(@"清除所有缓存成功");
    });
}

+(void)getSize:(JPCacheQueryCompletedBlock)completedOperation{
    NSString *savePa = [JPVideoCachePathTool fileSavePath];
    NSString *tempPa = [JPVideoCachePathTool fileCachePath];
    NSArray *directoryPathArr = @[
                                  savePa,
                                  tempPa
                                  ];
    [self getSizeWithDirectoryPath:directoryPathArr completion:^(NSInteger totalSize) {
        if (completedOperation) {
            completedOperation(totalSize);
        }
    }];
}

+(void)getSizeWithDirectoryPath:(NSArray *)directoryPathArr completion:(void(^)(NSInteger))completionBlock{
    
    dispatch_async(dispatch_get_global_queue(0, 0), ^{
        NSFileManager *manager = [NSFileManager defaultManager];
        NSInteger totalSize = 0;
        for (NSString *directoryPath in directoryPathArr) {
            BOOL isDir;
            BOOL isFile = [manager fileExistsAtPath:directoryPath isDirectory:&isDir];
            if (!isDir || !isFile) {
                NSException *exc = [NSException exceptionWithName:@"FilePathError" reason:@"File not exist." userInfo:nil];
                [exc raise];
            }
            
            NSArray *subPaths = [manager subpathsAtPath:directoryPath];
            for (NSString *subPath in subPaths) {
                NSString *fullPath = [directoryPath stringByAppendingPathComponent:subPath];
                if ([fullPath containsString:@".DS"]) continue;
                BOOL isDirectory;
                BOOL isFile = [manager fileExistsAtPath:fullPath isDirectory:&isDirectory];
                if (!isFile || isDirectory) continue;
                NSDictionary *attr = [manager attributesOfItemAtPath:fullPath error:nil];
                totalSize += [attr fileSize];
            }
        }
        dispatch_async(dispatch_get_main_queue(), ^{
            if (completionBlock) {
                completionBlock(totalSize);
            }
        });
    });
}

+ (unsigned long long)getDiskFreeSize{
    
    NSDictionary *systemAttributes = [[NSFileManager defaultManager] fileSystemAttributesAtPath:NSHomeDirectory()];
//    NSString *diskTotalSize = [systemAttributes objectForKey:@"NSFileSystemSize"]; 
    NSString *diskFreeSize = [systemAttributes objectForKey:NSFileSystemFreeSize];
    return [diskFreeSize longLongValue];
}

@end
