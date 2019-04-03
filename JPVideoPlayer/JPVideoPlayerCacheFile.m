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

- (void)dealloc {
    [self.readFileHandle closeFile];
    [self.writeFileHandle closeFile];
}

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
                [self _truncateFileToLength:0];
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


#pragma mark - Properties

- (BOOL)isFileLengthValid {
    __block BOOL valid = NO;
    JPDispatchSyncOnQueue(self.syncQueue, ^{
        valid = self.fileLength > 0;
    });
    return valid;
}

- (BOOL)hasCompleted {
    __block BOOL completed = NO;
    JPDispatchSyncOnQueue(self.syncQueue, ^{
        completed = self.completed;
    });
    return completed;
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

        if (position < self.fileLength) {
            NSRange range;
            for (int i = 0; i < self.internalFragmentRanges.count; ++i) {
                range = [self.internalFragmentRanges[i] rangeValue];
                if (NSLocationInRange(position, range)) {
                    result = range;
                    break;
                }
            }
        }

    });
    return result;
}

- (NSRange)firstNotCachedRangeFromPosition:(NSUInteger)position {
   __block  NSRange result = JPInvalidRange;
    JPDispatchSyncOnQueue(self.syncQueue, ^{

        if (position < self.fileLength) {
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
                    if (start > NSMaxRange(range)) continue;

                    /// 在当前区间之前, 就是目标
                    /// ---- + ------ * ------ * -------
                    result = NSMakeRange(start, range.location - start);
                    break;
                }
            }

            /// 没找到合适的区间, 那就是文件还没开始下载.
            if (!JPValidByteRange(result) && start < self.fileLength) {
                result = NSMakeRange(start, self.fileLength - start);
            }
        }

    });

    return result;
}


#pragma mark - File

- (void)removeCache {
    JPDispatchSyncOnQueue(self.syncQueue, ^{
        [[NSFileManager defaultManager] removeItemAtPath:self.cacheFilePath error:NULL];
        [[NSFileManager defaultManager] removeItemAtPath:self.indexFilePath error:NULL];
    });
}

- (BOOL)storeResponse:(NSHTTPURLResponse *)response {
    __block BOOL success = YES;
    JPDispatchSyncOnQueue(self.syncQueue, ^{

        if (![self isFileLengthValid]) {
            success = [self _truncateFileToLength:(NSUInteger)response.jp_fileLength];
        }
        self.responseHeaders = [[response allHeaderFields] copy];
        success = success && [self synchronize];

    });
    return success;
}

- (void)storeVideoData:(NSData *)data
              atOffset:(NSUInteger)offset
           synchronize:(BOOL)synchronize
      storedCompletion:(dispatch_block_t)completion {
    JPDispatchSyncOnQueue(self.syncQueue, ^{

        if (!self.writeFileHandle) JPErrorLog(@"self.writeFileHandle is nil");

        @try {
            [self.writeFileHandle seekToFileOffset:offset];
            [self.writeFileHandle jp_safeWriteData:data];
        }
        @catch (NSException * e) {
            JPErrorLog(@"Write file raise a exception: %@", e);
        }

        [self _addRange:NSMakeRange(offset, data.length)];
        if (synchronize) {
            [self synchronize];
        }

        if (completion) JPDispatchAsyncOnMainQueue(completion);

    });
}


#pragma mark - read data

- (NSData *)dataWithRange:(NSRange)range {
    if (!JPValidFileRange(range)) return nil;

    __block NSData *data = nil;
    JPDispatchSyncOnQueue(self.syncQueue, ^{

        if (self.readOffset != range.location) [self seekToPosition:range.location];
        data = [self readDataWithLength:range.length];

    });
    return data;
}

- (NSData *)readDataWithLength:(NSUInteger)length {
    __block NSData *data = nil;
    JPDispatchSyncOnQueue(self.syncQueue, ^{
        NSRange range = [self cachedRangeForRange:NSMakeRange(self.readOffset, length)];
        if (JPValidFileRange(range)) {
            data = [self.readFileHandle readDataOfLength:range.length];
            self.readOffset += [data length];
        }
    });
    return data;
}


#pragma mark - seek

- (void)seekToPosition:(NSUInteger)position {
    JPDispatchSyncOnQueue(self.syncQueue, ^{

        [self.readFileHandle seekToFileOffset:position];
        self.readOffset = (NSUInteger)self.readFileHandle.offsetInFile;

    });
}

- (void)seekToEnd {
    JPDispatchSyncOnQueue(self.syncQueue, ^{

        [self.readFileHandle seekToEndOfFile];
        self.readOffset = (NSUInteger)self.readFileHandle.offsetInFile;

    });
}


#pragma mark - Indexes

- (BOOL)synchronize {
    __block BOOL synchronize = NO;
    JPDispatchSyncOnQueue(self.syncQueue, ^{

        NSString *indexString = [self _unserializeIndex];
        if (indexString.length) {
            JPDebugLog(@"同步文件索引文件到磁盘: %@", indexString);
            synchronize = [indexString writeToFile:self.indexFilePath atomically:YES encoding:NSUTF8StringEncoding error:NULL];
            [self.writeFileHandle synchronizeFile];
        }

    });
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

- (BOOL)_truncateFileToLength:(NSUInteger)fileLength {
    __block BOOL result = NO;
    JPDispatchSyncOnQueue(self.syncQueue, ^{

        NSParameterAssert(self.writeFileHandle);
        if (self.writeFileHandle) {
            JPDebugLog(@"Truncate file to length: %u", fileLength);
            self.fileLength = fileLength;
            @try {
                [self.writeFileHandle truncateFileAtOffset:self.fileLength * sizeof(Byte)];
                [self.writeFileHandle seekToEndOfFile];
            }
            @catch (NSException * e) {
                JPErrorLog(@"Truncate file raise a exception: %@", e);
            }
            result = YES;
        }

    });
    return result;
}

- (NSString *)_unserializeIndex {
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

    if (self.responseHeaders) {
        dict[kJPVideoPlayerCacheFileResponseHeadersKey] = self.responseHeaders;
    }
    return [[NSString alloc] initWithData:[NSJSONSerialization dataWithJSONObject:dict options:0 error:nil] encoding:NSUTF8StringEncoding];
}

@end
