/*
 * This file is part of the JPVideoPlayer package.
 * (c) NewPan <13246884282@163.com>
 *
 * For the full copyright and license information, please view the LICENSE
 * file that was distributed with this source code.
 *
 * Click https://github.com/newyjp
 * or http://www.jianshu.com/users/e2f2d779c022/latest_articles to contact me.
 */

#import "JPVideoPlayerCache.h"
#import "JPVideoPlayerCachePath.h"
#import "JPVideoPlayerCompat.h"
#import "JPVideoPlayerManager.h"
#import "JPVideoPlayerSupportUtils.h"

#include <sys/param.h>
#include <sys/mount.h>
#import <CommonCrypto/CommonDigest.h>
#import <pthread.h>

static const NSInteger kDefaultCacheMaxCacheAge = 60*60*24*7; // 1 week
static const NSInteger kDefaultCacheMaxSize = 1000*1000*1000; // 1 GB

@implementation JPVideoPlayerCacheConfiguration

- (instancetype)init{
    self = [super init];
    if (self) {
        _maxCacheAge =  kDefaultCacheMaxCacheAge;
        _maxCacheSize = kDefaultCacheMaxSize;
    }
    return self;
}

@end

@interface JPVideoPlayerCache()

@property (nonatomic, strong, nonnull) dispatch_queue_t ioQueue;

@property (nonatomic) pthread_mutex_t lock;

@property (nonatomic, strong) NSFileManager *fileManager;

@end

static NSString *kJPVideoPlayerVersion2CacheHasBeenClearedKey = @"com.newpan.version2.cache.clear.key.www";
@implementation JPVideoPlayerCache

- (instancetype)initWithCacheConfiguration:(JPVideoPlayerCacheConfiguration *_Nullable)cacheConfiguration {
    self = [super init];
    if (self) {
        // Create IO serial queue
        _ioQueue = dispatch_queue_create("com.NewPan.JPVideoPlayerCache", DISPATCH_QUEUE_SERIAL);
        pthread_mutexattr_t mutexattr;
        pthread_mutexattr_init(&mutexattr);
        pthread_mutexattr_settype(&mutexattr, PTHREAD_MUTEX_RECURSIVE);
        pthread_mutex_init(&_lock, &mutexattr);
        JPVideoPlayerCacheConfiguration *configuration = cacheConfiguration;
        if (!configuration) {
            configuration = [[JPVideoPlayerCacheConfiguration alloc] init];
        }
        _cacheConfiguration = configuration;
        _fileManager = [NSFileManager defaultManager];
        
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
    return [self initWithCacheConfiguration:nil];
}

+ (nonnull instancetype)sharedCache {
    static dispatch_once_t once;
    static id instance;
    dispatch_once(&once, ^{
        instance = [[self alloc] initWithCacheConfiguration:nil];
    });
    return instance;
}


#pragma mark - Query and Retrieve Options

- (void)diskVideoExistsWithKey:(NSString *)key
                    completion:(JPVideoPlayerCheckCacheCompletion)completion {
    dispatch_async(_ioQueue, ^{
        BOOL exists = [self.fileManager fileExistsAtPath:[JPVideoPlayerCachePath videoCachePathForKey:key]];
        if (completion) {
            JPDispatchSyncOnMainQueue(^{
                completion(exists); 
            });
        }
    });
}

- (void)queryCacheOperationForKey:(NSString *)key
                       completion:(JPVideoPlayerCacheQueryCompletion _Nullable)completion {
    if (!key) {
        if (completion) {
            JPDispatchSyncOnMainQueue(^{
                completion(nil, JPVideoPlayerCacheTypeNone);
            });
        }
        return;
    }
    
    dispatch_async(self.ioQueue, ^{
        @autoreleasepool {
            BOOL exists = [self.fileManager fileExistsAtPath:[JPVideoPlayerCachePath videoCachePathForKey:key]];
            if(!exists){
                if (completion) {
                    JPDispatchSyncOnMainQueue(^{
                        completion(nil, JPVideoPlayerCacheTypeNone);
                    });
                }
                return;
            }

            if (completion) {
                JPDispatchSyncOnMainQueue(^{
                    completion([JPVideoPlayerCachePath videoCachePathForKey:key], JPVideoPlayerCacheTypeExisted);
                });
            }
        }
    });
}

- (BOOL)diskVideoExistsOnPath:(NSString *)path {
    return [self.fileManager fileExistsAtPath:path];
}


#pragma mark - Clear Cache Events

- (void)removeVideoCacheForKey:(NSString *)key
                    completion:(dispatch_block_t _Nullable)completion {
    dispatch_async(self.ioQueue, ^{
        if ([self.fileManager fileExistsAtPath:[JPVideoPlayerCachePath videoCachePathForKey:key]]) {
            [self.fileManager removeItemAtPath:[JPVideoPlayerCachePath videoCachePathForKey:key] error:nil];
            [self.fileManager removeItemAtPath:[JPVideoPlayerCachePath videoCacheIndexFilePathForKey:key] error:nil];
            JPDispatchSyncOnMainQueue(^{
                if (completion) {
                    completion();
                }
            });
        }
    });
}

- (void)deleteOldFilesOnCompletion:(dispatch_block_t _Nullable)completion {
    dispatch_async(self.ioQueue, ^{
        NSURL *diskCacheURL = [NSURL fileURLWithPath:[JPVideoPlayerCachePath videoCachePath] isDirectory:YES];
        NSArray<NSString *> *resourceKeys = @[NSURLIsDirectoryKey, NSURLContentModificationDateKey, NSURLTotalFileAllocatedSizeKey];
        
        // This enumerator prefetches useful properties for our cache files.
        NSDirectoryEnumerator *fileEnumerator = [self.fileManager enumeratorAtURL:diskCacheURL
                                                   includingPropertiesForKeys:resourceKeys
                                                                      options:NSDirectoryEnumerationSkipsHiddenFiles
                                                                 errorHandler:NULL];
        
        NSDate *expirationDate = [NSDate dateWithTimeIntervalSinceNow:-self.cacheConfiguration.maxCacheAge];
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
            [self.fileManager removeItemAtURL:fileURL error:nil];
        }
        
        // If our remaining disk cache exceeds a configured maximum size, perform a second
        // size-based cleanup pass.  We delete the oldest files first.
        if (self.cacheConfiguration.maxCacheSize > 0 && currentCacheSize > self.cacheConfiguration.maxCacheSize) {
            // Target half of our maximum cache size for this cleanup pass.
            const NSUInteger desiredCacheSize = self.cacheConfiguration.maxCacheSize / 2;
            
            // Sort the remaining cache files by their last modification time (oldest first).
            NSArray<NSURL *> *sortedFiles = [cacheFiles keysSortedByValueWithOptions:NSSortConcurrent
                                                                     usingComparator:^NSComparisonResult(id obj1, id obj2) {
                                                                         return [obj1[NSURLContentModificationDateKey] compare:obj2[NSURLContentModificationDateKey]];
                                                                     }];
            
            // Delete files until we fall below our desired cache size.
            for (NSURL *fileURL in sortedFiles) {
                if ([self.fileManager removeItemAtURL:fileURL error:nil]) {
                    NSDictionary<NSString *, id> *resourceValues = cacheFiles[fileURL];
                    NSNumber *totalAllocatedSize = resourceValues[NSURLTotalFileAllocatedSizeKey];
                    currentCacheSize -= totalAllocatedSize.unsignedIntegerValue;
                    
                    if (currentCacheSize < desiredCacheSize) {
                        break;
                    }
                }
            }
        }
        if (completion) {
            JPDispatchSyncOnMainQueue(^{
                completion();
            });
        }
    });
}

- (void)clearDiskOnCompletion:(nullable dispatch_block_t)completion{
    dispatch_async(self.ioQueue, ^{
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
        [self.fileManager removeItemAtPath:[JPVideoPlayerCachePath videoCachePathForAllFullFile] error:nil];
        [self.fileManager removeItemAtPath:[JPVideoPlayerCachePath videoCachePathForAllTemporaryFile] error:nil];
#pragma clang diagnostic pop
        [self.fileManager removeItemAtPath:[JPVideoPlayerCachePath videoCachePath] error:nil];
        JPDispatchSyncOnMainQueue(^{
            if (completion) {
                completion();
            }
        });
    });
}

- (void)clearVideoCacheOnVersion2OnCompletion:(dispatch_block_t _Nullable)completion {
    BOOL version2CacheHasBeenCleared = [NSUserDefaults.standardUserDefaults boolForKey:kJPVideoPlayerVersion2CacheHasBeenClearedKey];
    if(version2CacheHasBeenCleared){
        if(completion){
           completion();
        }
        return;
    }
    [NSUserDefaults.standardUserDefaults setBool:YES forKey:kJPVideoPlayerVersion2CacheHasBeenClearedKey];
    [NSUserDefaults.standardUserDefaults synchronize];
    dispatch_async(self.ioQueue, ^{
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
        [self.fileManager removeItemAtPath:[JPVideoPlayerCachePath videoCachePathForAllFullFile] error:nil];
        [self.fileManager removeItemAtPath:[JPVideoPlayerCachePath videoCachePathForAllTemporaryFile] error:nil];
#pragma clang diagnostic pop
        JPDispatchSyncOnMainQueue(^{
            if (completion) {
                completion();
            }
        });
    });
}


#pragma mark - File Name

- (NSString *)cacheFileNameForKey:(NSString *)key{
    return [self cachedFileNameForKey:key];
}

- (NSString *)cachedFileNameForKey:(NSString *)key {
    NSParameterAssert(key);
    if(!key.length){
        return nil;
    }

    NSURL *url = [NSURL URLWithString:key];
    if(url){
        key = [url jp_cURLCommand];
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

- (unsigned long long)getSize {
    __block unsigned long long size = 0;
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
    NSString *tempFilePath = [JPVideoPlayerCachePath videoCachePathForAllTemporaryFile];
    NSString *fullFilePath = [JPVideoPlayerCachePath videoCachePathForAllFullFile];
#pragma clang diagnostic pop
    NSString *videoCachePath = [JPVideoPlayerCachePath videoCachePath];
    @autoreleasepool {
        NSDirectoryEnumerator *fileEnumerator_temp = [self.fileManager enumeratorAtPath:tempFilePath];
        for (NSString *fileName in fileEnumerator_temp) {
            NSString *filePath = [tempFilePath stringByAppendingPathComponent:fileName];
            NSDictionary<NSString *, id> *attrs = [[NSFileManager defaultManager] attributesOfItemAtPath:filePath error:nil];
            size += [attrs fileSize];
        }

        NSDirectoryEnumerator *fileEnumerator_full = [self.fileManager enumeratorAtPath:fullFilePath];
        for (NSString *fileName in fileEnumerator_full) {
            NSString *filePath = [fullFilePath stringByAppendingPathComponent:fileName];
            NSDictionary<NSString *, id> *attrs = [[NSFileManager defaultManager] attributesOfItemAtPath:filePath error:nil];
            size += [attrs fileSize];
        }

        NSDirectoryEnumerator *fileEnumerator_video = [self.fileManager enumeratorAtPath:videoCachePath];
        for (NSString *fileName in fileEnumerator_video) {
            NSString *filePath = [videoCachePath stringByAppendingPathComponent:fileName];
            NSDictionary<NSString *, id> *attrs = [[NSFileManager defaultManager] attributesOfItemAtPath:filePath error:nil];
            size += [attrs fileSize];
        }
    }
    return size;
}

- (NSUInteger)getDiskCount{
    __block NSUInteger count = 0;
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
    NSString *tempFilePath = [JPVideoPlayerCachePath videoCachePathForAllTemporaryFile];
    NSString *fullFilePath = [JPVideoPlayerCachePath videoCachePathForAllFullFile];
#pragma clang diagnostic pop
    NSString *videoCachePath = [JPVideoPlayerCachePath videoCachePath];

    NSDirectoryEnumerator *fileEnumerator_temp = [self.fileManager enumeratorAtPath:tempFilePath];
    count += fileEnumerator_temp.allObjects.count;
    NSDirectoryEnumerator *fileEnumerator_full = [self.fileManager enumeratorAtPath:fullFilePath];
    count += fileEnumerator_full.allObjects.count;
    NSDirectoryEnumerator *fileEnumerator_video = [self.fileManager enumeratorAtPath:videoCachePath];
    count += fileEnumerator_video.allObjects.count;
    return count;
}

- (void)calculateSizeOnCompletion:(JPVideoPlayerCalculateSizeCompletion _Nullable)completion {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
    NSString *tempFilePath = [JPVideoPlayerCachePath videoCachePathForAllTemporaryFile];
    NSString *fullFilePath = [JPVideoPlayerCachePath videoCachePathForAllFullFile];
#pragma clang diagnostic pop
    NSString *videoFilePath = [JPVideoPlayerCachePath videoCachePath];
    NSURL *diskCacheURL_temp = [NSURL fileURLWithPath:tempFilePath isDirectory:YES];
    NSURL *diskCacheURL_full = [NSURL fileURLWithPath:fullFilePath isDirectory:YES];
    NSURL *diskCacheURL_video = [NSURL fileURLWithPath:videoFilePath isDirectory:YES];
    
    dispatch_async(self.ioQueue, ^{
        NSUInteger fileCount = 0;
        NSUInteger totalSize = 0;
        
        NSDirectoryEnumerator *fileEnumerator_temp = [self.fileManager enumeratorAtURL:diskCacheURL_temp includingPropertiesForKeys:@[NSFileSize] options:NSDirectoryEnumerationSkipsHiddenFiles errorHandler:NULL];
        for (NSURL *fileURL in fileEnumerator_temp) {
            NSNumber *fileSize;
            [fileURL getResourceValue:&fileSize forKey:NSURLFileSizeKey error:NULL];
            totalSize += fileSize.unsignedIntegerValue;
            fileCount += 1;
        }

        NSDirectoryEnumerator *fileEnumerator_full = [self.fileManager enumeratorAtURL:diskCacheURL_full includingPropertiesForKeys:@[NSFileSize] options:NSDirectoryEnumerationSkipsHiddenFiles errorHandler:NULL];
        for (NSURL *fileURL in fileEnumerator_full) {
            NSNumber *fileSize;
            [fileURL getResourceValue:&fileSize forKey:NSURLFileSizeKey error:NULL];
            totalSize += fileSize.unsignedIntegerValue;
            fileCount += 1;
        }

        NSDirectoryEnumerator *fileEnumerator_video = [self.fileManager enumeratorAtURL:diskCacheURL_video includingPropertiesForKeys:@[NSFileSize] options:NSDirectoryEnumerationSkipsHiddenFiles errorHandler:NULL];
        for (NSURL *fileURL in fileEnumerator_video) {
            NSNumber *fileSize;
            [fileURL getResourceValue:&fileSize forKey:NSURLFileSizeKey error:NULL];
            totalSize += fileSize.unsignedIntegerValue;
            fileCount += 1;
        }
        
        if (completion) {
            JPDispatchSyncOnMainQueue(^{
                completion(fileCount, totalSize);
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
    [self deleteOldFilesOnCompletion:nil];
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
    [self deleteOldFilesOnCompletion:^{
        [application endBackgroundTask:bgTask];
        bgTask = UIBackgroundTaskInvalid;
    }];
}

@end

@implementation JPVideoPlayerCache(Deprecated)

- (void)removeFullCacheForKey:(NSString *)key
                   completion:(dispatch_block_t _Nullable)completion{
    dispatch_async(self.ioQueue, ^{
        if ([self.fileManager fileExistsAtPath:[JPVideoPlayerCachePath videoCacheFullPathForKey:key]]) {
            [self.fileManager removeItemAtPath:[JPVideoPlayerCachePath videoCacheFullPathForKey:key] error:nil];
            JPDispatchSyncOnMainQueue(^{
                if (completion) {
                    completion();
                }
            });
        }
    });
}

- (void)removeTempCacheForKey:(NSString *)key
                   completion:(nullable dispatch_block_t)completion{
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

- (void)deleteAllTempCacheOnCompletion:(nullable dispatch_block_t)completion{
    dispatch_async(self.ioQueue, ^{
        [self.fileManager removeItemAtPath:[JPVideoPlayerCachePath videoCachePathForAllTemporaryFile] error:nil];
        JPDispatchSyncOnMainQueue(^{
            if (completion) {
                completion();
            }
        });
    });
}

@end
