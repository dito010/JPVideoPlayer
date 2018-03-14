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


#pragma mark - Landscape Events
//
//- (void)layoutProgressViewForPortrait:(UIView *)progressView{
//    CGFloat progressViewY = self.frame.size.height - JPVideoPlayerLayerFrameY;
//    if ([self.jp_videoPlayerDelegate respondsToSelector:@selector(shouldProgressViewOnTop)] && [self.jp_videoPlayerDelegate shouldProgressViewOnTop]) {
//        progressViewY = 0;
//    }
//    progressView.frame = CGRectMake(0, progressViewY, self.frame.size.width, JPVideoPlayerLayerFrameY);
//}
//
//- (void)layoutProgressViewForLandscape:(UIView *)progressView{
//    CGFloat width = CGRectGetHeight(self.superview.bounds);
//    CGFloat hei = CGRectGetWidth(self.superview.bounds);
//    CGFloat progressViewY = hei - JPVideoPlayerLayerFrameY;
//    if ([self.jp_videoPlayerDelegate respondsToSelector:@selector(shouldProgressViewOnTop)] && [self.jp_videoPlayerDelegate shouldProgressViewOnTop]) {
//        progressViewY = 0;
//    }
//    progressView.frame = CGRectMake(0, progressViewY, width, hei);
//}
//
//- (void)layoutActivityIndicatorViewForPortrait:(UIView *)acv{
//    CGSize viewSize = self.frame.size;
//    CGFloat selfX = (viewSize.width-JPVideoPlayerActivityIndicatorWH)*0.5;
//    CGFloat selfY = (viewSize.height-JPVideoPlayerActivityIndicatorWH)*0.5;
//    acv.frame = CGRectMake(selfX, selfY, JPVideoPlayerActivityIndicatorWH, JPVideoPlayerActivityIndicatorWH);
//}
//
//- (void)layoutActivityIndicatorViewForLandscape:(UIView *)acv{
//    CGFloat width = CGRectGetHeight(self.superview.bounds);
//    CGFloat hei = CGRectGetWidth(self.superview.bounds);
//    CGFloat selfX = (width-JPVideoPlayerActivityIndicatorWH)*0.5;
//    CGFloat selfY = (hei-JPVideoPlayerActivityIndicatorWH)*0.5;
//    acv.frame = CGRectMake(selfX, selfY, JPVideoPlayerActivityIndicatorWH, JPVideoPlayerActivityIndicatorWH);
//}

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