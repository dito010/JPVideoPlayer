//
// Created by NewPan on 2018/2/20.
// Copyright (c) 2018 NewPan. All rights reserved.
//

#import "JPVideoPlayerSupportUtils.h"
#import "objc/runtime.h"
#import "JPVideoPlayer.h"
#import "UIView+WebVideoCache.h"
#import "JPVideoPlayerControlViews.h"
#import "JPVideoPlayerCompat.h"
#import <MobileCoreServices/MobileCoreServices.h>

@implementation NSURL (StripQuery)

- (NSString *)absoluteStringByStrippingQuery{
    NSString *absoluteString = [self absoluteString];
    NSUInteger queryLength = [[self query] length];
    NSString* strippedString = (queryLength ? [absoluteString substringToIndex:[absoluteString length] - (queryLength + 1)] : absoluteString);

    if ([strippedString hasSuffix:@"?"]) {
        strippedString = [strippedString substringToIndex:absoluteString.length-1];
    }
    return strippedString;
}

@end

@implementation NSFileHandle (JPVideoPlayer)

- (BOOL)jp_safeWriteData:(NSData *)data {
    NSInteger retry = 3;
    size_t bytesLeft = data.length;
    const void *bytes = [data bytes];
    int fileDescriptor = [self fileDescriptor];
    while (bytesLeft > 0 && retry > 0) {
        ssize_t amountSent = write(fileDescriptor, bytes + data.length - bytesLeft, bytesLeft);
        if (amountSent < 0) {
            // write failed.
            JPErrorLog(@"Write file failed");
            break;
        }
        else {
            bytesLeft = bytesLeft - amountSent;
            if (bytesLeft > 0) {
                // not finished continue write after sleep 1 second.
                JPWarningLog(@"Write file retry");
                sleep(1);  //probably too long, but this is quite rare.
                retry--;
            }
        }
    }
    return bytesLeft == 0;
}

@end

@implementation NSHTTPURLResponse (JPVideoPlayer)

- (long long)jp_fileLength {
    NSString *range = [self allHeaderFields][@"Content-Range"];
    if (range) {
        NSArray *ranges = [range componentsSeparatedByString:@"/"];
        if (ranges.count > 0) {
            NSString *lengthString = [[ranges lastObject] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
            return [lengthString longLongValue];
        }
    }
    else {
        return [self expectedContentLength];
    }
    return 0;
}

- (BOOL)jp_supportRange {
    return [self allHeaderFields][@"Content-Range"] != nil;
}

@end

@implementation AVAssetResourceLoadingRequest (JPVideoPlayer)

- (void)jp_fillContentInformationWithResponse:(NSHTTPURLResponse *)response {
    if (!response) {
        return;
    }

    self.response = response;
    if (!self.contentInformationRequest) {
        return;
    }

    NSString *mimeType = [response MIMEType];
    CFStringRef contentType = UTTypeCreatePreferredIdentifierForTag(kUTTagClassMIMEType, (__bridge CFStringRef)(mimeType), NULL);
    self.contentInformationRequest.byteRangeAccessSupported = [response jp_supportRange];
    self.contentInformationRequest.contentType = CFBridgingRelease(contentType);
    self.contentInformationRequest.contentLength = [response jp_fileLength];
    JPDebugLog(@"填充了响应信息到 contentInformationRequest");
}

@end

@implementation NSURLSessionTask(JPVideoPlayer)

- (void)setWebTask:(JPResourceLoadingRequestWebTask *)webTask {
    id __weak __weak_object = webTask;
    id (^__weak_block)(void) = ^{
        return __weak_object;
    };
    objc_setAssociatedObject(self, @selector(webTask),   __weak_block, OBJC_ASSOCIATION_COPY);
}

- (JPResourceLoadingRequestWebTask *)webTask {
    id (^__weak_block)(void) = objc_getAssociatedObject(self, _cmd);
    if (!__weak_block) {
        return nil;
    }
    return __weak_block();
}

@end

NSString *kJPSwizzleErrorDomain = @"com.jpvideoplayer.swizzle.www";
@implementation NSObject (JPSwizzle)

+ (BOOL)jp_swizzleMethod:(SEL)origSel withMethod:(SEL)altSel error:(NSError**)error {
    Method origMethod = class_getInstanceMethod(self, origSel);
    if (!origMethod) {
        *error = [NSError errorWithDomain:kJPSwizzleErrorDomain code:0 userInfo:@{
                NSLocalizedDescriptionKey : [NSString stringWithFormat:@"original method %@ not found for class %@", NSStringFromSelector(origSel), [self class]]
        }];
        return NO;
    }

    Method altMethod = class_getInstanceMethod(self, altSel);
    if (!altMethod) {
        *error = [NSError errorWithDomain:kJPSwizzleErrorDomain code:0 userInfo:@{
                NSLocalizedDescriptionKey : [NSString stringWithFormat:@"alternate method %@ not found for class %@", NSStringFromSelector(altSel), [self class]]
        }];
        return NO;
    }

    class_addMethod(self,
            origSel,
            class_getMethodImplementation(self, origSel),
            method_getTypeEncoding(origMethod));
    class_addMethod(self,
            altSel,
            class_getMethodImplementation(self, altSel),
            method_getTypeEncoding(altMethod));

    method_exchangeImplementations(class_getInstanceMethod(self, origSel), class_getInstanceMethod(self, altSel));
    return YES;
}

@end

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
        message = [NSString stringWithFormat:@"[%@] [Thread: %02ld] %@", flag, (long)[threadName integerValue], message];
        printf("%s\n", message.UTF8String);
    }
}

@end

@interface JPApplicationStateMonitor()

@property(nonatomic, strong) NSMutableArray<NSNumber *> *applicationStateArray;

@property (nonatomic, assign) JPApplicationState applicationState;

@end

@implementation JPApplicationStateMonitor

- (instancetype)init {
    self = [super init];
    if (self) {
        [self setup];
    }
    return self;
}

- (void)dealloc {
    [self removeNotificationObserver];
}


#pragma mark - Setup

- (void)setup {
    [self addNotificationObserver];

    self.applicationStateArray = [NSMutableArray array];
    self.applicationState = JPApplicationStateUnknown;
}

- (void)addNotificationObserver {
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(applicationDidEnterBackgroundNotification)
                                                 name:UIApplicationDidEnterBackgroundNotification
                                               object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(applicationWillEnterForegroundNotification)
                                                 name:UIApplicationWillEnterForegroundNotification
                                               object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(applicationDidBecomeActiveNotification)
                                                 name:UIApplicationDidBecomeActiveNotification
                                               object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(applicationWillResignActiveNotification)
                                                 name:UIApplicationWillResignActiveNotification
                                               object:nil];
}

- (void)removeNotificationObserver {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}


#pragma mark - Notification

- (void)applicationWillResignActiveNotification {
    if (self.applicationStateArray.count) {
        [self.applicationStateArray removeAllObjects];
    }
    [self.applicationStateArray addObject:@(JPApplicationStateWillResignActive)];
    [self callDelegateMethodWithApplicationState:JPApplicationStateWillResignActive];
    self.applicationState = JPApplicationStateWillResignActive;
    JPDebugLog(@"JPApplicationStateWillResignActive");
}

- (void)applicationDidEnterBackgroundNotification {
    [self.applicationStateArray addObject:@(JPApplicationStateDidEnterBackground)];
    [self callDelegateMethodWithApplicationState:JPApplicationStateDidEnterBackground];
    self.applicationState = JPApplicationStateDidEnterBackground;
    JPDebugLog(@"JPApplicationStateDidEnterBackground");
}

- (void)applicationWillEnterForegroundNotification {
    [self.applicationStateArray addObject:@(JPApplicationStateWillEnterForeground)];
    [self callDelegateMethodWithApplicationState:JPApplicationStateWillEnterForeground];
    self.applicationState = JPApplicationStateWillEnterForeground;
    JPDebugLog(@"JPApplicationStateWillEnterForeground");
}

- (void)applicationDidBecomeActiveNotification{
    [self callDelegateMethodWithApplicationState:JPApplicationStateDidBecomeActive];
    self.applicationState = JPApplicationStateDidBecomeActive;
    JPDebugLog(@"JPApplicationStateDidBecomeActive");

    BOOL didEnterBackground = NO;
    for (NSNumber *appStateNumber in self.applicationStateArray) {
        NSInteger appState = appStateNumber.integerValue;
        if (appState == JPApplicationStateDidEnterBackground) {
            didEnterBackground = YES;
            break;
        }
    }
    if (!didEnterBackground) {
        if (self.delegate && [self.delegate respondsToSelector:@selector(applicationDidBecomeActiveFromResignActive:)]) {
            [self.delegate applicationDidBecomeActiveFromResignActive:self];
        }
    }
    else {
        if (self.delegate && [self.delegate respondsToSelector:@selector(applicationDidBecomeActiveFromBackground:)]) {
            [self.delegate applicationDidBecomeActiveFromBackground:self];
        }
    }
}

- (void)callDelegateMethodWithApplicationState:(JPApplicationState)applicationState {
    if (self.delegate && [self.delegate respondsToSelector:@selector(applicationStateMonitor:applicationStateDidChange:)]) {
        [self.delegate applicationStateMonitor:self applicationStateDidChange:applicationState];
    }
}

@end