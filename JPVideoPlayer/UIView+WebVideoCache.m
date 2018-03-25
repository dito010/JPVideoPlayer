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
#import <objc/runtime.h>
#import "JPVideoPlayer.h"
#import "JPVideoPlayerSupportUtils.h"
#import "JPVideoPlayerControlViews.h"

@interface JPVideoPlayerCategoryHelper : NSObject

@property(nonatomic, strong) JPVideoPlayerView *videoPlayerView;

@property(nonatomic, strong) UIView<JPVideoPlayerProtocol> *progressView;

@property(nonatomic, strong) UIView<JPVideoPlayerProtocol> *controlView;

@property(nonatomic, weak)id<JPVideoPlayerDelegate> videoPlayerDelegate;

@property(nonatomic, assign)JPVideoPlayerVideoViewStatus viewStatus;

@property(nonatomic, assign)JPVideoPlayerStatus playerStatus;

@end

@implementation JPVideoPlayerCategoryHelper

- (JPVideoPlayerView *)videoPlayerView {
    if(!_videoPlayerView){
       _videoPlayerView = [JPVideoPlayerView new];
    }
    return _videoPlayerView;
}

@end

@interface UIView()

/**
 * Parent view of self before enter full screen.
 */
@property(nonatomic)UIView *parentView_beforeFullScreen;

/**
 * Frame of self before enter full screen.
 */
@property(nonatomic)NSValue *frame_beforeFullScreen;

@property(nonatomic, readonly)JPVideoPlayerCategoryHelper *helper;

@end

@implementation UIView (WebVideoCache)

#pragma mark - Properties

- (JPVideoPlayerVideoViewStatus)jp_viewStatus {
    return self.helper.viewStatus;
}

- (JPVideoPlayerStatus)jp_playerStatus {
    return self.helper.playerStatus;
}

- (void)setJp_progressView:(UIView <JPVideoPlayerProtocol> *)jp_progressView {
    self.helper.progressView = jp_progressView;
}

- (UIView <JPVideoPlayerProtocol> *)jp_progressView {
    return self.helper.progressView;
}

- (void)setJp_controlView:(UIView <JPVideoPlayerProtocol> *)jp_controlView {
    self.helper.controlView = jp_controlView;
}

- (UIView <JPVideoPlayerProtocol> *)jp_controlView {
    return self.helper.controlView;
}

- (void)setJp_videoPlayerDelegate:(id <JPVideoPlayerDelegate>)jp_videoPlayerDelegate {
    self.helper.videoPlayerDelegate = jp_videoPlayerDelegate;
}

- (id <JPVideoPlayerDelegate>)jp_videoPlayerDelegate {
    return self.helper.videoPlayerDelegate;
}


#pragma mark - Play Video Methods

- (void)jp_playVideoWithURL:(NSURL *)url {
    [self jp_playVideoWithURL:url options:JPVideoPlayerContinueInBackground |
            JPVideoPlayerLayerVideoGravityResizeAspect];
}

- (void)jp_playVideoMuteWithURL:(NSURL *)url
                   progressView:(UIView <JPVideoPlayerProtocol> *_Nullable)progressView {
    NSParameterAssert(progressView);
    // TODO: 没有 progressView 使用自定义的.
    self.jp_progressView = progressView;
    [self jp_playVideoWithURL:url options:JPVideoPlayerContinueInBackground |
            JPVideoPlayerLayerVideoGravityResizeAspect |
            JPVideoPlayerMutedPlay];
}

- (void)jp_playVideoWithURL:(NSURL *)url
                controlView:(UIView <JPVideoPlayerProtocol> *_Nullable)controlView {
    if(!controlView){
        // Use default `JPVideoPlayerControlView` if no controlView.
        controlView = [JPVideoPlayerControlView new];
    }
    self.jp_controlView = controlView;
    [self jp_playVideoWithURL:url options:JPVideoPlayerContinueInBackground |
            JPVideoPlayerLayerVideoGravityResizeAspect];
}

- (void)jp_playVideoWithURL:(NSURL *)url options:(JPVideoPlayerOptions)options {
    [self jp_stopPlay];
    self.helper.viewStatus = JPVideoPlayerVideoViewStatusPortrait;

    if (url) {
        [JPVideoPlayerManager sharedManager].delegate = self;

        // Add progress view and control view if need.
        if(!self.helper.videoPlayerView.superview){
            [self addSubview:self.helper.videoPlayerView];
            self.helper.videoPlayerView.frame = self.bounds;
        }
        if(self.jp_controlView && !self.jp_controlView.superview){
            self.jp_controlView.frame = self.bounds;
            [self.helper.videoPlayerView.controlContainerView addSubview:self.jp_controlView];
        }
        if(self.jp_progressView && !self.jp_progressView.superview){
            self.jp_progressView.frame = self.bounds;
            [self.helper.videoPlayerView.controlContainerView addSubview:self.jp_progressView];
        }

        [[JPVideoPlayerManager sharedManager] playVideoWithURL:url
                                                   showOnLayer:self.helper.videoPlayerView.videoContainerLayer
                                                       options:options];
    }
    else {
        JPDispatchSyncOnMainQueue(^{
            if (self.jp_videoPlayerDelegate && [self.jp_videoPlayerDelegate respondsToSelector:@selector(downloadProgressDidChangeReceivedSize:expectedSize:error:)]) {
                NSError *error = [NSError errorWithDomain:JPVideoPlayerErrorDomain code:-1 userInfo:@{NSLocalizedDescriptionKey : @"Try to load a nil url"}];
                [self.jp_videoPlayerDelegate downloadProgressDidChangeReceivedSize:0 expectedSize:0 error:error];
            }
        });
    }
}


#pragma mark - Play Control

- (void)jp_stopPlay{
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
    if (self.jp_viewStatus != JPVideoPlayerVideoViewStatusPortrait) {
        return;
    }

//    self.jp_videoLayerView.backgroundColor = [UIColor blackColor];
//#pragma clang diagnostic push
//#pragma clang diagnostic ignored "-Wdeprecated-declarations"
//    // hide status bar.
//    [[UIApplication sharedApplication] setStatusBarHidden:YES withAnimation:UIStatusBarAnimationFade];
//#pragma clang diagnostic pop
//
//    self.jp_viewStatus = JPVideoPlayerVideoViewStatusAnimating;
//
//    self.parentView_beforeFullScreen = self.superview;
//    self.frame_beforeFullScreen = [NSValue valueWithCGRect:self.frame];
//
//    CGRect rectInWindow = [self.superview convertRect:self.frame toView:nil];
//    [self removeFromSuperview];
//    [[UIApplication sharedApplication].keyWindow addSubview:self];
//    self.frame = rectInWindow;
//    self.jp_indicatorView.alpha = 0;
//
//    if (animated) {
//        [UIView animateWithDuration:0.35 animations:^{
//
//            [self executeLandscape];
//
//        } completion:^(BOOL finished) {
//
//            self.jp_viewStatus = JPVideoPlayerVideoViewStatusLandscape;
//            if (completion) {
//                completion();
//            }
//            [UIView animateWithDuration:0.5 animations:^{
//
//                self.jp_indicatorView.alpha = 1;
//            }];
//
//        }];
//    }
//    else{
//        [self executeLandscape];
//        self.jp_viewStatus = JPVideoPlayerVideoViewStatusLandscape;
//        if (completion) {
//            completion();
//        }
//        [UIView animateWithDuration:0.5 animations:^{
//
//            self.jp_indicatorView.alpha = 1;
//        }];
//    }
//
//    [self refreshStatusBarOrientation:UIInterfaceOrientationLandscapeRight];
}

- (void)jp_gotoPortrait {
    [self jp_gotoPortraitAnimated:YES completion:nil];
}

- (void)jp_gotoPortraitAnimated:(BOOL)animated
                     completion:(JPVideoPlayerScreenAnimationCompletion)completion{
//    if (self.jp_viewStatus != JPVideoPlayerVideoViewStatusLandscape) {
//        return;
//    }
//
//    self.jp_videoLayerView.backgroundColor = [UIColor clearColor];
//#pragma clang diagnostic push
//#pragma clang diagnostic ignored "-Wdeprecated-declarations"
//    // display status bar.
//    [[UIApplication sharedApplication] setStatusBarHidden:NO withAnimation:UIStatusBarAnimationFade];
//#pragma clang diagnostic pop
//
//    self.jp_viewStatus = JPVideoPlayerVideoViewStatusAnimating;
//
//    self.jp_indicatorView.alpha = 0;
//
//    if (animated) {
//        [UIView animateWithDuration:0.35 animations:^{
//
//            [self executePortrait];
//
//        } completion:^(BOOL finished) {
//
//            [self finishPortrait];
//            if (completion) {
//                completion();
//            }
//
//        }];
//    }
//    else{
//        [self executePortrait];
//        [self finishPortrait];
//        if (completion) {
//            completion();
//        }
//    }
//
//    [self refreshStatusBarOrientation:UIInterfaceOrientationPortrait];
}


#pragma mark - Private

- (void)finishPortrait{
//    [self removeFromSuperview];
//    [self.parentView_beforeFullScreen addSubview:self];
//    self.frame = [self.frame_beforeFullScreen CGRectValue];
//
//    self.jp_backgroundLayer.frame = self.bounds;
//    [[JPVideoPlayerManager sharedManager] videoPlayer].currentPlayerModel.currentPlayerLayer.frame = self.bounds;
//    self.jp_videoLayerView.frame = self.bounds;
//    self.jp_indicatorView.frame = self.bounds;
//
//    self.jp_viewStatus = JPVideoPlayerVideoViewStatusPortrait;
//
//    [UIView animateWithDuration:0.5 animations:^{
//
//        self.jp_indicatorView.alpha = 1;
//    }];
}

- (void)executePortrait{
//    CGRect frame = [self.parentView_beforeFullScreen convertRect:[self.frame_beforeFullScreen CGRectValue] toView:nil];
//    self.transform = CGAffineTransformIdentity;
//    self.frame = frame;
//
//    self.jp_backgroundLayer.frame = self.bounds;
//    [[JPVideoPlayerManager sharedManager] videoPlayer].currentPlayerModel.currentPlayerLayer.frame = self.bounds;
//    self.jp_videoLayerView.frame = self.bounds;
//    self.jp_indicatorView.frame = self.bounds;
//
//#pragma clang diagnostic push
//#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
//    [self performSelector:NSSelectorFromString(@"refreshIndicatorViewForPortrait")];
//#pragma clang diagnostic pop
}

- (void)executeLandscape{
//    self.transform = CGAffineTransformMakeRotation(M_PI_2);
//    CGRect bounds = CGRectMake(0, 0, CGRectGetHeight(self.superview.bounds), CGRectGetWidth(self.superview.bounds));
//    CGPoint center = CGPointMake(CGRectGetMidX(self.superview.bounds), CGRectGetMidY(self.superview.bounds));
//    self.bounds = bounds;
//    self.center = center;
//
//    self.jp_backgroundLayer.frame = bounds;
//    [[JPVideoPlayerManager sharedManager] videoPlayer].currentPlayerModel.currentPlayerLayer.frame = bounds;
//    self.jp_videoLayerView.frame = bounds;
//    self.jp_indicatorView.frame = bounds;
//#pragma clang diagnostic push
//#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
//    [self performSelector:NSSelectorFromString(@"refreshIndicatorViewForLandscape")];
//#pragma clang diagnostic pop
}

- (void)refreshStatusBarOrientation:(UIInterfaceOrientation)interfaceOrientation {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
    [[UIApplication sharedApplication] setStatusBarOrientation:interfaceOrientation animated:YES];
#pragma clang diagnostic pop
}

- (JPVideoPlayerCategoryHelper *)helper {
    JPVideoPlayerCategoryHelper *helper = objc_getAssociatedObject(self, _cmd);
    if(!helper){
        helper = [JPVideoPlayerCategoryHelper new];
        objc_setAssociatedObject(self, _cmd, helper, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    return helper;
}

- (void)setParentView_beforeFullScreen:(UIView *)parentView_beforeFullScreen{
    objc_setAssociatedObject(self, @selector(parentView_beforeFullScreen), parentView_beforeFullScreen, OBJC_ASSOCIATION_ASSIGN);
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


#pragma mark - JPVideoPlayerManager

- (BOOL)videoPlayerManager:(JPVideoPlayerManager *)videoPlayerManager
 shouldDownloadVideoForURL:(NSURL *)videoURL {
    return YES;
}

- (BOOL)videoPlayerManager:(JPVideoPlayerManager *)videoPlayerManager
    shouldAutoReplayForURL:(NSURL *)videoURL {
    return YES;
}

- (void)videoPlayerManager:(JPVideoPlayerManager *)videoPlayerManager
    playerStatusDidChanged:(JPVideoPlayerStatus)playerStatus {

}

- (void)videoPlayerManagerDownloadProgressDidChange:(JPVideoPlayerManager *)videoPlayerManager
                                          cacheType:(JPVideoPlayerCacheType)cacheType
                                       receivedSize:(NSUInteger)receivedSize
                                       expectedSize:(NSUInteger)expectedSize
                                              error:(NSError *_Nullable)error {
    if(error){
        // TODO handle error.
        return;
    }
    switch(cacheType){
        case JPVideoPlayerCacheTypeLocation:
            NSParameterAssert(receivedSize == expectedSize);
            if(self.helper.controlView && [self.helper.controlView respondsToSelector:@selector(didFetchVideoFileLength:)]){
                [self.helper.controlView didFetchVideoFileLength:expectedSize];
            }
            if(self.helper.controlView && [self.helper.controlView respondsToSelector:@selector(cacheRangeDidChange:)]){
                NSRange range = NSMakeRange(0, receivedSize);
                [self.helper.controlView cacheRangeDidChange:@[[NSValue valueWithRange:range]]];
            }
            break;

        default:
            break;
    }

}

- (void)videoPlayerManagerPlayProgressDidChange:(JPVideoPlayerManager *)videoPlayerManager
                                 elapsedSeconds:(double)elapsedSeconds
                                   totalSeconds:(double)totalSeconds
                                          error:(NSError *_Nullable)error {
    if(error){
        //TODO handle error.
        return;
    }

    if(self.helper.controlView && [self.helper.controlView respondsToSelector:@selector(playProgressDidChangeElapsedSeconds:totalSeconds:)]){
       [self.helper.controlView playProgressDidChangeElapsedSeconds:elapsedSeconds
                                                       totalSeconds:totalSeconds];
    }
}

@end
