//
//  JPVideoPlayerDebrisJointManager.m
//  JPVideoPlayerDemo
//
//  Created by 尹久盼 on 2018/1/1.
//  Copyright © 2018年 NewPan. All rights reserved.
//

#import "JPVideoPlayerDebrisJointManager.h"
#import "JPVideoPlayerCachePathManager.h"
#import "JPVideoPlayerCacheModel.h"

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
    if (!key.length && completion) {
        completion(nil, [self generateErrorWithErrorMessage:@"Joint debris data need a key"]);
    }
    
    dispatch_async(self.ioQueue, ^{
        if (![self debrisVideoDataIsCacheFinishedForKey:key]) {
            if (completion) {
                completion(nil, [self generateErrorWithErrorMessage:@"Joint debris data cache file not finished"]);
            }
            return;
        }
        
        NSString *modelsSavePath = [JPVideoPlayerCachePathManager videoCacheModelsSavePathForKey:key];
        NSData *modelsData = [NSData dataWithContentsOfFile:modelsSavePath];
        if (!modelsData.length) {
            if (completion) {
                completion(nil, [self generateErrorWithErrorMessage:@"Joint debris data have no debris data"]);
            }
            return;
        }
        
        NSArray<NSData *> *modelDatasExisted = [NSKeyedUnarchiver unarchiveObjectWithData:modelsData];
        if (!modelDatasExisted.count) {
            if (completion) {
                completion(nil, [self generateErrorWithErrorMessage:@"Joint debris data have no debris data"]);
            }
            return;
        }
        
        JPVideoPlayerCacheModel *metadataModel = nil;
        NSMutableArray<JPVideoPlayerCacheModel *> *modelsM = [@[] mutableCopy];
        for (NSData *data in modelDatasExisted) {
            JPVideoPlayerCacheModel *model = [NSKeyedUnarchiver unarchiveObjectWithData:data];
            NSParameterAssert(model && [model isKindOfClass:[JPVideoPlayerCacheModel class]]);
            if (model) {
                [modelsM addObject:model];
                if (model.isMetadata == YES) {
                    metadataModel = model;
                }
            }
        }
        if (!modelsM.count || !metadataModel) {
            if (completion) {
                completion(nil, [self generateErrorWithErrorMessage:@"Joint debris data have no debris data"]);
            }
            return;
        }
        
        NSMutableDictionary *dictM = [@{} mutableCopy];
        for (JPVideoPlayerCacheModel *model in modelsM) {
            NSString *dataPath = [[JPVideoPlayerCachePathManager videoCacheTemporaryPathForKey:model.key] stringByAppendingPathComponent:model.dataName];
            if ([[NSFileManager defaultManager] fileExistsAtPath:dataPath]) {
                NSData *data = [NSData dataWithContentsOfFile:dataPath];
                if (data.length) {
                    [dictM setObject:data forKey:model];
                }
            }
        }
        
        NSString *metadataPath = [[JPVideoPlayerCachePathManager videoCacheTemporaryPathForKey:key] stringByAppendingPathComponent:metadataModel.dataName];
        while (dictM.allKeys.count != 1) {
            JPVideoPlayerCacheModel *targetModel = nil;
            for (JPVideoPlayerCacheModel *model in dictM.allKeys) {
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
            
            
            NSString *videoPath = [[JPVideoPlayerCachePathManager videoCacheTemporaryPathForKey:key] stringByAppendingPathComponent:targetModel.dataName];
            if (targetModel && videoPath && metadataPath) {
                [self internalStoreData:[NSData dataWithContentsOfFile:videoPath] aPath:metadataPath append:YES];
            }
        }
    });
    
}

- (BOOL)debrisVideoDataIsCacheFinishedForKey:(NSString *)key {
    NSParameterAssert(key);
    if (!key.length) {
        return NO;
    }
    
    NSString *modelsSavePath = [JPVideoPlayerCachePathManager videoCacheModelsSavePathForKey:key];
    NSData *modelsData = [NSData dataWithContentsOfFile:modelsSavePath];
    if (!modelsData.length) {
        return NO;
    }
    
    NSArray<NSData *> *modelDatasExisted = [NSKeyedUnarchiver unarchiveObjectWithData:modelsData];
    if (!modelDatasExisted.count) {
        return NO;
    }
    
    JPVideoPlayerCacheModel *metadataModel = nil;
    NSMutableArray<JPVideoPlayerCacheModel *> *modelsM = [@[] mutableCopy];
    for (NSData *data in modelDatasExisted) {
        JPVideoPlayerCacheModel *model = [NSKeyedUnarchiver unarchiveObjectWithData:data];
        NSParameterAssert(model && [model isKindOfClass:[JPVideoPlayerCacheModel class]]);
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
    
    for (JPVideoPlayerCacheModel *model in modelsM) {
        NSString *dataPath = [[JPVideoPlayerCachePathManager videoCacheTemporaryPathForKey:model.key] stringByAppendingPathComponent:model.dataName];
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

- (void)internalStoreData:(NSData *)aData aPath:(NSString *)aPath append:(BOOL)append {
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

- (NSError *)generateErrorWithErrorMessage:(NSString *)msg {
    NSCParameterAssert(msg);
    return [NSError errorWithDomain:JPVideoPlayerErrorDomain code:0 userInfo:@{NSLocalizedDescriptionKey : msg}];
}

@end
