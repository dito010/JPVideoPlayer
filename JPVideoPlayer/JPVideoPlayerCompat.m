//
//  JPVideoPlayerCompat.m
//  JPVideoPlayerDemo
//
//  Created by 尹久盼 on 2017/12/6.
//  Copyright © 2017年 NewPan. All rights reserved.
//

#import "JPVideoPlayerCompat.h"

NSString *const JPVideoPlayerDownloadStartNotification = @"www.jpvideplayer.download.start.notification";
NSString *const JPVideoPlayerDownloadReceiveResponseNotification = @"www.jpvideoplayer.download.received.response.notification";
NSString *const JPVideoPlayerDownloadStopNotification = @"www.jpvideplayer.download.stop.notification";
NSString *const JPVideoPlayerDownloadFinishNotification = @"www.jpvideplayer.download.finished.notification";

NSString *const JPVideoPlayerErrorDomain = @"com.jpvideoplayer.error.domain.www";

void JPDispatchSyncOnMainQueue(dispatch_block_t block) {
    if (!block) { return; }
    if (strcmp(dispatch_queue_get_label(DISPATCH_CURRENT_QUEUE_LABEL), dispatch_queue_get_label(dispatch_get_main_queue())) == 0) {
        block();
    }
    else {
        dispatch_sync(dispatch_get_main_queue(), block);
    }
}

@implementation JPLog
+ (void)initialize {
    _logLevel = JPLogLevelError;
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
        NSString *tempString = @"";
        NSString *functionName = [NSString stringWithCString:function encoding:NSUTF8StringEncoding];
        if (functionName.length && ([functionName containsString:@"-"] || [functionName containsString:@"+"])) {
            tempString = [tempString stringByAppendingString:[functionName stringByTrimmingCharactersInSet:[NSCharacterSet characterSetWithCharactersInString:@"- :+"]]];
        }

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
        message = [NSString stringWithFormat:@"[%@] %@ [Line %ld] => %@", flag, tempString, line, message];
        printf("%s\n", message.UTF8String);
    }
}


@end
