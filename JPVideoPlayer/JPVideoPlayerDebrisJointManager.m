//
//  JPVideoPlayerDebrisJointManager.m
//  JPVideoPlayerDemo
//
//  Created by 尹久盼 on 2018/1/1.
//  Copyright © 2018年 NewPan. All rights reserved.
//

#import "JPVideoPlayerDebrisJointManager.h"
#import "JPVideoPlayerCachePath.h"
#import "JPVideoPlayerCacheFile.h"

@interface JPVideoPlayerDebrisJointManager()

@property (nonatomic, strong, nonnull) dispatch_queue_t ioQueue;

@end

@implementation JPVideoPlayerDebrisJointManager

- (instancetype)init {
    self = [super init];
    if (self) {
        // Create IO serial queue
        _ioQueue = dispatch_queue_create("com.NewPan.JPVideoPlayerDebrisJointManager", DISPATCH_QUEUE_SERIAL);
    }
    return self;
}

- (void)tryToJointDataDebrisForKey:(NSString *)key
                        completion:(JPVideoPlayerDebrisJointCompletion)completion {
    NSParameterAssert(key);
    if (!key.length) {
        [self callCompletion:completion fullVideoPath:nil errorMessage:@"Joint debris data need a key"];
        return;
    }
    
    dispatch_async(self.ioQueue, ^{
        if (![self debrisVideoDataIsCacheFinishedForKey:key]) {
            [self callCompletion:completion fullVideoPath:nil errorMessage:@"Joint debris data cache file not finished"];
            return;
        }
        
        NSString *modelsSavePath = [JPVideoPlayerCachePath videoCacheIndexSavePathForKey:key];
        NSData *modelsData = [NSData dataWithContentsOfFile:modelsSavePath];
        if (!modelsData) {
            [self callCompletion:completion fullVideoPath:nil errorMessage:@"Joint debris data have no debris data"];
            return;
        }
        
        NSArray<NSData *> *modelDatasExisted = [NSKeyedUnarchiver unarchiveObjectWithData:modelsData];
        if (!modelDatasExisted.count) {
            [self callCompletion:completion fullVideoPath:nil errorMessage:@"Joint debris data have no debris data"];
            return;
        }
        
        JPVideoPlayerCacheFile *metadataModel = nil;
        NSMutableArray<JPVideoPlayerCacheFile *> *modelsM = [@[] mutableCopy];
        for (NSData *data in modelDatasExisted) {
            JPVideoPlayerCacheFile *model = [NSKeyedUnarchiver unarchiveObjectWithData:data];
            NSParameterAssert(model && [model isKindOfClass:[JPVideoPlayerCacheFile class]]);
            if (model) {
                [modelsM addObject:model];
                if (model.isMetadata == YES) {
                    metadataModel = model;
                }
            }
        }
        if (!modelsM.count || !metadataModel) {
            [self callCompletion:completion fullVideoPath:nil errorMessage:@"Joint debris data have no debris data"];
            return;
        }
        
        NSString *metadataPath = [[JPVideoPlayerCachePath videoCacheTemporaryPathForKey:key] stringByAppendingPathComponent:metadataModel.dataName];
        while (modelsM.count != 1) {
            // joint debris video data by index.
            // 按照 index 进行拼接.
            JPVideoPlayerCacheFile *targetModel = nil;
            for (JPVideoPlayerCacheFile *model in modelsM) {
                if (model.isMetadata) {
                    continue;
                }
                
                if (targetModel == nil) {
                    targetModel = model;
                }
                else {
                    if (model.index < targetModel.index) {
                        targetModel = model;
                    }
                }
            }
            
            NSString *videoPath = [[JPVideoPlayerCachePath videoCacheTemporaryPathForKey:key] stringByAppendingPathComponent:targetModel.dataName];
            if (targetModel && videoPath && metadataPath && [[NSFileManager defaultManager] fileExistsAtPath:videoPath]) {
                [self internalJointData:[NSData dataWithContentsOfFile:videoPath] aPath:metadataPath append:YES];
                // remove model.
                [modelsM removeObject:targetModel];
            }
        }
        
        // joint finished.
        NSString *fullVideoPath = [JPVideoPlayerCachePath videoCacheFullPathForKey:key];
        NSError *error;
        [[NSFileManager defaultManager] moveItemAtPath:metadataPath toPath:fullVideoPath error:&error];
        if (error) {
            [self callCompletion:completion fullVideoPath:nil errorMessage:error.localizedDescription];
            return;
        }
        
        [self callCompletion:completion fullVideoPath:fullVideoPath errorMessage:nil];
        // remove temporary file.
        [[NSFileManager defaultManager] removeItemAtPath:[JPVideoPlayerCachePath videoCacheTemporaryPathForKey:key]  error:nil];
    });
    
}

- (BOOL)debrisVideoDataIsCacheFinishedForKey:(NSString *)key {
    NSParameterAssert(key);
    if (!key.length) {
        return NO;
    }
    
    NSString *modelsSavePath = [JPVideoPlayerCachePath videoCacheIndexSavePathForKey:key];
    NSData *modelsData = [NSData dataWithContentsOfFile:modelsSavePath];
    if (!modelsData.length) {
        return NO;
    }
    
    NSArray<NSData *> *modelDatasExisted = [NSKeyedUnarchiver unarchiveObjectWithData:modelsData];
    if (!modelDatasExisted.count) {
        return NO;
    }
    
    JPVideoPlayerCacheFile *metadataModel = nil;
    NSMutableArray<JPVideoPlayerCacheFile *> *modelsM = [@[] mutableCopy];
    for (NSData *data in modelDatasExisted) {
        JPVideoPlayerCacheFile *model = [NSKeyedUnarchiver unarchiveObjectWithData:data];
        NSParameterAssert(model && [model isKindOfClass:[JPVideoPlayerCacheFile class]]);
        if (model) {
            [modelsM addObject:model];
            if (model.isMetadata == YES) {
                metadataModel = model;
            }
        }
    }
    if (!modelsM.count || !metadataModel) {
        return NO;
    }
    
    // we will receive the total video size when play a video.
    // so we compare the cache video data total length and the expected size can know the video is cache finished or not.
    // 因为真实的请求视频数据过程中, 播放器会先请求前两个字节的数据, 此时服务器返回的数据里包含了整个视频的总长度.
    // 将这个长度和已经缓存的视频数据的总长度进行对比, 如果相等则说明视频已经全部缓存完毕, 否则就是视频还未缓存完毕.
    NSUInteger totalCacheVideoSize = 0;
    
    for (JPVideoPlayerCacheFile *model in modelsM) {
        NSString *dataPath = [[JPVideoPlayerCachePath videoCacheTemporaryPathForKey:model.key] stringByAppendingPathComponent:model.dataName];
        if (![[NSFileManager defaultManager] fileExistsAtPath:dataPath]) {
            return NO;
        }
        
        NSData *debrisData = [NSData dataWithContentsOfFile:dataPath];
        if (debrisData.length != model.expectedSize) {
            return NO;
        }
        
        totalCacheVideoSize += model.expectedSize;
    }
    
    return metadataModel.expectedSize == totalCacheVideoSize;
}

- (void)internalJointData:(NSData *)aData aPath:(NSString *)aPath append:(BOOL)append {
    NSParameterAssert(aData);
    NSParameterAssert(aPath);
    if (!aPath.length || !aData.length) {
        return;
    }
    
    NSOutputStream *outputStream = [[NSOutputStream alloc] initToFileAtPath:aPath append:append];
    [outputStream open];
    [outputStream write:aData.bytes maxLength:aData.length];
    [outputStream close];
}

- (void)callCompletion:(JPVideoPlayerDebrisJointCompletion)completion
         fullVideoPath:(NSString *)fullVideoPath
          errorMessage:(NSString *)msg {
    if (!completion) {
        return;
    }
    
    NSError *error = nil;
    if (msg) {
        error = [NSError errorWithDomain:JPVideoPlayerErrorDomain code:0 userInfo:@{NSLocalizedDescriptionKey : msg}];
    }
    dispatch_async(dispatch_get_main_queue(), ^{
        completion(fullVideoPath, error);
    });
}

@end
