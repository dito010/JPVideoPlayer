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
const NSRange JPInvalidRange = {NSNotFound, 0};

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