//
//  JPVideoPlayerCustomizedVideoViewController.m
//  JPVideoPlayerDemo
//
//  Created by NewPan on 2019/3/17.
//  Copyright © 2019 NewPan. All rights reserved.
//

#import "JPVideoPlayerCustomizedVideoViewController.h"
#import "JPVideoPlayerKit.h"

@interface JPVideoPlayerCustomizedVideoViewController ()<JPVideoPlayerDelegate>

@property (weak, nonatomic) IBOutlet UITextField *videoURLTextField;

@property (weak, nonatomic) IBOutlet UIView *videoView;

@property (nonatomic, strong) NSMutableArray<NSValue *> *internalFragmentRanges;

@end

@implementation JPVideoPlayerCustomizedVideoViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"自定义视频播放";
    self.videoView.jp_videoPlayerDelegate = self;
    self.internalFragmentRanges = @[].mutableCopy;
    [self.internalFragmentRanges addObject:[NSValue valueWithRange:NSMakeRange(0, 4)]]; /// [0, 3]
//    [self.internalFragmentRanges addObject:[NSValue valueWithRange:NSMakeRange(5, 6)]]; /// [5, 10]
//    [self.internalFragmentRanges addObject:[NSValue valueWithRange:NSMakeRange(15, 6)]]; /// [15, 20]

    [self componentRequestDataRange:NSMakeRange(0, 100)];
}

- (void)componentRequestDataRange:(NSRange)dataRange {
    NSUInteger start = dataRange.location;
    NSUInteger end = NSMaxRange(dataRange);
    NSRange firstCachedRange;
    NSMutableArray *cacheHitRanges = @[].mutableCopy;
    NSMutableArray *cacheMissRanges = @[].mutableCopy;
    NSRange targetRange;
    while (start < end) {
        firstCachedRange = [self firstCachedRangeOnLocation:start];
        /// 找得到就意味着有部分已经缓存完.
        if (JPValidFileRange(firstCachedRange)) {
            /// contain
            /// ------ + ------- * ------- + ------
            if (NSLocationInRange(start, firstCachedRange)) {
                ///                start        end
                /// ------ + ------- * --------- * --------- + ------
                if (end < NSMaxRange(firstCachedRange)) {
                    targetRange = NSMakeRange(start, end - start);
                    if (JPValidFileRange(targetRange)) [cacheHitRanges addObject:[NSValue valueWithRange:targetRange]];
                    start = end;
                }
                ///                start                    end
                /// ------ + ------- * -------- + ---------- * ---------
                else {
                    targetRange = NSMakeRange(start, NSMaxRange(firstCachedRange) - start);
                    if (JPValidFileRange(targetRange)) [cacheHitRanges addObject:[NSValue valueWithRange:targetRange]];
                    start = NSMaxRange(firstCachedRange);
                }
            }
            /// after.
            /// ------ * ------- + ------- + ------
            else {
                ///      start                end
                /// ------ * ------- + ------- * ------ + --------
                if (NSLocationInRange(end, firstCachedRange)) {
                    targetRange = NSMakeRange(start, firstCachedRange.location - start);
                    if (JPValidFileRange(targetRange)) [cacheMissRanges addObject:[NSValue valueWithRange:targetRange]];
                    targetRange = NSMakeRange(firstCachedRange.location, end - firstCachedRange.location);
                    if (JPValidFileRange(targetRange)) [cacheHitRanges addObject:[NSValue valueWithRange:targetRange]];
                    start = end;
                }
                else {
                    /// 这里不会出现 end == firstCachedRange.location
                    NSParameterAssert(end != firstCachedRange.location);
                    ///      start       end
                    /// ------ * ------- * ------- + ------ + --------
                    if (end < firstCachedRange.location) {
                        targetRange = NSMakeRange(start, end - start);
                        if (JPValidFileRange(targetRange)) [cacheMissRanges addObject:[NSValue valueWithRange:targetRange]];
                        start = end;
                    }
                    ///      start                         end
                    /// ------ * ------- + ------- + ------ * --------
                    else {
                        targetRange = NSMakeRange(start, firstCachedRange.location - start);
                        if (JPValidFileRange(targetRange)) [cacheMissRanges addObject:[NSValue valueWithRange:targetRange]];
                        if (JPValidFileRange(firstCachedRange)) [cacheHitRanges addObject:[NSValue valueWithRange:firstCachedRange]];
                        start = NSMaxRange(firstCachedRange);
                    }
                }
            }
        }
        /// 找不到就意味着, 完全没开始缓存.
        else {
            targetRange = NSMakeRange(start, end - start);
            if (JPValidFileRange(targetRange)) [cacheMissRanges addObject:[NSValue valueWithRange:targetRange]];
            start = end;
        }
    }
    NSString *cacheHit = @"缓存命中: ";
    NSString *cacheMiss = @"缓存未命中: ";
    NSRange range;
    for (NSValue *hitRange in cacheHitRanges) {
        range = hitRange.rangeValue;
        cacheHit = [cacheHit stringByAppendingFormat:@" - [%d, %d]", range.location, NSMaxRange(range) - 1];
    }
    for (NSValue *cacheMissRange in cacheMissRanges) {
        range = cacheMissRange.rangeValue;
        cacheMiss = [cacheMiss stringByAppendingFormat:@" - [%d, %d]", range.location, NSMaxRange(range) - 1];
    }
    NSLog(@"%@", cacheHit);
    NSLog(@"%@", cacheMiss);
}

- (NSRange)firstCachedRangeOnLocation:(NSUInteger)location {
    /// 找得到就意味着有部分已经缓存完.
    /// 找不到就意味着 location 以后的数据完全没开始缓存.
    __block NSRange result = JPInvalidRange;
    NSRange _range;
    for (NSValue *v in self.internalFragmentRanges) {
        _range = v.rangeValue;
        /// contain
        /// ------ + ------- * ------- + ------
        /// after.
        /// ------ * ------- + ------- + ------
        if (NSLocationInRange(location, _range) || location < _range.location) {
            result = _range;
            break;
        }
    }
    return result;
}

- (void)viewDidDisappear:(BOOL)animated {
    [super viewDidDisappear:animated];
    [self.videoView jp_stopPlay];
}

- (IBAction)playButtonDidClick:(id)sender {
    NSArray<NSString *> *ranges = [self.videoURLTextField.text componentsSeparatedByString:@"，"];
    NSRange range = NSMakeRange(ranges.firstObject.integerValue, ranges.lastObject.integerValue);
    [self componentRequestDataRange:range];
//    [self.view endEditing:YES];
//    NSString *videoURLPath = self.videoURLTextField.text;
//    if (!videoURLPath.length) videoURLPath = self.videoURLTextField.placeholder;
//    if (!videoURLPath.length) return;
//
//    [self.videoView jp_resumePlayWithURL:[NSURL URLWithString:videoURLPath]
//                      bufferingIndicator:nil
//                             controlView:nil
//                            progressView:nil
//                           configuration:nil];
}


#pragma mark - JPVideoPlayerDelegate

- (void)playVideoFailWithError:(NSError *)error videoURL:(NSURL *)videoURL {
    NSLog(@"%@", error);
}

- (BOOL)shouldVideoViewResizeToFitWhenDeviceOrientationDidChange:(UIDeviceOrientation)deviceOrientation {
    return YES;
}

- (BOOL)shouldResumePlaybackFromPlaybackRecordForURL:(NSURL *)videoURL elapsedSeconds:(NSTimeInterval)elapsedSeconds {
    return YES;
}

@end
