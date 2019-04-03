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

#import "JPVideoPlayerCacheFile.h"
#import "JPVideoPlayerCompat.h"
#import "JPVideoPlayerSupportUtils.h"
#import "JPVideoPlayerCompat.h"
#import <pthread.h>

@interface JPVideoPlayerCacheFile()

@property (nonatomic, strong) NSMutableArray<NSValue *> *internalFragmentRanges;

@property (nonatomic, strong) NSFileHandle *writeFileHandle;

@property (nonatomic, strong) NSFileHandle *readFileHandle;

@property(nonatomic, assign) BOOL completed;

@property (nonatomic, assign) NSUInteger fileLength;

@property (nonatomic, assign) NSUInteger readOffset;

@property (nonatomic, copy) NSDictionary *responseHeaders;

@property(nonatomic, strong) dispatch_queue_t syncQueue;

@end

static const NSString *kJPVideoPlayerCacheFileZoneKey = @"com.newpan.zone.key.www";
static const NSString *kJPVideoPlayerCacheFileSizeKey = @"com.newpan.size.key.www";
static const NSString *kJPVideoPlayerCacheFileResponseHeadersKey = @"com.newpan.response.header.key.www";
@implementation JPVideoPlayerCacheFile

+ (instancetype)new {
    NSAssert(NO, @"Please use given initializer method");
    return nil;
}

- (instancetype)init {
    NSAssert(NO, @"Please use given initializer method");
    return nil;
}

+ (instancetype)cacheFileWithFilePath:(NSString *)filePath
                        indexFilePath:(NSString *)indexFilePath {
    return [[self alloc] initWithFilePath:filePath
                            indexFilePath:indexFilePath];
}

- (instancetype)initWithFilePath:(NSString *)filePath
                   indexFilePath:(NSString *)indexFilePath {
    if (!filePath.length || !indexFilePath.length) {
        JPErrorLog(@"filePath and indexFilePath can not be nil.");
        return nil;
    }

    self = [super init];
    if (self) {
        @autoreleasepool {
            _cacheFilePath = filePath;
            _indexFilePath = indexFilePath;
            _internalFragmentRanges = @[].mutableCopy;
            _readFileHandle = [NSFileHandle fileHandleForReadingAtPath:_cacheFilePath];
            _writeFileHandle = [NSFileHandle fileHandleForWritingAtPath:_cacheFilePath];

            _syncQueue = JPNewSyncQueue("com.jpvideoplayer.cachefile.sync.queue.www");

            NSString *indexStr = [NSString stringWithContentsOfFile:self.indexFilePath encoding:NSUTF8StringEncoding error:nil];
            NSData *data = [indexStr dataUsingEncoding:NSUTF8StringEncoding];
            NSDictionary *indexesDictionary = [NSJSONSerialization JSONObjectWithData:data
                                                                              options:NSJSONReadingMutableContainers | NSJSONReadingAllowFragments
                                                                                error:nil];
            if (!indexesDictionary) {
                [self truncateFileWithFileLength:0];
            }
            else {
                NSNumber *fileSize = indexesDictionary[kJPVideoPlayerCacheFileSizeKey];
                self.responseHeaders = indexesDictionary[kJPVideoPlayerCacheFileResponseHeadersKey];
                NSMutableArray<NSString *> *ranges = indexesDictionary[kJPVideoPlayerCacheFileZoneKey];
                if (fileSize) self.fileLength = [fileSize unsignedIntegerValue];

                NSRange range;
                for (NSString *rangeString in ranges) {
                    range = NSRangeFromString(rangeString);
                    [self.internalFragmentRanges addObject:[NSValue valueWithRange:range]];
                }
            }

            [self _checkHasCompleted];
        }
    }
    return self;
}

- (void)dealloc {
    [self.readFileHandle closeFile];
    [self.writeFileHandle closeFile];
}


#pragma mark - Properties

- (BOOL)isFileLengthValid {
    return self.fileLength > 0;
}

- (BOOL)hasCompleted {
    return self.completed;
}


#pragma mark - Range

- (NSArray<NSValue *> *)fragmentRanges {
    __block NSArray<NSValue *> *ranges = nil;
    JPDispatchSyncOnQueue(self.syncQueue, ^{
        ranges = self.internalFragmentRanges.copy;
    });
    return ranges;
}

- (void)mergeRangesIfNeed {
    JPDispatchSyncOnQueue(self.syncQueue, ^{

        BOOL hasMerge = NO;
        NSRange currentRange, nextRange;
        for (NSUInteger i = 0; i < self.internalFragmentRanges.count; ++i) {
            if ((i + 1) < self.internalFragmentRanges.count) {
                @autoreleasepool {
                    currentRange = [self.internalFragmentRanges[i] rangeValue];
                    nextRange = [self.internalFragmentRanges[i + 1] rangeValue];
                    if (JPRangeCanMerge(currentRange, nextRange)) {
                        [self.internalFragmentRanges removeObjectsAtIndexes:[NSIndexSet indexSetWithIndexesInRange:NSMakeRange(i, 2)]];
                        [self.internalFragmentRanges insertObject:[NSValue valueWithRange:NSUnionRange(currentRange, nextRange)] atIndex:i];
                        i -= 1;
                        hasMerge = YES;
                    }
                }
            }
        }
//        if(hasMerge){
//            NSString *string = @"";
//            NSRange range;
//            for(NSValue *rangeValue in self.internalFragmentRanges){
//                @autoreleasepool {
//                    range = [rangeValue rangeValue];
//                    string = [string stringByAppendingString:[NSString stringWithFormat:@"%@; ", NSStringFromRange(range)]];
//                }
//            }
//            JPDebugLog(@"合并后已缓存区间: %@", string);
//        }

    });
}

- (NSRange)cachedRangeForRange:(NSRange)range {
    return NSIntersectionRange([self cachedRangeContainsPosition:range.location], range);
}

- (NSRange)cachedRangeContainsPosition:(NSUInteger)position {
    __block NSRange result;
    JPDispatchSyncOnQueue(self.syncQueue, ^{

        if (position >= self.fileLength) {
            result = JPInvalidRange;
        }
        else {
            for (int i = 0; i < self.internalFragmentRanges.count; ++i) {
                NSRange range = [self.internalFragmentRanges[i] rangeValue];
                if (NSLocationInRange(position, range)) {
                    return range;
                }
            }
            if (!lock) {
                pthread_mutex_unlock(&_lock);
            }
            return JPInvalidRange;
        }

    });
    return result;
}

- (NSRange)firstNotCachedRangeFromPosition:(NSUInteger)position {
    if (position >= self.fileLength) return JPInvalidRange;

    int lock = pthread_mutex_trylock(&_lock);
    NSRange targetRange = JPInvalidRange;
    NSUInteger start = position;
    NSRange range;
    /// internalFragmentRanges 增序排列.
    for (NSUInteger i = 0; i < self.internalFragmentRanges.count; ++i) {
        @autoreleasepool {
            range = [self.internalFragmentRanges[i] rangeValue];
            /// * 代表区间, + 代表 position.
            /// ----- * ------ + ------ * -----
            /// 当前区间已缓存完成.
            if (NSLocationInRange(start, range)) {
                start = NSMaxRange(range);
                continue;
            }

            /// 在当前区间之后.
            /// ----- * ------ * ----- + -----
            if (start >= NSMaxRange(range)) continue;

            /// 在当前区间之前, 就是目标
            /// ---- + ------ * ------ * -------
            targetRange = NSMakeRange(start, range.location - start);
            break;
        }
    }

    ///
    if (!JPValidByteRange(targetRange) && start < self.fileLength) {
        targetRange = NSMakeRange(start, self.fileLength - start);
    }
    if (!lock) {
        pthread_mutex_unlock(&_lock);
    }
    return targetRange;
}


#pragma mark - File

- (BOOL)truncateFileWithFileLength:(NSUInteger)fileLength {
    NSParameterAssert(self.writeFileHandle);
    if (!self.writeFileHandle) return NO;

    JPDebugLog(@"Truncate file to length: %u", fileLength);
    self.fileLength = fileLength;
    @try {
        [self.writeFileHandle truncateFileAtOffset:self.fileLength * sizeof(Byte)];
        unsigned long long end = [self.writeFileHandle seekToEndOfFile];
        if (end != self.fileLength) return NO;
    }
    @catch (NSException * e) {
        JPErrorLog(@"Truncate file raise a exception: %@", e);
        return NO;
    }
    return YES;
}

- (void)removeCache {
    [[NSFileManager defaultManager] removeItemAtPath:self.cacheFilePath error:NULL];
    [[NSFileManager defaultManager] removeItemAtPath:self.indexFilePath error:NULL];
}

- (BOOL)storeResponse:(NSHTTPURLResponse *)response {
    BOOL success = YES;
    if (![self isFileLengthValid]) {
        success = [self truncateFileWithFileLength:(NSUInteger)response.jp_fileLength];
    }
    self.responseHeaders = [[response allHeaderFields] copy];
    success = success && [self synchronize];
    return success;
}

- (void)storeVideoData:(NSData *)data
              atOffset:(NSUInteger)offset
           synchronize:(BOOL)synchronize
      storedCompletion:(dispatch_block_t)completion {
    if (!self.writeFileHandle) {
        JPErrorLog(@"self.writeFileHandle is nil");
    }
    @try {
        [self.writeFileHandle seekToFileOffset:offset];
        [self.writeFileHandle jp_safeWriteData:data];
    }
    @catch (NSException * e) {
        JPErrorLog(@"Write file raise a exception: %@", e);
    }

    [self _addRange:NSMaxRange(offset, data.length)];
    if (synchronize) {
        [self synchronize];
    }
}


#pragma mark - read data

- (NSData *)dataWithRange:(NSRange)range {
    if (!JPValidFileRange(range)) {
        return nil;
    }

    if (self.readOffset != range.location) {
        [self seekToPosition:range.location];
    }

    return [self readDataWithLength:range.length];
}

- (NSData *)readDataWithLength:(NSUInteger)length {
    NSRange range = [self cachedRangeForRange:NSMakeRange(self.readOffset, length)];
    if (JPValidFileRange(range)) {
        int lock = pthread_mutex_trylock(&_lock);
        NSData *data = [self.readFileHandle readDataOfLength:range.length];
        self.readOffset += [data length];
        if (!lock) {
            pthread_mutex_unlock(&_lock);
        }
        return data;
    }
    return nil;
}


#pragma mark - seek

- (void)seekToPosition:(NSUInteger)position {
    int lock = pthread_mutex_trylock(&_lock);
    [self.readFileHandle seekToFileOffset:position];
    self.readOffset = (NSUInteger)self.readFileHandle.offsetInFile;
    if (!lock) {
        pthread_mutex_unlock(&_lock);
    }
}

- (void)seekToEnd {
    int lock = pthread_mutex_trylock(&_lock);
    [self.readFileHandle seekToEndOfFile];
    self.readOffset = (NSUInteger)self.readFileHandle.offsetInFile;
    if (!lock) {
        pthread_mutex_unlock(&_lock);
    }
}


#pragma mark - Indexes

- (NSString *)unserializeIndex {
    int lock = pthread_mutex_trylock(&_lock);

    NSMutableDictionary *dict = [@{
            kJPVideoPlayerCacheFileSizeKey: @(self.fileLength),
    } mutableCopy];

    NSMutableArray *rangeArray = [[NSMutableArray alloc] init];
    for (NSValue *range in self.internalFragmentRanges) {
        [rangeArray addObject:NSStringFromRange([range rangeValue])];
    }
    if(rangeArray.count){
        dict[kJPVideoPlayerCacheFileZoneKey] = rangeArray;
    }

    JPDebugLog(@"存储字典: %@", dict);

    if (self.responseHeaders) {
        dict[kJPVideoPlayerCacheFileResponseHeadersKey] = self.responseHeaders;
    }

    NSData *data = [NSJSONSerialization dataWithJSONObject:dict options:0 error:nil];
    if (data) {
        NSString *dataString = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
        if (!lock) {
            pthread_mutex_unlock(&_lock);
        }
        return dataString;
    }
    if (!lock) {
        pthread_mutex_unlock(&_lock);
    }
    return nil;
}

- (BOOL)synchronize {
    NSString *indexString = [self unserializeIndex];
    int lock = pthread_mutex_trylock(&_lock);
    JPDebugLog(@"Did synchronize index file");
    [self.writeFileHandle synchronizeFile];
    BOOL synchronize = [indexString writeToFile:self.indexFilePath atomically:YES encoding:NSUTF8StringEncoding error:NULL];
    if (!lock) {
        pthread_mutex_unlock(&_lock);
    }
    return synchronize;
}


#pragma mark - Private

- (void)_addRange:(NSRange)range {
    NSParameterAssert(NSMaxRange(range) <= self.fileLength);
    if (NSMaxRange(range) > self.fileLength) return;

    [self.internalFragmentRanges addObject:[NSValue valueWithRange:range]];
    [self.internalFragmentRanges sortUsingComparator:^NSComparisonResult(NSValue *obj1, NSValue *obj2) {
        return obj1.rangeValue.location > obj2.rangeValue.location ? NSOrderedAscending : NSOrderedDescending;
    }];
    [self mergeRangesIfNeed];
    [self _checkHasCompleted];
}

- (void)_checkHasCompleted {
    self.completed = NO;
    if (self.internalFragmentRanges.count == 1) {
        NSRange range = [self.internalFragmentRanges.firstObject rangeValue];
        if (range.location == 0 && (range.length == self.fileLength)) {
            self.completed = YES;
        }
    }
}

@end
