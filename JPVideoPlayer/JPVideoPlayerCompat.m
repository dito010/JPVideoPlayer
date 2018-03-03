//
//  JPVideoPlayerCompat.m
//  JPVideoPlayerDemo
//
//  Created by 尹久盼 on 2017/12/6.
//  Copyright © 2017年 NewPan. All rights reserved.
//

#import "JPVideoPlayerCompat.h"
#import <AVFoundation/AVFoundation.h>

NSString *const JPVideoPlayerDownloadStartNotification = @"www.jpvideplayer.download.start.notification";
NSString *const JPVideoPlayerDownloadReceiveResponseNotification = @"www.jpvideoplayer.download.received.response.notification";
NSString *const JPVideoPlayerDownloadStopNotification = @"www.jpvideplayer.download.stop.notification";
NSString *const JPVideoPlayerDownloadFinishNotification = @"www.jpvideplayer.download.finished.notification";
NSString *const JPVideoPlayerErrorDomain = @"com.jpvideoplayer.error.domain.www";
const NSRange JPInvalidRange = {NSNotFound,0};

void JPDispatchSyncOnMainQueue(dispatch_block_t block) {
    if (!block) { return; }
    if (strcmp(dispatch_queue_get_label(DISPATCH_CURRENT_QUEUE_LABEL), dispatch_queue_get_label(dispatch_get_main_queue())) == 0) {
        block();
    }
    else {
        dispatch_sync(dispatch_get_main_queue(), block);
    }
}

BOOL JPValidByteRange(NSRange range) {
    return ((range.location != NSNotFound) || (range.length > 0));
}

BOOL JPValidFileRange(NSRange range) {
    return ((range.location != NSNotFound) && range.length > 0 && range.length != NSUIntegerMax);
}

BOOL JPRangeCanMerge(NSRange range1, NSRange range2) {
    return (NSMaxRange(range1) == range2.location) || (NSMaxRange(range2) == range1.location) || NSIntersectionRange(range1, range2).length > 0;
}

NSString* JPRangeToHTTPRangeHeader(NSRange range) {
    if (JPValidByteRange(range)) {
        if (range.location == NSNotFound) {
            return [NSString stringWithFormat:@"bytes=-%tu",range.length];
        }
        else if (range.length == NSUIntegerMax) {
            return [NSString stringWithFormat:@"bytes=%tu-",range.location];
        }
        else {
            return [NSString stringWithFormat:@"bytes=%tu-%tu",range.location, NSMaxRange(range) - 1];
        }
    }
    else {
        return nil;
    }
}

NSString* JPRangeToHTTPRangeReponseHeader(NSRange range, NSUInteger length) {
    if (JPValidByteRange(range)) {
        NSUInteger start = range.location;
        NSUInteger end = NSMaxRange(range) - 1;
        if (range.location == NSNotFound) {
            start = range.location;
        }
        else if (range.length == NSUIntegerMax) {
            start = length - range.length;
            end = start + range.length - 1;
        }
        return [NSString stringWithFormat:@"bytes %tu-%tu/%tu",start,end,length];
    }
    else {
        return nil;
    }
}

@implementation JPLog

+ (void)initialize {
    _logLevel = JPLogLevelDebug;
}

+ (void)logWithFlag:(JPLogLevel)logLevel
               file:(const char *)file
           function:(const char *)function
               line:(NSUInteger)line
             format:(NSString *)format, ... {
    if (logLevel > _logLevel) {
        return;
    }
    if (!format) {
        return;
    }

    
    va_list args;
    va_start(args, format);
    
    NSString *message = [[NSString alloc] initWithFormat:format arguments:args];
    va_end(args);
    
    if (message.length) {
        NSString *tempString = [[NSString stringWithCString:file encoding:NSUTF8StringEncoding].lastPathComponent
                componentsSeparatedByString:@"."].firstObject;
        NSString *flag;
        switch (logLevel) {
            case JPLogLevelDebug:
                flag = @"DEBUG";
                break;

            case JPLogLevelWarning:
                flag = @"Waring";
                break;

            case JPLogLevelError:
                flag = @"Error";
                break;
                
            default:
                break;
        }

        NSString *threadName = [[NSThread currentThread] description];
        threadName = [threadName componentsSeparatedByString:@">"].lastObject;
        threadName = [threadName componentsSeparatedByString:@","].firstObject;
        threadName = [threadName stringByReplacingOccurrencesOfString:@"{number = " withString:@""];
        // message = [NSString stringWithFormat:@"[%@] [Thread: %@] %@ => [%@ + %ld]", flag, threadName, message, tempString, line];
        message = [NSString stringWithFormat:@"[%@] [Thread: %0ld] %@", flag, (long)[threadName integerValue], message];
        printf("%s\n", message.UTF8String);
    }
}

@end
