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
#import "JPVideoPlayerCachePath.h"
#import "JPVideoPlayerCompat.h"
#import "JPVideoPlayerManager.h"
#import "JPVideoPlayerDebrisJointManager.h"
#import "JPVideoPlayerSupportUtils.h"

#include <sys/param.h>
#include <sys/mount.h>
#import <CommonCrypto/CommonDigest.h>
#import <pthread.h>

static const NSInteger kDefaultCacheMaxCacheAge = 60*60*24*7; // 1 week
static const NSInteger kDefaultCacheMaxSize = 1000*1000*1000; // 1 GB

@implementation JPVideoPlayerCacheConfig

- (instancetype)init{
    self = [super init];
    if (self) {
        _maxCacheAge =  kDefaultCacheMaxCacheAge;
        _maxCacheSize = kDefaultCacheMaxSize;
    }
    return self;
}

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
 * Joint Manager.
 */
@property(nonatomic, strong, nonnull) JPVideoPlayerDebrisJointManager *joinManager;

@end

@implementation JPVideoPlayerCacheTask

@end

@interface JPVideoPlayerCache()

@property (nonatomic, strong, nonnull) dispatch_queue_t ioQueue;

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

@implementation JPVideoPlayerCache{
    NSFileManager *_fileManager;
}

- (instancetype)initWithCacheConfig:(JPVideoPlayerCacheConfig *)cacheConfig {
    self = [super init];
    if (self) {
        // Create IO serial queue
        _ioQueue = dispatch_queue_create("com.NewPan.JPVideoPlayerCache", DISPATCH_QUEUE_SERIAL);
        pthread_mutexattr_t mutexattr;
        pthread_mutexattr_init(&mutexattr);
        pthread_mutexattr_settype(&mutexattr, PTHREAD_MUTEX_RECURSIVE);
        pthread_mutex_init(&_lock, &mutexattr);
        JPVideoPlayerCacheConfig *config = cacheConfig;
        if (!config) {
            config = [[JPVideoPlayerCacheConfig alloc] init];
        }
        _config = config;
        _fileManager = [NSFileManager defaultManager];
        _currentCacheTask = nil;
        
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


#pragma mark - Store Private

- (NSArray<NSData *> *)fetchModelsExistedForKey:(NSString *)key {
    NSParameterAssert(key);
    NSString *modelsSavePath = [JPVideoPlayerCachePath videoCacheIndexSavePathForKey:key];
    NSData *modelsData = [NSData dataWithContentsOfFile:modelsSavePath];
    if (!modelsData.length) {
        return nil;
    }
    
    return [NSKeyedUnarchiver unarchiveObjectWithData:modelsData];
}

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

- (nullable NSOperation *)queryCacheOperationForKey:(nullable NSString *)key done:(nullable JPVideoPlayerCacheQueryCompletion)doneBlock {
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
            BOOL exists = [_fileManager fileExistsAtPath:[JPVideoPlayerCachePath videoCacheFullPathForKey:key]];
            
            if (!exists) {
                exists = [_fileManager fileExistsAtPath:[JPVideoPlayerCachePath videoCacheFullPathForKey:key].stringByDeletingPathExtension];
            }
            
            if (exists) {
                if (doneBlock) {
                    dispatch_async(dispatch_get_main_queue(), ^{
                        doneBlock([JPVideoPlayerCachePath videoCacheFullPathForKey:key], JPVideoPlayerCacheTypeDisk);
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

- (void)diskVideoExistsWithKey:(NSString *)key completion:(JPVideoPlayerCheckCacheCompletion)completionBlock{
    dispatch_async(_ioQueue, ^{
        BOOL exists = [_fileManager fileExistsAtPath:[JPVideoPlayerCachePath videoCacheFullPathForKey:key]];
        
        if (!exists) {
            exists = [_fileManager fileExistsAtPath:[JPVideoPlayerCachePath videoCacheFullPathForKey:key].stringByDeletingPathExtension];
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

- (void)removeFullCacheForKey:(nullable NSString *)key withCompletion:(nullable dispatch_block_t)completion{
    dispatch_async(self.ioQueue, ^{
        if ([_fileManager fileExistsAtPath:[JPVideoPlayerCachePath videoCacheFullPathForKey:key]]) {
            [_fileManager removeItemAtPath:[JPVideoPlayerCachePath videoCacheFullPathForKey:key] error:nil];
            JPDispatchSyncOnMainQueue(^{
                if (completion) {
                    completion();
                }
            });
        }
    });
}

- (void)removeTempCacheForKey:(NSString * _Nonnull)key withCompletion:(nullable dispatch_block_t)completion{
    dispatch_async(self.ioQueue, ^{
        NSString *path = [JPVideoPlayerCachePath videoCachePathForAllTemporaryFile];
        path = [path stringByAppendingPathComponent:[[JPVideoPlayerCache sharedCache] cacheFileNameForKey:key]];
        NSFileManager *fileManager = [NSFileManager defaultManager];
        if ([fileManager fileExistsAtPath:path]) {
            [fileManager removeItemAtPath:path error:nil];
            JPDispatchSyncOnMainQueue(^{
                if (completion) {
                    completion();
                }
            });
            // For Test.
            // printf("Remove temp video data finished, file url string is %@", key);
        }
    });
}

- (void)deleteOldFilesWithCompletionBlock:(nullable dispatch_block_t)completionBlock{
    dispatch_async(self.ioQueue, ^{
        NSURL *diskCacheURL = [NSURL fileURLWithPath:[JPVideoPlayerCachePath videoCachePathForAllFullFile] isDirectory:YES];
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

- (void)deleteAllTempCacheOnCompletion:(nullable dispatch_block_t)completion{
    dispatch_async(self.ioQueue, ^{
        [_fileManager removeItemAtPath:[JPVideoPlayerCachePath videoCachePathForAllTemporaryFile] error:nil];
        JPDispatchSyncOnMainQueue(^{
            if (completion) {
                completion();
            }
        });
    });
}

- (void)clearDiskOnCompletion:(nullable dispatch_block_t)completion{
    dispatch_async(self.ioQueue, ^{
        [_fileManager removeItemAtPath:[JPVideoPlayerCachePath videoCachePathForAllFullFile] error:nil];
        [_fileManager removeItemAtPath:[JPVideoPlayerCachePath videoCachePathForAllTemporaryFile] error:nil];
        JPDispatchSyncOnMainQueue(^{
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
        NSString *tempFilePath = [JPVideoPlayerCachePath videoCachePathForAllTemporaryFile];
        NSString *fullFilePath = [JPVideoPlayerCachePath videoCachePathForAllFullFile];
        
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
        NSString *tempFilePath = [JPVideoPlayerCachePath videoCachePathForAllTemporaryFile];
        NSString *fullFilePath = [JPVideoPlayerCachePath videoCachePathForAllFullFile];
        
        NSDirectoryEnumerator *fileEnumerator_temp = [_fileManager enumeratorAtPath:tempFilePath];
        count += fileEnumerator_temp.allObjects.count;
        
        NSDirectoryEnumerator *fileEnumerator_full = [_fileManager enumeratorAtPath:fullFilePath];
        count += fileEnumerator_full.allObjects.count;
    });
    return count;
}

- (void)calculateSizeWithCompletionBlock:(JPVideoPlayerCalculateSizeCompletion)completionBlock{
    
    NSString *tempFilePath = [JPVideoPlayerCachePath videoCachePathForAllTemporaryFile];
    NSString *fullFilePath = [JPVideoPlayerCachePath videoCachePathForAllFullFile];
    
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
