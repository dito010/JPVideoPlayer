//
//  JPWebServerAVPlayerResponse.m
//  Test
//
//  Created by NewPan on 2018/2/10.
//  Copyright © 2018年 NewPan. All rights reserved.
//

#import "JPWebServerAVPlayerResponse.h"
#import <sys/stat.h>
#import "JPWebServerPrivate.h"

#define kFileReadBufferSize (32 * 1024)

@interface JPWebServerAVPlayerResponse()

@property(nonatomic, assign) int file;

@property (nonatomic, strong) NSDictionary *overrides;

@end

@implementation JPWebServerAVPlayerResponse

@dynamic contentType, lastModifiedDate, eTag;

+ (instancetype)responseWithFile:(NSString *)path
                       byteRange:(NSRange)range
               mimeTypeOverrides:(nullable NSDictionary *)overrides {
    return [[self alloc] initWithFile:path
                            byteRange:range
                    mimeTypeOverrides:overrides];
}

- (instancetype)initWithFile:(NSString *)path
                   byteRange:(NSRange)range
           mimeTypeOverrides:(nullable NSDictionary *)overrides {
    NSAssert(path, @"The path can not be nil when initialise response.");
    if(!path.length){
        return nil;
    }

    if ((self = [super init])) {
        _path = [path copy];
        _overrides = overrides;
        if(![self internalSetPropertyValueWithFilePath:path
                                             byteRange:range
                                     mimeTypeOverrides:overrides]){
            return nil;
        }
    }
    return self;
}

- (void)updateResponseByteRange:(NSRange)range {
    [self internalSetPropertyValueWithFilePath:self.path
                                     byteRange:range
                             mimeTypeOverrides:self.overrides];
}

- (BOOL)open:(NSError**)error {
    _file = open([_path fileSystemRepresentation], O_NOFOLLOW | O_RDONLY);
    if (_file <= 0) {
        if (error) {
            *error = JPWebServerMakePosixError(errno);
        }
        return NO;
    }
    if (lseek(_file, _offset, SEEK_SET) != (off_t)_offset) {
        if (error) {
            *error = JPWebServerMakePosixError(errno);
        }
        close(_file);
        return NO;
    }
    return YES;
}

- (NSData*)readData:(NSError**)error {
    size_t length = MIN((NSUInteger)kFileReadBufferSize, _size);
    NSMutableData* data = [[NSMutableData alloc] initWithLength:length];
    ssize_t result = read(_file, data.mutableBytes, length);
    if (result < 0) {
        if (error) {
            *error = JPWebServerMakePosixError(errno);
        }
        return nil;
    }
    if (result > 0) {
        [data setLength:result];
        _size -= result;
    }
    return data;
}

- (void)close {
    close(_file);
}


#pragma mark - Private

- (BOOL)internalSetPropertyValueWithFilePath:(NSString *)path
                                   byteRange:(NSRange)range
                           mimeTypeOverrides:(nullable NSDictionary *)overrides {
    struct stat info;
    if (lstat([path fileSystemRepresentation], &info) || !(info.st_mode & S_IFREG)) {
        GWS_DNOT_REACHED();
        return NO;
    }
#ifndef __LP64__
    if (info.st_size >= (off_t)4294967295) {  // In 32 bit mode, we can't handle files greater than 4 GiBs (don't use "NSUIntegerMax" here to avoid potential unsigned to signed conversion issues)
        GWS_DNOT_REACHED();
        return NO;
    }
#endif

    BOOL hasByteRange = JPWebServerIsValidByteRange(range);
    NSUInteger fileSize = (NSUInteger)info.st_size;
    range = [self internalCheckRange:range fileSize:fileSize];
    if (range.length == 0) {
        return NO;  // TODO: Return 416 status code and "Content-Range: bytes */{file length}" header
    }
    _offset = range.location;
    _size = range.length;
    if (hasByteRange) {
        [self setStatusCode:kJPWebServerHTTPStatusCode_PartialContent];
        [self setValue:[NSString stringWithFormat:@"bytes %lu-%lu/%lu", (unsigned long)_offset, (unsigned long)(_offset + _size - 1), (unsigned long)fileSize] forAdditionalHeader:@"Content-Range"];
        GWS_LOG_DEBUG(@"Using content bytes range [%lu-%lu] for file \"%@\"", (unsigned long)_offset, (unsigned long)(_offset + _size - 1), path);
    }

    self.contentType = JPWebServerGetMimeTypeForExtension([_path pathExtension], overrides);
    self.contentLength = _size;
    self.lastModifiedDate = [self internalDateFromTimeSpec:&info.st_mtimespec];
    self.eTag = [NSString stringWithFormat:@"%llu/%li/%li", info.st_ino, info.st_mtimespec.tv_sec, info.st_mtimespec.tv_nsec];
    return YES;
}

- (NSDate *)internalDateFromTimeSpec:(const struct timespec*)t {
    return [NSDate dateWithTimeIntervalSince1970:((NSTimeInterval)t->tv_sec + (NSTimeInterval)t->tv_nsec / 1000000000.0)];
}

- (NSRange)internalCheckRange:(NSRange)range fileSize:(NSUInteger)fileSize {
    BOOL hasByteRange = JPWebServerIsValidByteRange(range);
    if (hasByteRange) {
        if (range.location != NSUIntegerMax) {
            range.location = MIN(range.location, fileSize);
            range.length = MIN(range.length, fileSize - range.location);
        }
        else {
            range.length = MIN(range.length, fileSize);
            range.location = fileSize - range.length;
        }
    }
    else {
        range.location = 0;
        range.length = fileSize;
    }
    return range;
}

- (NSString*)description {
    NSMutableString* description = [NSMutableString stringWithString:[super description]];
    [description appendFormat:@"\n\n{%@}", _path];
    return description;
}

@end
