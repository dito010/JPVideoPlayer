//
//  JPVideoPlayerCacheFile.m
//  JPVideoPlayerDemo
//
//  Created by 尹久盼 on 2018/1/1.
//  Copyright © 2018年 NewPan. All rights reserved.
//

#import "JPVideoPlayerCacheFile.h"
#import "JPVideoPlayerCompat.h"
#import "JPVideoPlayerSupportUtils.h"
#import "JPVideoPlayerCompat.h"
#import <pthread.h>

@interface JPVideoPlayerCacheFile()

@property (nonatomic, strong) NSMutableArray<NSValue *> *ranges;

@property (nonatomic, strong) NSFileHandle *writeFileHandle;

@property (nonatomic, strong) NSFileHandle *readFileHandle;

@property(nonatomic, assign) BOOL compelete;

@property (nonatomic, assign) NSUInteger fileLength;

@property (nonatomic, assign) NSUInteger readOffset;

@property (nonatomic, copy) NSDictionary *responseHeaders;

@property (nonatomic) pthread_mutex_t lock;

@end

static const NSString *kJPVideoPlayerCacheFileZoneKey = @"com.newpan.zone.key.www";
static const NSString *kJPVideoPlayerCacheFileSizeKey = @"com.newpan.size.key.www";
static const NSString *kJPVideoPlayerCacheFileResponseHeadersKey = @"com.newpan.response.header.key.www";
@implementation JPVideoPlayerCacheFile

+ (instancetype)cacheFileWithFilePath:(NSString *)filePath
                        indexFilePath:(NSString *)indexFilePath {
    return [[self alloc] initWithFilePath:filePath
                            indexFilePath:indexFilePath];
}

- (instancetype)init {
    NSAssert(NO, @"Please use given initializer method");
    return [self initWithFilePath:@"" indexFilePath:@""];
}

- (instancetype)initWithFilePath:(NSString *)filePath
                   indexFilePath:(NSString *)indexFilePath {
    NSParameterAssert(filePath.length && indexFilePath.length);
    if (!filePath.length || !indexFilePath.length) {
        return nil;
    }

    self = [super init];
    if (self) {
        _cacheFilePath = filePath;
        _indexFilePath = indexFilePath;
        _ranges = [[NSMutableArray alloc] init];
        _readFileHandle = [NSFileHandle fileHandleForReadingAtPath:_cacheFilePath];
        _writeFileHandle = [NSFileHandle fileHandleForWritingAtPath:_cacheFilePath];
        pthread_mutexattr_t mutexattr;
        pthread_mutexattr_init(&mutexattr);
        pthread_mutexattr_settype(&mutexattr, PTHREAD_MUTEX_RECURSIVE);
        pthread_mutex_init(&_lock, &mutexattr);

        NSString *indexStr = [NSString stringWithContentsOfFile:self.indexFilePath encoding:NSUTF8StringEncoding error:nil];
        NSData *data = [indexStr dataUsingEncoding:NSUTF8StringEncoding];
        NSDictionary *indexDictionary = [NSJSONSerialization JSONObjectWithData:data
                                                                 options:NSJSONReadingMutableContainers | NSJSONReadingAllowFragments
                                                                   error:nil];
        if (![self serializeIndex:indexDictionary]) {
            [self truncateFileWithFileLength:0];
        }

        [self checkCompelete];
    }
    return self;
}

- (void)dealloc {
    [self.readFileHandle closeFile];
    [self.writeFileHandle closeFile];
    pthread_mutex_destroy(&_lock);
}


#pragma mark - Properties

- (NSUInteger)cachedDataBound {
    if (self.ranges.count > 0) {
        NSRange range = [[self.ranges lastObject] rangeValue];
        return NSMaxRange(range);
    }
    return 0;
}

- (BOOL)isFileLengthValid {
    return self.fileLength != 0;
}

- (BOOL)isCompeleted {
    return self.compelete;
}

- (BOOL)isEOF {
    if (self.readOffset + 1 >= self.fileLength) {
        return YES;
    }
    return NO;
}


#pragma mark - Range

- (void)mergeRangesIfNeed {
    int lock = pthread_mutex_trylock(&_lock);
    for (int i = 0; i < self.ranges.count; ++i) {
        if ((i + 1) < self.ranges.count) {
            NSRange currentRange = [self.ranges[i] rangeValue];
            NSRange nextRange = [self.ranges[i + 1] rangeValue];
            if (JPRangeCanMerge(currentRange, nextRange)) {
                [self.ranges removeObjectsAtIndexes:[NSIndexSet indexSetWithIndexesInRange:NSMakeRange(i, 2)]];
                [self.ranges insertObject:[NSValue valueWithRange:NSUnionRange(currentRange, nextRange)] atIndex:i];
                i -= 1;
            }
        }
    }
    if (!lock) {
        pthread_mutex_unlock(&_lock);
    }
}

- (void)addRange:(NSRange)range {
    if (range.length == 0 || range.location >= self.fileLength) {
        return;
    }

    int lock = pthread_mutex_trylock(&_lock);
    BOOL inserted = NO;
    for (int i = 0; i < self.ranges.count; ++i) {
        NSRange currentRange = [self.ranges[i] rangeValue];
        if (currentRange.location >= range.location) {
            [self.ranges insertObject:[NSValue valueWithRange:range] atIndex:i];
            inserted = YES;
            break;
        }
    }
    if (!inserted) {
        [self.ranges addObject:[NSValue valueWithRange:range]];
    }
    if (!lock) {
        pthread_mutex_unlock(&_lock);
    }
    [self mergeRangesIfNeed];
    [self checkCompelete];
}

- (NSRange)cachedRangeForRange:(NSRange)range {
    NSRange cachedRange = [self cachedRangeContainsPosition:range.location];
    NSRange ret = NSIntersectionRange(cachedRange, range);
    if (ret.length > 0) {
        return ret;
    }
    else {
        return JPInvalidRange;
    }
}

- (NSRange)cachedRangeContainsPosition:(NSUInteger)position {
    if (position >= self.fileLength) {
        return JPInvalidRange;
    }

    int lock = pthread_mutex_trylock(&_lock);
    for (int i = 0; i < self.ranges.count; ++i) {
        NSRange range = [self.ranges[i] rangeValue];
        if (NSLocationInRange(position, range)) {
            return range;
        }
    }
    if (!lock) {
        pthread_mutex_unlock(&_lock);
    }
    return JPInvalidRange;
}

- (NSRange)firstNotCachedRangeFromPosition:(NSUInteger)position {
    if (position >= self.fileLength) {
        return JPInvalidRange;
    }

    int lock = pthread_mutex_trylock(&_lock);
    NSRange targerRange = JPInvalidRange;
    NSUInteger start = position;
    for (int i = 0; i < self.ranges.count; ++i) {
        NSRange range = [self.ranges[i] rangeValue];
        if (NSLocationInRange(start, range)) {
            start = NSMaxRange(range);
        }
        else {
            if (start >= NSMaxRange(range)) {
                continue;
            }
            else {
                targerRange = NSMakeRange(start, range.location - start);
            }
        }
    }

    if (start < self.fileLength) {
        targerRange = NSMakeRange(start, self.fileLength - start);
    }
    if (!lock) {
        pthread_mutex_unlock(&_lock);
    }
    return targerRange;
}

- (void)checkCompelete {
    int lock = pthread_mutex_trylock(&_lock);
    self.compelete = NO;
    if (self.ranges && self.ranges.count == 1) {
        NSRange range = [self.ranges[0] rangeValue];
        if (range.location == 0 && (range.length == self.fileLength)) {
            self.compelete = YES;
        }
    }
    if (!lock) {
        pthread_mutex_unlock(&_lock);
    }
}


#pragma mark - File

- (BOOL)truncateFileWithFileLength:(NSUInteger)fileLength {
    JPDebugLog(@"Truncate file to length: %u", fileLength);
    if (!self.writeFileHandle) {
        return NO;
    }

    int lock = pthread_mutex_trylock(&_lock);
    self.fileLength = fileLength;
    @try {
        [self.writeFileHandle truncateFileAtOffset:self.fileLength * sizeof(Byte)];
        unsigned long long end = [self.writeFileHandle seekToEndOfFile];
        if (end != self.fileLength) {
            if (!lock) {
                pthread_mutex_unlock(&_lock);
            }
            return NO;
        }
    }
    @catch (NSException * e) {
        // TODO: 处理异常.
        JPErrorLog(@"Truncate file raise a exception: %@", e);
        if (!lock) {
            pthread_mutex_unlock(&_lock);
        }
        return NO;
    }
    if (!lock) {
        pthread_mutex_unlock(&_lock);
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
        success = [self truncateFileWithFileLength:response.jp_fileLength];
    }
    self.responseHeaders = [[response allHeaderFields] copy];
    success = success && [self synchronize];
    return success;
}

- (BOOL)storeVideoData:(NSData *)data
              atOffset:(NSUInteger)offset
           synchronize:(BOOL)synchronize {
    if (!self.writeFileHandle) {
        return NO;
    }
    @try {
        [self.writeFileHandle seekToFileOffset:offset];
        [self.writeFileHandle jp_safeWriteData:data];
    }
    @catch (NSException * e) {
        // TODO: 处理异常.
        JPErrorLog(@"Write file raise a exception: %@", e);
        return NO;
    }

    [self addRange:NSMakeRange(offset, [data length])];
    if (synchronize) {
        [self synchronize];
    }
    return YES;
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


#pragma mark - Index

- (BOOL)serializeIndex:(NSDictionary *)indexDictionary {
    if (![indexDictionary isKindOfClass:[NSDictionary class]]) {
        return NO;
    }

    int lock = pthread_mutex_trylock(&_lock);
    NSNumber *fileSize = indexDictionary[kJPVideoPlayerCacheFileSizeKey];
    if (fileSize && [fileSize isKindOfClass:[NSNumber class]]) {
        self.fileLength = [fileSize unsignedIntegerValue];
    }

    if (self.fileLength == 0) {
        if (!lock) {
            pthread_mutex_unlock(&_lock);
        }
        return NO;
    }

    [self.ranges removeAllObjects];
    NSMutableArray *rangeArray = indexDictionary[kJPVideoPlayerCacheFileZoneKey];
    for (NSString *rangeStr in rangeArray) {
        NSRange range = NSRangeFromString(rangeStr);
        [self.ranges addObject:[NSValue valueWithRange:range]];
    }
    self.responseHeaders = indexDictionary[kJPVideoPlayerCacheFileResponseHeadersKey];
    if (!lock) {
        pthread_mutex_unlock(&_lock);
    }
    return YES;
}

- (NSString *)unserializeIndex {
    int lock = pthread_mutex_trylock(&_lock);
    NSMutableArray *rangeArray = [[NSMutableArray alloc] init];
    for (NSValue *range in self.ranges) {
        [rangeArray addObject:NSStringFromRange([range rangeValue])];
    }
    NSMutableDictionary *dict = [@{
            kJPVideoPlayerCacheFileSizeKey: @(self.fileLength),
            kJPVideoPlayerCacheFileZoneKey: rangeArray
    } mutableCopy];

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

@end
