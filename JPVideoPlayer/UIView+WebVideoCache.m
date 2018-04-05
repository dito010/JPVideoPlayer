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

@property(nonatomic, strong) UIView<JPVideoPlayerProgressProtocol> *progressView;

@property(nonatomic, strong) UIView<JPVideoPlayerProgressProtocol> *controlView;

@property(nonatomic, strong) UIView<JPVideoPlayerBufferingProtocol> *bufferingIndicator;

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

- (void)setJp_progressView:(UIView <JPVideoPlayerProgressProtocol> *)jp_progressView {
    self.helper.progressView = jp_progressView;
}

- (UIView <JPVideoPlayerProgressProtocol> *)jp_progressView {
    return self.helper.progressView;
}

- (void)setJp_controlView:(UIView <JPVideoPlayerProgressProtocol> *)jp_controlView {
    self.helper.controlView = jp_controlView;
}

- (UIView <JPVideoPlayerProgressProtocol> *)jp_controlView {
    return self.helper.controlView;
}

- (void)setJp_bufferingIndicator:(UIView <JPVideoPlayerBufferingProtocol> *)jp_bufferingIndicator {
    self.helper.bufferingIndicator = jp_bufferingIndicator;
}

- (UIView <JPVideoPlayerBufferingProtocol> *)jp_bufferingIndicator {
    return self.helper.bufferingIndicator;
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
        bufferingIndicator:(UIView <JPVideoPlayerBufferingProtocol> *_Nullable)bufferingIndicator
              progressView:(UIView <JPVideoPlayerProgressProtocol> *_Nullable)progressView {
    if(!progressView && !self.jp_progressView){
        // Use default `JPVideoPlayerProgressView` if no progressView.
        progressView = [JPVideoPlayerProgressView new];
    }
    if(!bufferingIndicator && !self.jp_bufferingIndicator){
        // Use default `JPVideoPlayerBufferingIndicator` if no bufferingIndicator.
        bufferingIndicator = [JPVideoPlayerBufferingIndicator new];
    }
    if(progressView){
        self.jp_progressView = progressView;
    }
    if(bufferingIndicator){
       self.jp_bufferingIndicator = bufferingIndicator;
    }
    [self jp_playVideoWithURL:url options:JPVideoPlayerContinueInBackground |
            JPVideoPlayerLayerVideoGravityResizeAspect |
            JPVideoPlayerMutedPlay];
}

- (void)jp_playVideoWithURL:(NSURL *)url
         bufferingIndicator:(UIView <JPVideoPlayerBufferingProtocol> *_Nullable)bufferingIndicator
                controlView:(UIView <JPVideoPlayerProgressProtocol> *_Nullable)controlView
               progressView:(UIView <JPVideoPlayerProgressProtocol> *_Nullable)progressView {
    if(!bufferingIndicator && !self.jp_bufferingIndicator){
        // Use default `JPVideoPlayerBufferingIndicator` if no bufferingIndicator.
        bufferingIndicator = [JPVideoPlayerBufferingIndicator new];
    }
    if(!controlView && !self.jp_controlView){
        // Use default `JPVideoPlayerControlView` if no controlView.
        controlView = [[JPVideoPlayerControlView alloc] initWithControlBar:nil blurImage:nil];
    }
    if(!progressView && !self.jp_progressView){
        // Use default `JPVideoPlayerProgressView` if no progressView.
        progressView = [JPVideoPlayerProgressView new];
    }
    if(progressView){
        self.jp_progressView = progressView;
    }
    if(bufferingIndicator){
        self.jp_bufferingIndicator = bufferingIndicator;
    }
    if(controlView){
       self.jp_controlView = controlView;
    }
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
        self.helper.videoPlayerView.hidden = NO;
        if(self.jp_bufferingIndicator && !self.jp_bufferingIndicator.superview){
           self.jp_bufferingIndicator.frame = self.bounds;
           [self.helper.videoPlayerView.bufferingIndicatorContainerView addSubview:self.jp_bufferingIndicator];
        }
        if(self.jp_bufferingIndicator){
            [self callStartBufferingDelegate];
        }

        if(self.jp_progressView && !self.jp_progressView.superview){
            self.jp_progressView.frame = self.bounds;
            if(self.jp_progressView && [self.jp_progressView respondsToSelector:@selector(viewWillAddToSuperView:)]){
                [self.jp_progressView viewWillAddToSuperView:self];
            }
            [self.helper.videoPlayerView.progressContainerView addSubview:self.jp_progressView];
        }
        if(self.jp_controlView && !self.jp_controlView.superview){
            self.jp_controlView.frame = self.bounds;
            if(self.jp_controlView && [self.jp_controlView respondsToSelector:@selector(viewWillAddToSuperView:)]){
               [self.jp_controlView viewWillAddToSuperView:self];
            }
            [self.helper.videoPlayerView.controlContainerView addSubview:self.jp_controlView];
            self.helper.videoPlayerView.progressContainerView.alpha = 0;
        }

        [[JPVideoPlayerManager sharedManager] playVideoWithURL:url
                                                   showOnLayer:self.helper.videoPlayerView.videoContainerLayer
                                                       options:options];
    }
    else {
        JPDispatchSyncOnMainQueue(^{
            // TODO: handle error.
//            if (self.jp_videoPlayerDelegate && [self.jp_videoPlayerDelegate respondsToSelector:@selector(downloadProgressDidChangeReceivedSize:expectedSize:error:)]) {
//                NSError *error = [NSError errorWithDomain:JPVideoPlayerErrorDomain code:-1 userInfo:@{NSLocalizedDescriptionKey : @"Try to load a nil url"}];
//                [self.jp_videoPlayerDelegate downloadProgressDidChangeReceivedSize:0 expectedSize:0 error:error];
//            }
        });
    }
}


#pragma mark - Play Control

- (void)jp_seekToTime:(CMTime)time {
    [[JPVideoPlayerManager sharedManager] seekToTime:time];
}

- (void)jp_stopPlay{
    [[JPVideoPlayerManager sharedManager] stopPlay];
    self.helper.videoPlayerView.hidden = YES;
    [self callFinishBufferingDelegate];
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


#pragma mark - Landscape & Portrait Control

- (void)jp_gotoLandscape {
    [self jp_gotoLandscapeAnimated:YES
                        completion:nil];
}

- (void)jp_gotoLandscapeAnimated:(BOOL)animated
                      completion:(dispatch_block_t)completion {
    if (self.jp_viewStatus != JPVideoPlayerVideoViewStatusPortrait) {
        return;
    }

    self.helper.viewStatus = JPVideoPlayerVideoViewStatusAnimating;
    JPVideoPlayerView *videoPlayerView = self.helper.videoPlayerView;
    videoPlayerView.backgroundColor = [UIColor blackColor];
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
    // hide status bar.
    [[UIApplication sharedApplication] setStatusBarHidden:YES withAnimation:UIStatusBarAnimationFade];
#pragma clang diagnostic pop

    CGRect videoPlayerViewFrameInWindow = [self convertRect:videoPlayerView.frame toView:nil];
    [videoPlayerView removeFromSuperview];
    [[UIApplication sharedApplication].keyWindow addSubview:videoPlayerView];
    videoPlayerView.frame = videoPlayerViewFrameInWindow;
    videoPlayerView.controlContainerView.alpha = 0;

    if (animated) {
        [UIView animateWithDuration:0.35
                              delay:0
                            options:UIViewAnimationCurveEaseOut
                         animations:^{
            [self executeLandscape];
        }
        completion:^(BOOL finished) {
            self.helper.viewStatus = JPVideoPlayerVideoViewStatusLandscape;
            if (completion) {
                completion();
            }
            [UIView animateWithDuration:0.5 animations:^{
                videoPlayerView.controlContainerView.alpha = 1;
            }];
        }];
    }
    else{
        [self executeLandscape];
        self.helper.viewStatus = JPVideoPlayerVideoViewStatusLandscape;
        if (completion) {
            completion();
        }
        [UIView animateWithDuration:0.5 animations:^{
            videoPlayerView.controlContainerView.alpha = 0;
        }];
    }
    [self refreshStatusBarOrientation:UIInterfaceOrientationLandscapeRight];
}

- (void)jp_gotoPortrait {
    [self jp_gotoPortraitAnimated:YES
                       completion:nil];
}

- (void)jp_gotoPortraitAnimated:(BOOL)animated
                     completion:(dispatch_block_t)completion{
    if (self.jp_viewStatus != JPVideoPlayerVideoViewStatusLandscape) {
        return;
    }

    JPVideoPlayerView *videoPlayerView = self.helper.videoPlayerView;
    videoPlayerView.backgroundColor = [UIColor clearColor];
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
    // display status bar.
    [[UIApplication sharedApplication] setStatusBarHidden:NO withAnimation:UIStatusBarAnimationFade];
#pragma clang diagnostic pop
    self.helper.viewStatus = JPVideoPlayerVideoViewStatusAnimating;
    videoPlayerView.controlContainerView.alpha = 0;
    if (animated) {
        [UIView animateWithDuration:0.35
                              delay:0
                            options:UIViewAnimationCurveEaseOut
                         animations:^{
            [self executePortrait];
        }
        completion:^(BOOL finished) {
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

- (void)callStartBufferingDelegate {
    if(self.jp_bufferingIndicator && [self.jp_bufferingIndicator respondsToSelector:@selector(didStartBuffering)]){
        [self.jp_bufferingIndicator didStartBuffering];
    }
}

- (void)callFinishBufferingDelegate {
    if(self.jp_bufferingIndicator && [self.jp_bufferingIndicator respondsToSelector:@selector(didFinishBuffering)]){
        [self.jp_bufferingIndicator didFinishBuffering];
    }
}

- (void)finishPortrait {
    JPVideoPlayerView *videoPlayerView = self.helper.videoPlayerView;
    [videoPlayerView removeFromSuperview];
    [self addSubview:videoPlayerView];
    videoPlayerView.frame = self.bounds;
    [[JPVideoPlayerManager sharedManager] videoPlayer].currentPlayerModel.currentPlayerLayer.frame = self.bounds;
    self.helper.viewStatus = JPVideoPlayerVideoViewStatusPortrait;
    [UIView animateWithDuration:0.5 animations:^{
        videoPlayerView.controlContainerView.alpha = 1;
    }];
}

- (void)executePortrait {
    UIView *videoPlayerView = self.helper.videoPlayerView;
    CGRect frame = [self.superview convertRect:self.frame toView:nil];
    videoPlayerView.transform = CGAffineTransformIdentity;
    videoPlayerView.frame = frame;
    [[JPVideoPlayerManager sharedManager] videoPlayer].currentPlayerModel.currentPlayerLayer.frame = self.bounds;
}

- (void)executeLandscape {
    UIView *videoPlayerView = self.helper.videoPlayerView;
    CGRect screenBounds = [[UIScreen mainScreen] bounds];
    CGRect bounds = CGRectMake(0, 0, CGRectGetHeight(screenBounds), CGRectGetWidth(screenBounds));
    CGPoint center = CGPointMake(CGRectGetMidX(screenBounds), CGRectGetMidY(screenBounds));
    videoPlayerView.bounds = bounds;
    videoPlayerView.center = center;
    videoPlayerView.transform = CGAffineTransformMakeRotation(M_PI_2);
    [[JPVideoPlayerManager sharedManager] videoPlayer].currentPlayerModel.currentPlayerLayer.frame = bounds;
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


#pragma mark - JPVideoPlayerManager

- (BOOL)videoPlayerManager:(JPVideoPlayerManager *)videoPlayerManager
 shouldDownloadVideoForURL:(NSURL *)videoURL {
    if (self.jp_videoPlayerDelegate && [self.jp_videoPlayerDelegate respondsToSelector:@selector(shouldDownloadVideoForURL:)]) {
        return [self.jp_videoPlayerDelegate shouldDownloadVideoForURL:videoURL];
    }
    return YES;
}

- (BOOL)videoPlayerManager:(JPVideoPlayerManager *)videoPlayerManager
    shouldAutoReplayForURL:(NSURL *)videoURL {
    if (self.jp_videoPlayerDelegate && [self.jp_videoPlayerDelegate respondsToSelector:@selector(shouldAutoReplayForURL:)]) {
        return [self.jp_videoPlayerDelegate shouldAutoReplayForURL:videoURL];
    }
    return YES;
}

- (void)videoPlayerManager:(JPVideoPlayerManager *)videoPlayerManager
    playerStatusDidChanged:(JPVideoPlayerStatus)playerStatus {
    self.helper.playerStatus = playerStatus;
    JPDebugLog(@"playerStatus: %ld", playerStatus);
    if (self.jp_videoPlayerDelegate && [self.jp_videoPlayerDelegate respondsToSelector:@selector(shouldAutoReplayForURL:)]) {
        [self.jp_videoPlayerDelegate playerStatusDidChanged:playerStatus];
    }
    BOOL needDisplayBufferingIndicator =
            playerStatus == JPVideoPlayerStatusBuffering ||
            playerStatus == JPVideoPlayerStatusUnkown ||
            playerStatus == JPVideoPlayerStatusFailed;
    needDisplayBufferingIndicator ? [self callStartBufferingDelegate] : [self callFinishBufferingDelegate];
}

- (void)videoPlayerManager:(JPVideoPlayerManager *)videoPlayerManager
   didFetchVideoFileLength:(NSUInteger)videoLength {
    if(self.helper.controlView && [self.helper.controlView respondsToSelector:@selector(didFetchVideoFileLength:)]){
        [self.helper.controlView didFetchVideoFileLength:videoLength];
    }
    if(self.helper.progressView && [self.helper.progressView respondsToSelector:@selector(didFetchVideoFileLength:)]){
        [self.helper.progressView didFetchVideoFileLength:videoLength];
    }
}

- (void)videoPlayerManagerDownloadProgressDidChange:(JPVideoPlayerManager *)videoPlayerManager
                                          cacheType:(JPVideoPlayerCacheType)cacheType
                                     fragmentRanges:(NSArray<NSValue *> *_Nullable)fragmentRanges
                                       expectedSize:(NSUInteger)expectedSize
                                              error:(NSError *_Nullable)error {
    if(error){
        // TODO handle error.
        return;
    }
    switch(cacheType){
        case JPVideoPlayerCacheTypeLocation:
        case JPVideoPlayerCacheTypeFull:
            NSParameterAssert(fragmentRanges);
            NSRange range = [fragmentRanges.firstObject rangeValue];
            NSParameterAssert(range.length == expectedSize);
            break;

        default:
            break;
    }
    if(self.helper.controlView && [self.helper.controlView respondsToSelector:@selector(cacheRangeDidChange:)]){
        [self.helper.controlView cacheRangeDidChange:fragmentRanges];
    }
    if(self.helper.progressView && [self.helper.progressView respondsToSelector:@selector(cacheRangeDidChange:)]){
        [self.helper.progressView cacheRangeDidChange:fragmentRanges];
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
    if(self.helper.progressView && [self.helper.progressView respondsToSelector:@selector(playProgressDidChangeElapsedSeconds:totalSeconds:)]){
        [self.helper.progressView playProgressDidChangeElapsedSeconds:elapsedSeconds
                                                        totalSeconds:totalSeconds];
    }
}

@end