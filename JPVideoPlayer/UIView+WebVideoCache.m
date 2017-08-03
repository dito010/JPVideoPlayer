/*
 * This file is part of the JPVideoPlayer package.
 * (c) NewPan <13246884282@163.com>
 *
 * For the full copyright and license information, please view the LICENSE
 * file that was distributed with this source code.
 *
 * Click https://github.com/Chris-Pan
 * or http://www.jianshu.com/users/e2f2d779c022/latest_articles to contact me.
 */


#import "UIView+WebVideoCache.h"
#import "UIView+WebVideoCacheOperation.h"
#import <objc/runtime.h>
#import "JPVideoPlayerPlayVideoTool.h"

static NSString *JPVideoPlayerErrorDomain = @"JPVideoPlayerErrorDomain";

@interface UIView()

/**
 * Parent view of self before enter full screen.
 */
@property(nonatomic)UIView *parentView_beforeFullScreen;

/**
 * Frame of self before enter full screen.
 */
@property(nonatomic)NSValue *frame_beforeFullScreen;

@end

@implementation UIView (WebVideoCache)

#pragma mark - Play Video Methods

- (void)jp_playVideoWithURL:(NSURL *)url{
    [self jp_playVideoWithURL:url options:JPVideoPlayerContinueInBackground | JPVideoPlayerLayerVideoGravityResizeAspect | JPVideoPlayerShowActivityIndicatorView | JPVideoPlayerShowProgressView progress:nil completed:nil];
}

- (void)jp_playVideoHiddenStatusViewWithURL:(NSURL *)url{
    [self jp_playVideoWithURL:url options:JPVideoPlayerContinueInBackground | JPVideoPlayerShowActivityIndicatorView | JPVideoPlayerLayerVideoGravityResizeAspect progress:nil completed:nil];
}

- (void)jp_playVideoMutedDisplayStatusViewWithURL:(NSURL *)url{
    [self jp_playVideoWithURL:url options:JPVideoPlayerContinueInBackground | JPVideoPlayerShowProgressView | JPVideoPlayerShowActivityIndicatorView | JPVideoPlayerLayerVideoGravityResizeAspect | JPVideoPlayerMutedPlay progress:nil completed:nil];
}

- (void)jp_playVideoMutedHiddenStatusViewWithURL:(NSURL *)url{
    [self jp_playVideoWithURL:url options:JPVideoPlayerContinueInBackground | JPVideoPlayerMutedPlay | JPVideoPlayerLayerVideoGravityResizeAspect | JPVideoPlayerShowActivityIndicatorView progress:nil completed:nil];
}

- (void)jp_playVideoWithURL:(NSURL *)url options:(JPVideoPlayerOptions)options progress:(JPVideoPlayerDownloaderProgressBlock)progressBlock completed:(JPVideoPlayerCompletionBlock)completedBlock{
    
    NSString *validOperationKey = NSStringFromClass([self class]);
    [self jp_cancelVideoLoadOperationWithKey:validOperationKey];
    [self jp_stopPlay];
    self.currentPlayingURL = url;
    self.viewStatus = JPVideoPlayerVideoViewStatusPortrait;
    
    if (url) {
        __weak typeof(self) wself = self;
        
        // set self as the delegate of `JPVideoPlayerManager`.
        [JPVideoPlayerManager sharedManager].delegate = self;
        
        // set up the video layer view and indicator view.
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
        [self performSelector:NSSelectorFromString(@"jp_setupVideoLayerViewAndIndicatorView")];
#pragma clang diagnostic pop
        
        id <JPVideoPlayerOperation> operation = [[JPVideoPlayerManager sharedManager] loadVideoWithURL:url showOnView:self options:options progress:progressBlock completed:^(NSString * _Nullable fullVideoCachePath, NSError * _Nullable error, JPVideoPlayerCacheType cacheType, NSURL * _Nullable videoURL) {
            __strong __typeof (wself) sself = wself;
            if (!sself) return;
            
            dispatch_main_async_safe(^{
                if (completedBlock) {
                    completedBlock(fullVideoCachePath, error, cacheType, url);
                }
            });
        }];
        
        [self jp_setVideoLoadOperation:operation forKey:validOperationKey];
    }
    else {
        dispatch_main_async_safe(^{
            if (completedBlock) {
                NSError *error = [NSError errorWithDomain:JPVideoPlayerErrorDomain code:-1 userInfo:@{NSLocalizedDescriptionKey : @"Trying to load a nil url"}];
                completedBlock(nil, error, JPVideoPlayerCacheTypeNone, url);
            }
        });
    }
}


#pragma mark - Play Control

- (void)jp_stopPlay{
    [[JPVideoPlayerCache sharedCache] cancelCurrentComletionBlock];
    [[JPVideoPlayerDownloader sharedDownloader] cancelAllDownloads];
    [[JPVideoPlayerManager sharedManager]stopPlay];
}

- (void)jp_pause{
    [[JPVideoPlayerManager sharedManager] pause];
}

- (void)jp_resume{
    [[JPVideoPlayerManager sharedManager] resume];
}

- (void)jp_setPlayerMute:(BOOL)mute{
    [[JPVideoPlayerManager sharedManager] setPlayerMute:mute];
}

- (BOOL)jp_playerIsMute{
    return [JPVideoPlayerManager sharedManager].playerIsMute;
}


#pragma mark - Landscape Or Portrait Control

- (void)jp_gotoLandscape {
    [self jp_gotoLandscapeAnimated:YES completion:nil];
}

- (void)jp_gotoLandscapeAnimated:(BOOL)animated completion:(JPVideoPlayerScreenAnimationCompletion)completion {
    if (self.viewStatus != JPVideoPlayerVideoViewStatusPortrait) {
        return;
    }
    
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
    // hide status bar.
    [[UIApplication sharedApplication] setStatusBarHidden:YES withAnimation:UIStatusBarAnimationFade];
#pragma clang diagnostic pop
    
    self.viewStatus = JPVideoPlayerVideoViewStatusAnimating;
    
    self.parentView_beforeFullScreen = self.superview;
    self.frame_beforeFullScreen = [NSValue valueWithCGRect:self.frame];
    
    CGRect rectInWindow = [self.superview convertRect:self.frame toView:nil];
    [self removeFromSuperview];
    [[UIApplication sharedApplication].keyWindow addSubview:self];
    self.frame = rectInWindow;
    self.jp_indicatorView.alpha = 0;
    
    if (animated) {
        [UIView animateWithDuration:0.35 animations:^{
            
            [self executeLandscape];
            
        } completion:^(BOOL finished) {
            
            self.viewStatus = JPVideoPlayerVideoViewStatusLandscape;
            if (completion) {
                completion();
            }
            [UIView animateWithDuration:0.5 animations:^{
                
                self.jp_indicatorView.alpha = 1;
            }];
            
        }];
    }
    else{
        [self executeLandscape];
        self.viewStatus = JPVideoPlayerVideoViewStatusLandscape;
        if (completion) {
            completion();
        }
        [UIView animateWithDuration:0.5 animations:^{
            
            self.jp_indicatorView.alpha = 1;
        }];
    }
    
    [self refreshStatusBarOrientation:UIInterfaceOrientationLandscapeRight];
}

- (void)jp_gotoPortrait {
    [self jp_gotoPortraitAnimated:YES completion:nil];
}

- (void)jp_gotoPortraitAnimated:(BOOL)animated completion:(JPVideoPlayerScreenAnimationCompletion)completion{
    if (self.viewStatus != JPVideoPlayerVideoViewStatusLandscape) {
        return;
    }
    
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
    // display status bar.
    [[UIApplication sharedApplication] setStatusBarHidden:NO withAnimation:UIStatusBarAnimationFade];
#pragma clang diagnostic pop
    
    self.viewStatus = JPVideoPlayerVideoViewStatusAnimating;
    
    self.jp_indicatorView.alpha = 0;
    
    if (animated) {
        [UIView animateWithDuration:0.35 animations:^{
            
            [self executePortrait];
            
        } completion:^(BOOL finished) {
           
            [self finishPortrait];
            if (completion) {
                completion();
            }
            
        }];
    }
    else{
        [self executePortrait];
        [self finishPortrait];
        if (completion) {
            completion();
        }
    }
    
    [self refreshStatusBarOrientation:UIInterfaceOrientationPortrait];
}


#pragma mark - Private

- (void)finishPortrait{
    [self removeFromSuperview];
    [self.parentView_beforeFullScreen addSubview:self];
    self.frame = [self.frame_beforeFullScreen CGRectValue];
    
    self.jp_backgroundLayer.frame = self.bounds;
    [JPVideoPlayerPlayVideoTool sharedTool].currentPlayVideoItem.currentPlayerLayer.frame = self.bounds;
    self.jp_videoLayerView.frame = self.bounds;
    self.jp_indicatorView.frame = self.bounds;
    
    self.viewStatus = JPVideoPlayerVideoViewStatusPortrait;
    
    [UIView animateWithDuration:0.5 animations:^{
        
        self.jp_indicatorView.alpha = 1;
    }];
}

- (void)executePortrait{
    CGRect frame = [self.parentView_beforeFullScreen convertRect:[self.frame_beforeFullScreen CGRectValue] toView:nil];
    self.transform = CGAffineTransformIdentity;
    self.frame = frame;
    
    self.jp_backgroundLayer.frame = self.bounds;
    [JPVideoPlayerPlayVideoTool sharedTool].currentPlayVideoItem.currentPlayerLayer.frame = self.bounds;
    self.jp_videoLayerView.frame = self.bounds;
    self.jp_indicatorView.frame = self.bounds;
    
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
    [self performSelector:NSSelectorFromString(@"refreshIndicatorViewForPortrait")];
#pragma clang diagnostic pop
}

- (void)executeLandscape{
    self.transform = CGAffineTransformMakeRotation(M_PI_2);
    CGRect bounds = CGRectMake(0, 0, CGRectGetHeight(self.superview.bounds), CGRectGetWidth(self.superview.bounds));
    CGPoint center = CGPointMake(CGRectGetMidX(self.superview.bounds), CGRectGetMidY(self.superview.bounds));
    self.bounds = bounds;
    self.center = center;
    
    self.jp_backgroundLayer.frame = bounds;
    [JPVideoPlayerPlayVideoTool sharedTool].currentPlayVideoItem.currentPlayerLayer.frame = bounds;
    self.jp_videoLayerView.frame = bounds;
    self.jp_indicatorView.frame = bounds;
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
    [self performSelector:NSSelectorFromString(@"refreshIndicatorViewForLandscape")];
#pragma clang diagnostic pop
}

- (void)refreshStatusBarOrientation:(UIInterfaceOrientation)interfaceOrientation {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
    [[UIApplication sharedApplication] setStatusBarOrientation:interfaceOrientation animated:YES];
#pragma clang diagnostic pop
}

- (void)setParentView_beforeFullScreen:(UIView *)parentView_beforeFullScreen{
    objc_setAssociatedObject(self, @selector(parentView_beforeFullScreen), parentView_beforeFullScreen, OBJC_ASSOCIATION_ASSIGN);
}

- (void)setPlayingStatus:(JPVideoPlayerPlayingStatus)playingStatus{
    objc_setAssociatedObject(self, @selector(playingStatus), @(playingStatus), OBJC_ASSOCIATION_ASSIGN);
}

- (JPVideoPlayerPlayingStatus)playingStatus{
    return [objc_getAssociatedObject(self, _cmd) integerValue];
}

- (UIView *)parentView_beforeFullScreen{
    return objc_getAssociatedObject(self, _cmd);
}

- (void)setFrame_beforeFullScreen:(NSValue *)frame_beforeFullScreen{
    objc_setAssociatedObject(self, @selector(frame_beforeFullScreen), frame_beforeFullScreen, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (NSValue *)frame_beforeFullScreen{
    return objc_getAssociatedObject(self, _cmd);
}

- (void)setViewStatus:(JPVideoPlayerVideoViewStatus)viewStatus{
    objc_setAssociatedObject(self, @selector(viewStatus), @(viewStatus), OBJC_ASSOCIATION_ASSIGN);
}

- (JPVideoPlayerVideoViewStatus)viewStatus{
    return [objc_getAssociatedObject(self, _cmd) integerValue];
}

- (id<JPVideoPlayerDelegate>)jp_videoPlayerDelegate{
    id (^__weak_block)() = objc_getAssociatedObject(self, _cmd);
    return __weak_block();
}

- (void)setJp_videoPlayerDelegate:(id<JPVideoPlayerDelegate>)jp_videoPlayerDelegate{
    id __weak __weak_object = jp_videoPlayerDelegate;
    id (^__weak_block)() = ^{
        return __weak_object;
    };
    objc_setAssociatedObject(self, @selector(jp_videoPlayerDelegate),   __weak_block, OBJC_ASSOCIATION_COPY);
}


#pragma mark - JPVideoPlayerManager

- (BOOL)videoPlayerManager:(JPVideoPlayerManager *)videoPlayerManager shouldDownloadVideoForURL:(NSURL *)videoURL{
    if (self.jp_videoPlayerDelegate && [self.jp_videoPlayerDelegate respondsToSelector:@selector(shouldDownloadVideoForURL:)]) {
        return [self.jp_videoPlayerDelegate shouldDownloadVideoForURL:videoURL];
    }
    return YES;
}

- (BOOL)videoPlayerManager:(JPVideoPlayerManager *)videoPlayerManager shouldAutoReplayForURL:(NSURL *)videoURL{
    if (self.jp_videoPlayerDelegate && [self.jp_videoPlayerDelegate respondsToSelector:@selector(shouldAutoReplayAfterPlayCompleteForURL:)]) {
        return [self.jp_videoPlayerDelegate shouldAutoReplayAfterPlayCompleteForURL:videoURL];
    }
    return YES;
}

- (void)videoPlayerManager:(JPVideoPlayerManager *)videoPlayerManager playingStatusDidChanged:(JPVideoPlayerPlayingStatus)playingStatus{
    self.playingStatus = playingStatus;
    if (self.jp_videoPlayerDelegate && [self.jp_videoPlayerDelegate respondsToSelector:@selector(playingStatusDidChanged:)]) {
        [self.jp_videoPlayerDelegate playingStatusDidChanged:playingStatus];
    }
}

- (BOOL)videoPlayerManager:(JPVideoPlayerManager *)videoPlayerManager downloadingProgressDidChanged:(CGFloat)downloadingProgress{
    if (self.jp_videoPlayerDelegate && [self.jp_videoPlayerDelegate respondsToSelector:@selector(downloadingProgressDidChanged:)]) {
        [self.jp_videoPlayerDelegate downloadingProgressDidChanged:downloadingProgress];
        return NO;
    }
    return YES;
}

- (BOOL)videoPlayerManager:(JPVideoPlayerManager *)videoPlayerManager playingProgressDidChanged:(CGFloat)playingProgress{
    if (self.jp_videoPlayerDelegate && [self.jp_videoPlayerDelegate respondsToSelector:@selector(playingProgressDidChanged:)]) {
        [self.jp_videoPlayerDelegate playingProgressDidChanged:playingProgress];
        return NO;
    }
    return YES;
}

@end
