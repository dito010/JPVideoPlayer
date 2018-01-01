/*
 * This file is part of the JPVideoPlayer package.
 * (c) NewPan <13246884282@163.com>
 *
 * For the full copyright and license information, please view the LICENSE
 * file that was distributed with this source code.
 *
 * Click https://github.com/Chris-Pan
 * or http://www.jianshu.com/users/e2f2d779c022/latest_articles to contact me.
 */


#import "JPVideoPlayerCache.h"
#import "JPVideoPlayerCacheConfig.h"
#import "JPVideoPlayerCachePathManager.h"
#import "JPVideoPlayerCompat.h"
#import "JPVideoPlayerManager.h"
#import "JPVideoPlayerDownloaderOperation.h"
#import "JPVideoPlayerCacheModel.h"

#include <sys/param.h>
#include <sys/mount.h>
#import <CommonCrypto/CommonDigest.h>
#import "NSURL+QueryStrip.h"
#import <pthread.h>

@interface JPVideoPlayerCacheToken()

/**
 * outputStream.
 */
@property(nonnull, nonatomic, strong)NSOutputStream *outputStream;

/**
 * Received video size.
 */
@property(nonatomic, assign)NSUInteger receivedVideoSize;

/**
 * key.
 */
@property(nonnull, nonatomic, strong)NSString *key;

@end

@implementation JPVideoPlayerCacheToken

@end


@interface JPVideoPlayerCacheTask: NSObject

/**
 * videoSavePath.
 */
@property(nonnull, nonatomic, copy)NSString *videoSavePath;

/**
 * Received video size.
 */
@property(nonatomic, assign)NSUInteger receivedVideoSize;

/*
 * model.
 */
@property(nonatomic, strong, nonnull) JPVideoPlayerCacheModel *model;

@end

@implementation JPVideoPlayerCacheTask

@end

@interface JPVideoPlayerCache()

@property (nonatomic, strong, nonnull) dispatch_queue_t ioQueue;

/**
 * OutputStreams.
 */
@property(nonatomic, strong, nonnull)NSMutableArray<JPVideoPlayerCacheToken *> *outputStreams;

/**
 * completionBlock can be call or not.
 */
@property(nonatomic, assign, getter=isCompletionBlockEnable)BOOL completionBlockEnable;

@property (nonatomic) pthread_mutex_t lock;

/*
 * current cache task.
 */
@property(nonatomic, strong) JPVideoPlayerCacheTask *currentCacheTask;

@end

static NSString *const kJPVideoPlayerCacheErrorDomain = @"com.jpvideoplayer.error.domain.www";
@implementation JPVideoPlayerCache{
    NSFileManager *_fileManager;
}

- (void)dealloc {
    pthread_mutex_destroy(&_lock);
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (instancetype)initWithCacheConfig:(JPVideoPlayerCacheConfig *)cacheConfig {
    self = [super init];
    if (self) {
        // Create IO serial queue
        _ioQueue = dispatch_queue_create("com.NewPan.JPVideoPlayerCache", DISPATCH_QUEUE_SERIAL);
        pthread_mutex_init(&(_lock), NULL);
        JPVideoPlayerCacheConfig *config = cacheConfig;
        if (!config) {
            config = [[JPVideoPlayerCacheConfig alloc] init];
        }
        _config = config;
        _fileManager = [NSFileManager defaultManager];
        _outputStreams = [NSMutableArray array];
        _currentCacheTask = nil;
        
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(downloadVideoDidStart:) name:JPVideoPlayerDownloadStartNotification object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(deleteOldFiles)
                                                     name:UIApplicationWillTerminateNotification
                                                   object:nil];
        
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(backgroundDeleteOldFiles)
                                                     name:UIApplicationDidEnterBackgroundNotification
                                                   object:nil];
    }
    return self;
}

- (instancetype)init{
    NSAssert(NO, @"please use given init method");
    return [self initWithCacheConfig:nil];
}

+ (nonnull instancetype)sharedCache {
    static dispatch_once_t once;
    static id instance;
    dispatch_once(&once, ^{
        instance = [[self alloc] initWithCacheConfig:nil];
    });
    return instance;
}


#pragma mark - Store Video Options

- (void)downloadVideoDidStart:(NSNotification *)notification{
    JPVideoPlayerDownloaderOperation *operation = notification.object;
    NSURL *url = operation.request.URL;
    NSString *key = [[JPVideoPlayerManager sharedManager] cacheKeyForURL:url];
    [self removeTempCacheForKey:key withCompletion:nil];
    
    @autoreleasepool {
        [self.outputStreams removeAllObjects];
    }
}

- (nullable JPVideoPlayerCacheToken *)storeVideoData:(nullable NSData *)videoData expectedSize:(NSUInteger)expectedSize forKey:(nullable NSString *)key completion:(nullable JPVideoPlayerStoreDataFinishedBlock)completionBlock{
    
    if (videoData.length==0) return nil;
    
    if (key.length==0) {
        if (completionBlock){
            NSError *error = [NSError errorWithDomain:kJPVideoPlayerCacheErrorDomain code:0 userInfo:@{NSLocalizedDescriptionKey : @"Need a key for storing video data"}];
            completionBlock(0, error, nil);
        }
        return nil;
    }
    
    // Check the free size of the device.
    if (![self haveFreeSizeToCacheFileWithSize:expectedSize]) {
        if (completionBlock){
            NSError *error = [NSError errorWithDomain:kJPVideoPlayerCacheErrorDomain code:0 userInfo:@{NSLocalizedDescriptionKey : @"No enough size of device to cache the video data"}];
            completionBlock(0, error, nil);
        }
        return nil;
    }
    
    @synchronized (self) {
        self.completionBlockEnable = YES;
        JPVideoPlayerCacheToken *targetToken = nil;
        for (JPVideoPlayerCacheToken *token in self.outputStreams) {
            if ([token.key isEqualToString:key]) {
                targetToken = token;
                break;
            }
        }
        if (!targetToken) {
            NSString *path = [JPVideoPlayerCachePathManager videoCacheTemporaryPathForKey:key];
            NSOutputStream *stream = [[NSOutputStream alloc]initToFileAtPath:path append:YES];
            [stream open];
            JPVideoPlayerCacheToken *token = [JPVideoPlayerCacheToken new];
            token.key = key;
            token.outputStream = stream;
            [self.outputStreams addObject:token];
            targetToken = token;
        }

        if (videoData.length>0) {
            dispatch_async(self.ioQueue, ^{
                [targetToken.outputStream write:videoData.bytes maxLength:videoData.length];
                targetToken.receivedVideoSize += videoData.length;
                
                NSString *tempVideoCachePath = [JPVideoPlayerCachePathManager videoCacheTemporaryPathForKey:key];
                
                // transform to NSUrl
                NSURL *fileURL = [NSURL fileURLWithPath:tempVideoCachePath];
                
                // disable iCloud backup
                if (self.config.shouldDisableiCloud) {
                    [fileURL setResourceValue:@YES forKey:NSURLIsExcludedFromBackupKey error:nil];
                }
                
                if (completionBlock) {
                    NSString *fullVideoCachePath = nil;
                    NSError *error = nil;
                    if (targetToken.receivedVideoSize==expectedSize) {
                        fullVideoCachePath = [JPVideoPlayerCachePathManager videoCacheFullPathForKey:key];
                        [_fileManager moveItemAtPath:tempVideoCachePath toPath:fullVideoCachePath error:&error];
                    }
                    
                    dispatch_async(dispatch_get_main_queue(), ^{
                        if (self.completionBlockEnable) {
                            completionBlock(targetToken.receivedVideoSize, error, fullVideoCachePath);
                        }
                    });
                }
                
                // cache temporary video data finished.
                // close the stream.
                // remove the cache operation.
                if (targetToken.receivedVideoSize==expectedSize) {
                    [targetToken.outputStream close];
                    [self.outputStreams removeObject:targetToken];
                    self.completionBlockEnable = NO;
                }
            });
        }
        return targetToken;
    }
}

- (void)_storeVideoData:(NSData *)videoData
           expectedSize:(NSUInteger)expectedSize
                 forKey:(NSString *)key
             completion:(JPVideoPlayerStoreDataFinishedBlock)completionBlock {
    NSParameterAssert(videoData.length);
    NSParameterAssert(key.length);
    if (!videoData.length) return;
    
    if (!key.length) {
        if (completionBlock){
            NSError *error = [NSError errorWithDomain:kJPVideoPlayerCacheErrorDomain code:0 userInfo:@{NSLocalizedDescriptionKey : @"Need a key for storing video data"}];
            completionBlock(0, error, nil);
        }
        return;
    }
    
    // Check the free size of the device.
    // 检查是否有足够的磁盘缓存.
    if (![self haveFreeSizeToCacheFileWithSize:expectedSize]) {
        if (completionBlock){
            NSError *error = [NSError errorWithDomain:kJPVideoPlayerCacheErrorDomain code:0 userInfo:@{NSLocalizedDescriptionKey : @"No enough size of device to cache the video data"}];
            completionBlock(0, error, nil);
        }
        return;
    }
    
    dispatch_async(self.ioQueue, ^{
        // the first time receive the video data for given key.
        // 某个请求第一次返回数据.
        if (!self.currentCacheTask) {
            JPVideoPlayerCacheTask *cacheTask = [JPVideoPlayerCacheTask new];
            // the path of models(model recorde the video data message).
            // 存储模型的路径(模型里记录了存储视频的信息).
            NSString *modelsSavePath = [JPVideoPlayerCachePathManager videoCacheModelsSavePathForKey:key];
            NSLog(@"modelsSavePath: %@", modelsSavePath);
            NSData *modelsData = [NSData dataWithContentsOfFile:modelsSavePath];
            
            NSMutableArray<NSData *> *modelDatasM = [@[] mutableCopy];
            JPVideoPlayerCacheModel *model = nil;
            NSString *dataName = nil;
            if (!modelsData.length) {
                // first save video data for key.
                // 某个视频第一次请求返回数据.
                dataName = @"dataDebris0";
                model = [[JPVideoPlayerCacheModel alloc] initWithKey:key
                                                        expectedSize:expectedSize
                                                            dataName:dataName
                                                               index:0
                                                          isMetadata:YES];
            }
            else{
                NSArray<NSData *> *modelDatasExisted = [NSKeyedUnarchiver unarchiveObjectWithData:modelsData];
                NSParameterAssert(modelDatasExisted);
                if (modelDatasExisted) {
                    [modelDatasM addObjectsFromArray:modelDatasExisted];
                }
                dataName = [NSString stringWithFormat:@"dataDebris%ld", modelDatasExisted.count];
                // frist time receive video for a request(but not first request for given key).
                // 某个请求第一次返回数据(但不是第一次请求).
                model = [[JPVideoPlayerCacheModel alloc] initWithKey:key
                                                        expectedSize:expectedSize
                                                            dataName:dataName
                                                               index:modelDatasExisted.count
                                                          isMetadata:NO];
            }
            
            // archiver models then store it.
            // 归档模型, 并存储.
            NSData *data = [NSKeyedArchiver archivedDataWithRootObject:model];
            NSParameterAssert(data);
            if (data) {
                [modelDatasM addObject:data];
            }
            NSOutputStream *modelsStream = [self internalStoreModelsData:[NSKeyedArchiver archivedDataWithRootObject:modelDatasM] aPath:modelsSavePath];
            [self internalCloseOutputStream:modelsStream];
            
            NSString *videoSavePath = [[JPVideoPlayerCachePathManager videoCacheTemporaryPathForKey:key] stringByAppendingPathComponent:dataName];
            cacheTask.videoSavePath =  videoSavePath;
            NSOutputStream *videoStream = [self internalStoreVideoData:videoData videoPath:videoSavePath];
            cacheTask.receivedVideoSize += videoData.length;
            cacheTask.videoSavePath = videoSavePath;
            cacheTask.model = model;
            self.currentCacheTask = cacheTask;
            [self internalCloseOutputStream:videoStream];
            
            if (completionBlock) {
//                completionBlock();
            }
        }
        else {
            // store the last video data for a request.
            // 某个请求的接下来的响应数据, 继续存储.
            NSParameterAssert(self.currentCacheTask.videoSavePath.length);
            NSOutputStream *videoStream = [self internalStoreVideoData:videoData videoPath:self.currentCacheTask.videoSavePath];
            [self internalCloseOutputStream:videoStream];
        }
        
    });
}

- (void)reset {
    if (!self.currentCacheTask) {
        return;
    }
    
    self.currentCacheTask = nil;
}

- (void)cancel:(nullable JPVideoPlayerCacheToken *)token{
    if (token) {
        [self.outputStreams removeObject:token];
        [self disableCurrentCompletion];
    }
}

- (void)disableCurrentCompletion{
    self.completionBlockEnable = NO;
}


#pragma mark - Store Private

- (NSOutputStream *)internalStoreVideoData:(NSData *)videoData videoPath:(NSString *)videoPath {
    // watch out that video data need appending.
    // 注意: 视频数据的写入是需要 append 的.
    return [self internalStoreData:videoData aPath:videoPath append:YES];
}

- (NSOutputStream *)internalStoreModelsData:(NSData *)modelsData aPath:(NSString *)aPath {
    // models data forbid appending.
    // 注意: 模型数据的写入是禁止 append 的.
    return [self internalStoreData:modelsData aPath:aPath append:NO];
}

- (NSOutputStream *)internalStoreData:(NSData *)aData aPath:(NSString *)aPath append:(BOOL)append {
    NSParameterAssert(aData);
    NSParameterAssert(aPath);
    if (!aPath.length || !aData.length) {
        return nil;
    }
    
    NSOutputStream *outputStream = [[NSOutputStream alloc] initToFileAtPath:aPath append:append];
    [outputStream open];
    [outputStream write:aData.bytes maxLength:aData.length];
    return outputStream;
}

- (void)internalCloseOutputStream:(NSOutputStream *)outputStream {
    NSParameterAssert(outputStream);
    [outputStream close];
}


#pragma mark - Query and Retrieve Options

- (nullable NSOperation *)queryCacheOperationForKey:(nullable NSString *)key done:(nullable JPVideoPlayerCacheQueryCompletedBlock)doneBlock {
    if (!key) {
        if (doneBlock) {
            doneBlock(nil, JPVideoPlayerCacheTypeNone);
        }
        return nil;
    }
    
    NSOperation *operation = [NSOperation new];
    dispatch_async(self.ioQueue, ^{
        if (operation.isCancelled) {
            // do not call the completion if cancelled
            return;
        }
        
        @autoreleasepool {
            BOOL exists = [_fileManager fileExistsAtPath:[JPVideoPlayerCachePathManager videoCacheFullPathForKey:key]];
            
            if (!exists) {
                exists = [_fileManager fileExistsAtPath:[JPVideoPlayerCachePathManager videoCacheFullPathForKey:key].stringByDeletingPathExtension];
            }
            
            if (exists) {
                if (doneBlock) {
                    dispatch_async(dispatch_get_main_queue(), ^{
                        doneBlock([JPVideoPlayerCachePathManager videoCacheFullPathForKey:key], JPVideoPlayerCacheTypeDisk);
                    });
                }
            }
            else{
                if (doneBlock) {
                    dispatch_async(dispatch_get_main_queue(), ^{
                        doneBlock(nil, JPVideoPlayerCacheTypeNone);
                    });
                }
            }
        }
    });
    
    return operation;
}

- (void)diskVideoExistsWithKey:(NSString *)key completion:(JPVideoPlayerCheckCacheCompletionBlock)completionBlock{
    dispatch_async(_ioQueue, ^{
        BOOL exists = [_fileManager fileExistsAtPath:[JPVideoPlayerCachePathManager videoCacheFullPathForKey:key]];

        if (!exists) {
            exists = [_fileManager fileExistsAtPath:[JPVideoPlayerCachePathManager videoCacheFullPathForKey:key].stringByDeletingPathExtension];
        }
        
        if (completionBlock) {
            dispatch_async(dispatch_get_main_queue(), ^{
                completionBlock(exists);
            });
        }
    });
}

- (BOOL)diskVideoExistsWithPath:(NSString * _Nullable)fullVideoCachePath{
    return [_fileManager fileExistsAtPath:fullVideoCachePath];
}


#pragma mark - Clear Cache Events

- (void)removeFullCacheForKey:(nullable NSString *)key withCompletion:(nullable JPVideoPlayerNoParamsBlock)completion{
    dispatch_async(self.ioQueue, ^{
        if ([_fileManager fileExistsAtPath:[JPVideoPlayerCachePathManager videoCacheFullPathForKey:key]]) {
            [_fileManager removeItemAtPath:[JPVideoPlayerCachePathManager videoCacheFullPathForKey:key] error:nil];
            dispatch_main_async_safe(^{
                if (completion) {
                    completion();
                }
            });
        }
    });
}

- (void)removeTempCacheForKey:(NSString * _Nonnull)key withCompletion:(nullable JPVideoPlayerNoParamsBlock)completion{
    dispatch_async(self.ioQueue, ^{
        NSString *path = [JPVideoPlayerCachePathManager videoCachePathForAllTemporaryFile];
        path = [path stringByAppendingPathComponent:[[JPVideoPlayerCache sharedCache] cacheFileNameForKey:key]];
        NSFileManager *fileManager = [NSFileManager defaultManager];
        if ([fileManager fileExistsAtPath:path]) {
            [fileManager removeItemAtPath:path error:nil];
            dispatch_main_async_safe(^{
                if (completion) {
                    completion();
                }
            });
            // For Test.
            // printf("Remove temp video data finished, file url string is %@", key);
        }
    });
}

- (void)deleteOldFilesWithCompletionBlock:(nullable JPVideoPlayerNoParamsBlock)completionBlock{
    dispatch_async(self.ioQueue, ^{
        NSURL *diskCacheURL = [NSURL fileURLWithPath:[JPVideoPlayerCachePathManager videoCachePathForAllFullFile] isDirectory:YES];
        NSArray<NSString *> *resourceKeys = @[NSURLIsDirectoryKey, NSURLContentModificationDateKey, NSURLTotalFileAllocatedSizeKey];
        
        // This enumerator prefetches useful properties for our cache files.
        NSDirectoryEnumerator *fileEnumerator = [_fileManager enumeratorAtURL:diskCacheURL
                                                   includingPropertiesForKeys:resourceKeys
                                                                      options:NSDirectoryEnumerationSkipsHiddenFiles
                                                                 errorHandler:NULL];
        
        NSDate *expirationDate = [NSDate dateWithTimeIntervalSinceNow:-self.config.maxCacheAge];
        NSMutableDictionary<NSURL *, NSDictionary<NSString *, id> *> *cacheFiles = [NSMutableDictionary dictionary];
        NSUInteger currentCacheSize = 0;
        
        // Enumerate all of the files in the cache directory.  This loop has two purposes:
        //
        //  1. Removing files that are older than the expiration date.
        //  2. Storing file attributes for the size-based cleanup pass.
        NSMutableArray<NSURL *> *urlsToDelete = [[NSMutableArray alloc] init];
       
        @autoreleasepool {
            for (NSURL *fileURL in fileEnumerator) {
                NSError *error;
                NSDictionary<NSString *, id> *resourceValues = [fileURL resourceValuesForKeys:resourceKeys error:&error];
                
                // Skip directories and errors.
                if (error || !resourceValues || [resourceValues[NSURLIsDirectoryKey] boolValue]) {
                    continue;
                }
                
                // Remove files that are older than the expiration date;
                NSDate *modificationDate = resourceValues[NSURLContentModificationDateKey];
                if ([[modificationDate laterDate:expirationDate] isEqualToDate:expirationDate]) {
                    [urlsToDelete addObject:fileURL];
                    continue;
                }
                
                // Store a reference to this file and account for its total size.
                NSNumber *totalAllocatedSize = resourceValues[NSURLTotalFileAllocatedSizeKey];
                currentCacheSize += totalAllocatedSize.unsignedIntegerValue;
                cacheFiles[fileURL] = resourceValues;
            }
        }
        
        for (NSURL *fileURL in urlsToDelete) {
            [_fileManager removeItemAtURL:fileURL error:nil];
        }
        
        // If our remaining disk cache exceeds a configured maximum size, perform a second
        // size-based cleanup pass.  We delete the oldest files first.
        if (self.config.maxCacheSize > 0 && currentCacheSize > self.config.maxCacheSize) {
            // Target half of our maximum cache size for this cleanup pass.
            const NSUInteger desiredCacheSize = self.config.maxCacheSize / 2;
            
            // Sort the remaining cache files by their last modification time (oldest first).
            NSArray<NSURL *> *sortedFiles = [cacheFiles keysSortedByValueWithOptions:NSSortConcurrent
                                                                     usingComparator:^NSComparisonResult(id obj1, id obj2) {
                                                                         return [obj1[NSURLContentModificationDateKey] compare:obj2[NSURLContentModificationDateKey]];
                                                                     }];
            
            // Delete files until we fall below our desired cache size.
            for (NSURL *fileURL in sortedFiles) {
                if ([_fileManager removeItemAtURL:fileURL error:nil]) {
                    NSDictionary<NSString *, id> *resourceValues = cacheFiles[fileURL];
                    NSNumber *totalAllocatedSize = resourceValues[NSURLTotalFileAllocatedSizeKey];
                    currentCacheSize -= totalAllocatedSize.unsignedIntegerValue;
                    
                    if (currentCacheSize < desiredCacheSize) {
                        break;
                    }
                }
            }
        }
        if (completionBlock) {
            dispatch_async(dispatch_get_main_queue(), ^{
                completionBlock();
            });
        }
    });
}

- (void)deleteAllTempCacheOnCompletion:(nullable JPVideoPlayerNoParamsBlock)completion{
    dispatch_async(self.ioQueue, ^{
        [_fileManager removeItemAtPath:[JPVideoPlayerCachePathManager videoCachePathForAllTemporaryFile] error:nil];
        dispatch_main_async_safe(^{
            if (completion) {
                completion();
            }
        });
    });
}

- (void)clearDiskOnCompletion:(nullable JPVideoPlayerNoParamsBlock)completion{
    dispatch_async(self.ioQueue, ^{
        [_fileManager removeItemAtPath:[JPVideoPlayerCachePathManager videoCachePathForAllFullFile] error:nil];
        [_fileManager removeItemAtPath:[JPVideoPlayerCachePathManager videoCachePathForAllTemporaryFile] error:nil];
        dispatch_main_async_safe(^{
            if (completion) {
                completion();
            }
        });
    });
}


#pragma mark - File Name

- (nullable NSString *)cacheFileNameForKey:(nullable NSString *)key{
    return [self cachedFileNameForKey:key];
}

- (nullable NSString *)cachedFileNameForKey:(nullable NSString *)key {
    if ([key length]) {
        NSString *strippedQueryKey = [[NSURL URLWithString:key] absoluteStringByStrippingQuery];
        key = [strippedQueryKey length] ? strippedQueryKey : key;
    }
    
    const char *str = key.UTF8String;
    if (str == NULL) str = "";
    unsigned char r[CC_MD5_DIGEST_LENGTH];
    CC_MD5(str, (CC_LONG)strlen(str), r);
    NSString *filename = [NSString stringWithFormat:@"%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x",
                          r[0], r[1], r[2], r[3], r[4], r[5], r[6], r[7], r[8], r[9], r[10],
                          r[11], r[12], r[13], r[14], r[15]];
    return filename;
}


#pragma mark - Cache Info

- (BOOL)haveFreeSizeToCacheFileWithSize:(NSUInteger)fileSize{
    unsigned long long freeSizeOfDevice = [self getDiskFreeSize];
    if (fileSize > freeSizeOfDevice) {
        return NO;
    }
    return YES;
}

- (unsigned long long)getSize{
    __block unsigned long long size = 0;
    dispatch_sync(self.ioQueue, ^{
        NSString *tempFilePath = [JPVideoPlayerCachePathManager videoCachePathForAllTemporaryFile];
        NSString *fullFilePath = [JPVideoPlayerCachePathManager videoCachePathForAllFullFile];
        
        NSDirectoryEnumerator *fileEnumerator_temp = [_fileManager enumeratorAtPath:tempFilePath];
        
        @autoreleasepool {
            for (NSString *fileName in fileEnumerator_temp) {
                NSString *filePath = [tempFilePath stringByAppendingPathComponent:fileName];
                NSDictionary<NSString *, id> *attrs = [[NSFileManager defaultManager] attributesOfItemAtPath:filePath error:nil];
                size += [attrs fileSize];
            }
            
            NSDirectoryEnumerator *fileEnumerator_full = [_fileManager enumeratorAtPath:fullFilePath];
            for (NSString *fileName in fileEnumerator_full) {
                NSString *filePath = [fullFilePath stringByAppendingPathComponent:fileName];
                NSDictionary<NSString *, id> *attrs = [[NSFileManager defaultManager] attributesOfItemAtPath:filePath error:nil];
                size += [attrs fileSize];
            }
        }
    });
    return size;
}

- (NSUInteger)getDiskCount{
    __block NSUInteger count = 0;
    dispatch_sync(self.ioQueue, ^{
        NSString *tempFilePath = [JPVideoPlayerCachePathManager videoCachePathForAllTemporaryFile];
        NSString *fullFilePath = [JPVideoPlayerCachePathManager videoCachePathForAllFullFile];
        
        NSDirectoryEnumerator *fileEnumerator_temp = [_fileManager enumeratorAtPath:tempFilePath];
        count += fileEnumerator_temp.allObjects.count;
        
        NSDirectoryEnumerator *fileEnumerator_full = [_fileManager enumeratorAtPath:fullFilePath];
        count += fileEnumerator_full.allObjects.count;
    });
    return count;
}

- (void)calculateSizeWithCompletionBlock:(JPVideoPlayerCalculateSizeBlock)completionBlock{
    
    NSString *tempFilePath = [JPVideoPlayerCachePathManager videoCachePathForAllTemporaryFile];
    NSString *fullFilePath = [JPVideoPlayerCachePathManager videoCachePathForAllFullFile];
    
    NSURL *diskCacheURL_temp = [NSURL fileURLWithPath:tempFilePath isDirectory:YES];
    NSURL *diskCacheURL_full = [NSURL fileURLWithPath:fullFilePath isDirectory:YES];
    
    dispatch_async(self.ioQueue, ^{
        NSUInteger fileCount = 0;
        NSUInteger totalSize = 0;
        
        NSDirectoryEnumerator *fileEnumerator_temp = [_fileManager enumeratorAtURL:diskCacheURL_temp includingPropertiesForKeys:@[NSFileSize] options:NSDirectoryEnumerationSkipsHiddenFiles errorHandler:NULL];
        for (NSURL *fileURL in fileEnumerator_temp) {
            NSNumber *fileSize;
            [fileURL getResourceValue:&fileSize forKey:NSURLFileSizeKey error:NULL];
            totalSize += fileSize.unsignedIntegerValue;
            fileCount += 1;
        }
        
        NSDirectoryEnumerator *fileEnumerator_full = [_fileManager enumeratorAtURL:diskCacheURL_full includingPropertiesForKeys:@[NSFileSize] options:NSDirectoryEnumerationSkipsHiddenFiles errorHandler:NULL];
        for (NSURL *fileURL in fileEnumerator_full) {
            NSNumber *fileSize;
            [fileURL getResourceValue:&fileSize forKey:NSURLFileSizeKey error:NULL];
            totalSize += fileSize.unsignedIntegerValue;
            fileCount += 1;
        }
        
        if (completionBlock) {
            dispatch_async(dispatch_get_main_queue(), ^{
                completionBlock(fileCount, totalSize);
            });
        }
    });
}

- (unsigned long long)getDiskFreeSize{
    struct statfs buf;
    unsigned long long freespace = -1;
    if(statfs("/var", &buf) >= 0){
        freespace = (long long)(buf.f_bsize * buf.f_bfree);
    }
    return freespace;
}


#pragma mark - Private

- (void)deleteOldFiles {
    [self deleteOldFilesWithCompletionBlock:nil];
    [self deleteAllTempCacheOnCompletion:nil];
}

- (void)backgroundDeleteOldFiles {
    Class UIApplicationClass = NSClassFromString(@"UIApplication");
    if(!UIApplicationClass || ![UIApplicationClass respondsToSelector:@selector(sharedApplication)]) {
        return;
    }
    UIApplication *application = [UIApplication performSelector:@selector(sharedApplication)];
    __block UIBackgroundTaskIdentifier bgTask = [application beginBackgroundTaskWithExpirationHandler:^{
        // Clean up any unfinished task business by marking where you
        // stopped or ending the task outright.
        [application endBackgroundTask:bgTask];
        bgTask = UIBackgroundTaskInvalid;
    }];
    
    // Start the long-running task and return immediately.
    [self deleteOldFilesWithCompletionBlock:^{
        [application endBackgroundTask:bgTask];
        bgTask = UIBackgroundTaskInvalid;
    }];
}

@end
