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

@implementation JPLog

+ (void)initialize {
    _logLevel = JPLogLevelError;
}

+ (void)logWithFlag:(JPLogLevel)flag
               file:(const char *)file
           function:(const char *)function
               line:(NSUInteger)line
             format:(NSString *)format, ... {
    if (flag > _logLevel) {
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
        NSString *fileName = [NSString stringWithCString:file encoding:NSUTF8StringEncoding];
        if (fileName.length && [fileName containsString:@"/"]) {
            tempString = [tempString stringByAppendingString:[fileName componentsSeparatedByString:@"/"].lastObject];
            tempString = [tempString stringByAppendingString:@"-"];
        }
        
        NSString *functionName = [NSString stringWithCString:function encoding:NSUTF8StringEncoding];
        if (functionName.length && ([functionName containsString:@"-"] || [functionName containsString:@"+"])) {
            tempString = [tempString stringByAppendingString:[functionName stringByTrimmingCharactersInSet:[NSCharacterSet characterSetWithCharactersInString:@"- :+"]]];
        }
        
        message = [NSString stringWithFormat:@"%@-%ld: %@", tempString, line, message];
    }
    NSLog(@"%@", message);
}


@end
