/*
 * This file is part of the JPVideoPlayer package.
 * (c) NewPan <13246884282@163.com>
 *
 * For the full copyright and license information, please view the LICENSE
 * file that was distributed with this source code.
 *
 * Click https://github.com/newyjp
 * or http://www.jianshu.com/users/e2f2d779c022/latest_articles to contact me.
 */

#import "UIView+WebVideoCache.h"
#import <objc/runtime.h>
#import "JPVideoPlayer.h"
#import "JPVideoPlayerSupportUtils.h"
#import "JPVideoPlayerControlViews.h"

@interface JPVideoPlayerHelper : NSObject

@property(nonatomic, strong) JPVideoPlayerView *videoPlayerView;

@property(nonatomic, strong) UIView<JPVideoPlayerProtocol> *progressView;

@property(nonatomic, strong) UIView<JPVideoPlayerProtocol> *controlView;

@property(nonatomic, strong) UIView<JPVideoPlayerBufferingProtocol> *bufferingIndicator;

@property(nonatomic, weak) id<JPVideoPlayerDelegate> videoPlayerDelegate;

@property(nonatomic, assign) JPVideoPlayViewInterfaceOrientation viewInterfaceOrientation;

@property(nonatomic, assign)JPVideoPlayerStatus playerStatus;

@property (nonatomic, weak) UIView *playVideoView;

@property(nonatomic, copy) NSURL *videoURL;

@end

@implementation JPVideoPlayerHelper

- (instancetype)initWithPlayVideoView:(UIView *)playVideoView {
    self = [super init];
    if(self){
       _playVideoView = playVideoView;
    }
    return self;
}

- (JPVideoPlayViewInterfaceOrientation)viewInterfaceOrientation {
    if(_viewInterfaceOrientation == JPVideoPlayViewInterfaceOrientationUnknown){
       CGSize referenceSize = self.playVideoView.window.bounds.size;
       _viewInterfaceOrientation = referenceSize.width < referenceSize.height ? JPVideoPlayViewInterfaceOrientationPortrait :
               JPVideoPlayViewInterfaceOrientationLandscape;
    }
    return _viewInterfaceOrientation;
}

- (JPVideoPlayerView *)videoPlayerView {
    if(!_videoPlayerView){
        BOOL autoHide = YES;
        if (_playVideoView.jp_videoPlayerDelegate && [_playVideoView.jp_videoPlayerDelegate respondsToSelector:@selector(shouldAutoHideControlContainerViewWhenUserTapping)]) {
            autoHide = [_playVideoView.jp_videoPlayerDelegate shouldAutoHideControlContainerViewWhenUserTapping];
        }
        _videoPlayerView = [[JPVideoPlayerView alloc] initWithNeedAutoHideControlViewWhenUserTapping:autoHide];
    }
    return _videoPlayerView;
}

@end

@interface UIView()

@property(nonatomic, readonly)JPVideoPlayerHelper *helper;

@end

@implementation UIView (WebVideoCache)

#pragma mark - Properties

- (JPVideoPlayViewInterfaceOrientation)jp_viewInterfaceOrientation {
    return self.helper.viewInterfaceOrientation;
}

- (JPVideoPlayerStatus)jp_playerStatus {
    return self.helper.playerStatus;
}

- (JPVideoPlayerView *)jp_videoPlayerView {
    return self.helper.videoPlayerView;
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

- (NSURL *)jp_videoURL {
    return self.helper.videoURL;
}

- (void)setJp_videoURL:(NSURL *)jp_videoURL {
    self.helper.videoURL = jp_videoURL.copy;
}


#pragma mark - Play Video Methods

- (void)jp_playVideoWithURL:(NSURL *)url {
    [self jp_playVideoWithURL:url
                      options:JPVideoPlayerContinueInBackground |
                              JPVideoPlayerLayerVideoGravityResizeAspect
                configuration:nil];
}

- (void)jp_playVideoMuteWithURL:(NSURL *)url
             bufferingIndicator:(UIView <JPVideoPlayerBufferingProtocol> *_Nullable)bufferingIndicator
                   progressView:(UIView <JPVideoPlayerProtocol> *_Nullable)progressView
                  configuration:(JPPlayVideoConfiguration _Nullable)configuration {
    [self setBufferingIndicator:bufferingIndicator
                    controlView:nil
                   progressView:progressView
             needSetControlView:NO];
    [self jp_stopPlay];
    [self jp_playVideoWithURL:url
                      options:JPVideoPlayerContinueInBackground |
                              JPVideoPlayerLayerVideoGravityResizeAspect |
                              JPVideoPlayerMutedPlay
                configuration:configuration];
}

- (void)jp_resumeMutePlayWithURL:(NSURL *)url
              bufferingIndicator:(UIView <JPVideoPlayerBufferingProtocol> *_Nullable)bufferingIndicator
                    progressView:(UIView <JPVideoPlayerProtocol> *_Nullable)progressView
                   configuration:(JPPlayVideoConfiguration _Nullable)configuration {
    [self setBufferingIndicator:bufferingIndicator
                    controlView:nil
                   progressView:progressView
             needSetControlView:NO];
    [self jp_resumePlayWithURL:url
                       options:JPVideoPlayerContinueInBackground |
                               JPVideoPlayerLayerVideoGravityResizeAspect |
                               JPVideoPlayerMutedPlay
                 configuration:configuration];
}

- (void)jp_playVideoWithURL:(NSURL *)url
         bufferingIndicator:(UIView <JPVideoPlayerBufferingProtocol> *_Nullable)bufferingIndicator
                controlView:(UIView <JPVideoPlayerProtocol> *_Nullable)controlView
               progressView:(UIView <JPVideoPlayerProtocol> *_Nullable)progressView
              configuration:(JPPlayVideoConfiguration _Nullable)configuration {
    [self setBufferingIndicator:bufferingIndicator
                    controlView:controlView
                   progressView:progressView
             needSetControlView:YES];
    [self jp_stopPlay];
    [self jp_playVideoWithURL:url
                      options:JPVideoPlayerContinueInBackground |
                              JPVideoPlayerLayerVideoGravityResizeAspect
                configuration:configuration];
}

- (void)jp_resumePlayWithURL:(NSURL *)url
          bufferingIndicator:(UIView <JPVideoPlayerBufferingProtocol> *_Nullable)bufferingIndicator
                 controlView:(UIView <JPVideoPlayerProtocol> *_Nullable)controlView
                progressView:(UIView <JPVideoPlayerProtocol> *_Nullable)progressView
               configuration:(JPPlayVideoConfiguration _Nullable)configuration {
    [self setBufferingIndicator:bufferingIndicator
                    controlView:controlView
                   progressView:progressView
             needSetControlView:YES];
    [self jp_resumePlayWithURL:url
                       options:JPVideoPlayerContinueInBackground |
                               JPVideoPlayerLayerVideoGravityResizeAspect
                 configuration:configuration];
}

- (void)setBufferingIndicator:(UIView <JPVideoPlayerBufferingProtocol> *_Nullable)bufferingIndicator
                  controlView:(UIView <JPVideoPlayerProtocol> *_Nullable)controlView
                 progressView:(UIView <JPVideoPlayerProtocol> *_Nullable)progressView
              needSetControlView:(BOOL)needSetControlView {
    // should show default.
    BOOL showDefaultView = YES;
    if (self.jp_videoPlayerDelegate && [self.jp_videoPlayerDelegate respondsToSelector:@selector(shouldShowDefaultControlAndIndicatorViews)]) {
        showDefaultView = [self.jp_videoPlayerDelegate shouldShowDefaultControlAndIndicatorViews];
    }
    // user update progressView.
    if(progressView && self.jp_progressView){
        [self.jp_progressView removeFromSuperview];
    }
    if(showDefaultView && !progressView && !self.jp_progressView){
        // Use default `JPVideoPlayerProgressView` if no progressView.
        progressView = [JPVideoPlayerProgressView new];
    }
    if(progressView){
        self.jp_progressView = progressView;
    }

    // user update bufferingIndicator.
    if(bufferingIndicator && self.jp_bufferingIndicator){
        [self.jp_bufferingIndicator removeFromSuperview];
    }
    if(showDefaultView && !bufferingIndicator && !self.jp_bufferingIndicator){
        // Use default `JPVideoPlayerBufferingIndicator` if no bufferingIndicator.
        bufferingIndicator = [JPVideoPlayerBufferingIndicator new];
    }
    if(bufferingIndicator){
        self.jp_bufferingIndicator = bufferingIndicator;
    }

    if(needSetControlView){
        //before setting controllerView userInteractionEnabled should be enabled.
        self.userInteractionEnabled = YES;
        // user update controlView.
        if(controlView && self.jp_controlView){
            [self.jp_controlView removeFromSuperview];
        }
        if(showDefaultView && !controlView && !self.jp_controlView){
            // Use default `JPVideoPlayerControlView` if no controlView.
            controlView = [[JPVideoPlayerControlView alloc] initWithControlBar:nil blurImage:nil];
        }
        if(controlView){
            self.jp_controlView = controlView;
        }
    }
}

- (void)jp_playVideoWithURL:(NSURL *)url
                    options:(JPVideoPlayerOptions)options
              configuration:(JPPlayVideoConfiguration _Nullable)configuration {
    [self playVideoWithURL:url
                   options:options
   configurationCompletion:configuration
                  isResume:NO];
}

- (void)jp_resumePlayWithURL:(NSURL *)url
                     options:(JPVideoPlayerOptions)options
               configuration:(JPPlayVideoConfiguration _Nullable)configuration {
    [self playVideoWithURL:url
                   options:options
   configurationCompletion:configuration
                  isResume:YES];
}

- (void)playVideoWithURL:(NSURL *)url
                     options:(JPVideoPlayerOptions)options
     configurationCompletion:(JPPlayVideoConfiguration _Nullable)configurationCompletion
                isResume:(BOOL)isResume {
    JPMainThreadAssert;
    self.jp_videoURL = url;
    if (url) {
        [JPVideoPlayerManager sharedManager].delegate = self;
        self.helper.viewInterfaceOrientation = JPVideoPlayViewInterfaceOrientationPortrait;

        // handler the reuse of progressView in `UITableView`.
        if(self.jp_progressView && [self.jp_progressView respondsToSelector:@selector(viewWillPrepareToReuse)]){
            [self.jp_progressView viewWillPrepareToReuse];
        }
        if(self.jp_controlView && [self.jp_controlView respondsToSelector:@selector(viewWillPrepareToReuse)]){
            [self.jp_controlView viewWillPrepareToReuse];
        }
        [self callFinishBufferingDelegate];
        // Add progressView and controlView if need.
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
        if(!self.helper.videoPlayerView.superview){
            [self addSubview:self.helper.videoPlayerView];
        }
        self.helper.videoPlayerView.frame = self.bounds;
        self.helper.videoPlayerView.backgroundColor = [UIColor clearColor];
        if (self.jp_videoPlayerDelegate && [self.jp_videoPlayerDelegate respondsToSelector:@selector(shouldShowBlackBackgroundBeforePlaybackStart)]) {
            BOOL shouldShow = [self.jp_videoPlayerDelegate shouldShowBlackBackgroundBeforePlaybackStart];
            if(shouldShow){
                self.helper.videoPlayerView.backgroundColor = [UIColor blackColor];
            }
        }

        // nobody retain this block.
        JPPlayVideoConfiguration internalConfigFinishedBlock = ^(UIView *view, JPVideoPlayerModel *model){
            NSParameterAssert(model);
            if(configurationCompletion){
                configurationCompletion(self, model);
            }
        };
        
        if(!isResume){
            [[JPVideoPlayerManager sharedManager] playVideoWithURL:url
                                                       showOnLayer:self.helper.videoPlayerView.videoContainerLayer
                                                           options:options
                                           configurationCompletion:internalConfigFinishedBlock];
            [self callOrientationDelegateWithInterfaceOrientation:self.jp_viewInterfaceOrientation];
        }
        else {
            [[JPVideoPlayerManager sharedManager] resumePlayWithURL:url
                                                        showOnLayer:self.helper.videoPlayerView.videoContainerLayer
                                                            options:options
                                            configurationCompletion:internalConfigFinishedBlock];
        }
    }
    else {
        JPDispatchSyncOnMainQueue(^{
            if (self.jp_videoPlayerDelegate && [self.jp_videoPlayerDelegate respondsToSelector:@selector(playVideoFailWithError:videoURL:)]) {
                [self.jp_videoPlayerDelegate playVideoFailWithError:JPErrorWithDescription(@"Try to play video with a invalid url")
                                                           videoURL:url];
            }
        });
    }
}


#pragma mark - Playback Control

- (void)setJp_rate:(float)jp_rate {
    JPVideoPlayerManager.sharedManager.rate = jp_rate;
}

- (float)jp_rate {
    return JPVideoPlayerManager.sharedManager.rate;
}

- (void)setJp_muted:(BOOL)jp_muted {
    JPVideoPlayerManager.sharedManager.muted = jp_muted;
}

- (BOOL)jp_muted {
    return JPVideoPlayerManager.sharedManager.muted;
}

- (void)setJp_volume:(float)jp_volume {
    JPVideoPlayerManager.sharedManager.volume = jp_volume;
}

- (float)jp_volume {
    return JPVideoPlayerManager.sharedManager.volume;
}

- (void)jp_seekToTime:(CMTime)time {
    [[JPVideoPlayerManager sharedManager] seekToTime:time];
}

- (NSTimeInterval)jp_elapsedSeconds {
    return [JPVideoPlayerManager.sharedManager elapsedSeconds];
}

- (NSTimeInterval)jp_totalSeconds {
    return [JPVideoPlayerManager.sharedManager totalSeconds];
}

- (void)jp_pause {
    [[JPVideoPlayerManager sharedManager] pause];
}

- (void)jp_resume {
    [[JPVideoPlayerManager sharedManager] resume];
}

- (CMTime)jp_currentTime {
    return JPVideoPlayerManager.sharedManager.currentTime;
}

- (void)jp_stopPlay {
    [[JPVideoPlayerManager sharedManager] stopPlay];
    self.helper.videoPlayerView.hidden = YES;
    self.helper.videoPlayerView.backgroundColor = [UIColor clearColor];
    [self callFinishBufferingDelegate];
}


#pragma mark - Landscape & Portrait Control

- (void)jp_gotoLandscape {
    [self jp_gotoLandscapeAnimated:YES
                        completion:nil];
}

- (void)jp_gotoLandscapeAnimated:(BOOL)flag
                      completion:(dispatch_block_t)completion {
    if (self.jp_viewInterfaceOrientation != JPVideoPlayViewInterfaceOrientationPortrait) {
        return;
    }

    self.helper.viewInterfaceOrientation = JPVideoPlayViewInterfaceOrientationLandscape;
    JPVideoPlayerView *videoPlayerView = self.helper.videoPlayerView;
    videoPlayerView.backgroundColor = [UIColor blackColor];

    CGRect videoPlayerViewFrameInWindow = [self convertRect:videoPlayerView.frame toView:nil];
    [videoPlayerView removeFromSuperview];
    [[UIApplication sharedApplication].keyWindow addSubview:videoPlayerView];
    videoPlayerView.frame = videoPlayerViewFrameInWindow;
    videoPlayerView.controlContainerView.alpha = 0;

    if (flag) {
        [UIView animateWithDuration:0.35
                              delay:0
                            options:UIViewAnimationOptionCurveEaseOut
                         animations:^{
                             [self executeLandscape];
                         }
                         completion:^(BOOL finished) {
                             if (completion) {
                                 completion();
                             }
                             [UIView animateWithDuration:0.5 animations:^{
                                 videoPlayerView.controlContainerView.alpha = 1;
                             }];
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
                             // hide status bar.
                             [[UIApplication sharedApplication] setStatusBarHidden:YES withAnimation:UIStatusBarAnimationFade];
#pragma clang diagnostic pop
                         }];
    }
    else{
        [self executeLandscape];
        if (completion) {
            completion();
        }
        [UIView animateWithDuration:0.5 animations:^{
            videoPlayerView.controlContainerView.alpha = 0;
        }];
    }
    [self refreshStatusBarOrientation:UIInterfaceOrientationLandscapeRight];
    [self callOrientationDelegateWithInterfaceOrientation:JPVideoPlayViewInterfaceOrientationLandscape];
}

- (void)jp_gotoPortrait {
    [self jp_gotoPortraitAnimated:YES
                       completion:nil];
}

- (void)jp_gotoPortraitAnimated:(BOOL)flag
                     completion:(dispatch_block_t)completion{
    if (self.jp_viewInterfaceOrientation != JPVideoPlayViewInterfaceOrientationLandscape) {
        return;
    }

    self.helper.viewInterfaceOrientation = JPVideoPlayViewInterfaceOrientationPortrait;
    JPVideoPlayerView *videoPlayerView = self.helper.videoPlayerView;
    videoPlayerView.backgroundColor = [UIColor blackColor];
    if (self.jp_videoPlayerDelegate && [self.jp_videoPlayerDelegate respondsToSelector:@selector(shouldShowBlackBackgroundWhenPlaybackStart)]) {
        BOOL shouldShow = [self.jp_videoPlayerDelegate shouldShowBlackBackgroundWhenPlaybackStart];
        videoPlayerView.backgroundColor = shouldShow ? [UIColor blackColor] : [UIColor clearColor];
    }
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
    // display status bar.
    [[UIApplication sharedApplication] setStatusBarHidden:NO withAnimation:UIStatusBarAnimationFade];
#pragma clang diagnostic pop
    videoPlayerView.controlContainerView.alpha = 0;
    if (flag) {
        [UIView animateWithDuration:0.35
                              delay:0
                            options:UIViewAnimationOptionCurveEaseOut
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
    [self callOrientationDelegateWithInterfaceOrientation:JPVideoPlayViewInterfaceOrientationPortrait];
}


#pragma mark - Private

- (void)callOrientationDelegateWithInterfaceOrientation:(JPVideoPlayViewInterfaceOrientation)interfaceOrientation {
    if(self.jp_controlView && [self.jp_controlView respondsToSelector:@selector(videoPlayerInterfaceOrientationDidChange:videoURL:)]){
        [self.jp_controlView videoPlayerInterfaceOrientationDidChange:interfaceOrientation videoURL:self.jp_videoURL];
    }
    if(self.jp_progressView && [self.jp_progressView respondsToSelector:@selector(videoPlayerInterfaceOrientationDidChange:videoURL:)]){
        [self.jp_progressView videoPlayerInterfaceOrientationDidChange:interfaceOrientation videoURL:self.jp_videoURL];
    }
}

- (void)callStartBufferingDelegate {
    if(self.jp_bufferingIndicator && [self.jp_bufferingIndicator respondsToSelector:@selector(didStartBufferingVideoURL:)]){
        [self.jp_bufferingIndicator didStartBufferingVideoURL:self.jp_videoURL];
    }
}

- (void)callFinishBufferingDelegate {
    if(self.jp_bufferingIndicator && [self.jp_bufferingIndicator respondsToSelector:@selector(didFinishBufferingVideoURL:)]){
        [self.jp_bufferingIndicator didFinishBufferingVideoURL:self.jp_videoURL];
    }
}

- (void)finishPortrait {
    JPVideoPlayerView *videoPlayerView = self.helper.videoPlayerView;
    [videoPlayerView removeFromSuperview];
    [self addSubview:videoPlayerView];
    videoPlayerView.frame = self.bounds;
    [[JPVideoPlayerManager sharedManager] videoPlayer].playerModel.playerLayer.frame = self.bounds;
    [UIView animateWithDuration:0.5 animations:^{
        videoPlayerView.controlContainerView.alpha = 1;
    }];
}

- (void)executePortrait {
    UIView *videoPlayerView = self.helper.videoPlayerView;
    CGRect frame = [self.superview convertRect:self.frame toView:nil];
    videoPlayerView.transform = CGAffineTransformIdentity;
    videoPlayerView.frame = frame;
    [[JPVideoPlayerManager sharedManager] videoPlayer].playerModel.playerLayer.frame = self.bounds;
}

- (void)executeLandscape {
    UIView *videoPlayerView = self.helper.videoPlayerView;
    CGRect screenBounds = [[UIScreen mainScreen] bounds];
    CGRect bounds = CGRectMake(0, 0, CGRectGetHeight(screenBounds), CGRectGetWidth(screenBounds));
    CGPoint center = CGPointMake(CGRectGetMidX(screenBounds), CGRectGetMidY(screenBounds));
    videoPlayerView.bounds = bounds;
    videoPlayerView.center = center;
    videoPlayerView.transform = CGAffineTransformMakeRotation(M_PI_2);
    [[JPVideoPlayerManager sharedManager] videoPlayer].playerModel.playerLayer.frame = bounds;
}

- (void)refreshStatusBarOrientation:(UIInterfaceOrientation)interfaceOrientation {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
    [[UIApplication sharedApplication] setStatusBarOrientation:interfaceOrientation animated:YES];
#pragma clang diagnostic pop
}

- (JPVideoPlayerHelper *)helper {
    JPVideoPlayerHelper *helper = objc_getAssociatedObject(self, _cmd);
    if(!helper){
        helper = [[JPVideoPlayerHelper alloc] initWithPlayVideoView:self];
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
    if(playerStatus == JPVideoPlayerStatusPlaying){
        self.helper.videoPlayerView.backgroundColor = [UIColor blackColor];
        if (self.jp_videoPlayerDelegate && [self.jp_videoPlayerDelegate respondsToSelector:@selector(shouldShowBlackBackgroundWhenPlaybackStart)]) {
            BOOL shouldShow = [self.jp_videoPlayerDelegate shouldShowBlackBackgroundWhenPlaybackStart];
            self.helper.videoPlayerView.backgroundColor = shouldShow ? [UIColor blackColor] : [UIColor clearColor];
        }
    }
    self.helper.playerStatus = playerStatus;
    // JPDebugLog(@"playerStatus: %ld", playerStatus);
    if (self.jp_videoPlayerDelegate && [self.jp_videoPlayerDelegate respondsToSelector:@selector(playerStatusDidChanged:)]) {
        [self.jp_videoPlayerDelegate playerStatusDidChanged:playerStatus];
    }
    BOOL needDisplayBufferingIndicator =
            playerStatus == JPVideoPlayerStatusBuffering ||
                    playerStatus == JPVideoPlayerStatusUnknown ||
                    playerStatus == JPVideoPlayerStatusFailed;
    needDisplayBufferingIndicator ? [self callStartBufferingDelegate] : [self callFinishBufferingDelegate];
    if(self.jp_controlView && [self.jp_controlView respondsToSelector:@selector(videoPlayerStatusDidChange:videoURL:)]){
        [self.jp_controlView videoPlayerStatusDidChange:playerStatus videoURL:self.jp_videoURL];
    }
    if(self.jp_progressView && [self.jp_progressView respondsToSelector:@selector(videoPlayerStatusDidChange:videoURL:)]){
        [self.jp_progressView videoPlayerStatusDidChange:playerStatus videoURL:self.jp_videoURL];
    }
}

- (void)videoPlayerManager:(JPVideoPlayerManager *)videoPlayerManager
   didFetchVideoFileLength:(NSUInteger)videoLength {
    if(self.helper.controlView && [self.helper.controlView respondsToSelector:@selector(didFetchVideoFileLength:videoURL:)]){
        [self.helper.controlView didFetchVideoFileLength:videoLength videoURL:self.jp_videoURL];
    }
    if(self.helper.progressView && [self.helper.progressView respondsToSelector:@selector(didFetchVideoFileLength:videoURL:)]){
        [self.helper.progressView didFetchVideoFileLength:videoLength videoURL:self.jp_videoURL];
    }
}

- (void)videoPlayerManagerDownloadProgressDidChange:(JPVideoPlayerManager *)videoPlayerManager
                                          cacheType:(JPVideoPlayerCacheType)cacheType
                                     fragmentRanges:(NSArray<NSValue *> *_Nullable)fragmentRanges
                                       expectedSize:(NSUInteger)expectedSize
                                              error:(NSError *_Nullable)error {
    if(error){
        if (self.jp_videoPlayerDelegate && [self.jp_videoPlayerDelegate respondsToSelector:@selector(playVideoFailWithError:videoURL:)]) {
            [self.jp_videoPlayerDelegate playVideoFailWithError:JPErrorWithDescription(@"Try to play video with a invalid url")
                                                       videoURL:videoPlayerManager.managerModel.videoURL];
        }
        return;
    }
    switch(cacheType){
        case JPVideoPlayerCacheTypeLocation:
            NSParameterAssert(fragmentRanges);
            NSRange range = [fragmentRanges.firstObject rangeValue];
            NSParameterAssert(range.length == expectedSize);
            break;

        default:
            break;
    }
    if(self.helper.controlView && [self.helper.controlView respondsToSelector:@selector(cacheRangeDidChange:videoURL:)]){
        [self.helper.controlView cacheRangeDidChange:fragmentRanges videoURL:self.jp_videoURL];
    }
    if(self.helper.progressView && [self.helper.progressView respondsToSelector:@selector(cacheRangeDidChange:videoURL:)]){
        [self.helper.progressView cacheRangeDidChange:fragmentRanges videoURL:self.jp_videoURL];
    }
}

- (void)videoPlayerManagerPlayProgressDidChange:(JPVideoPlayerManager *)videoPlayerManager
                                 elapsedSeconds:(double)elapsedSeconds
                                   totalSeconds:(double)totalSeconds
                                          error:(NSError *_Nullable)error {
    if(error){
        if (self.jp_videoPlayerDelegate && [self.jp_videoPlayerDelegate respondsToSelector:@selector(playVideoFailWithError:videoURL:)]) {
            [self.jp_videoPlayerDelegate playVideoFailWithError:JPErrorWithDescription(@"Try to play video with a invalid url")
                                                       videoURL:videoPlayerManager.managerModel.videoURL];
        }
        return;
    }
    if(self.helper.controlView && [self.helper.controlView respondsToSelector:@selector(playProgressDidChangeElapsedSeconds:totalSeconds:videoURL:)]){
        [self.helper.controlView playProgressDidChangeElapsedSeconds:elapsedSeconds
                                                        totalSeconds:totalSeconds
                                                            videoURL:self.jp_videoURL];
    }
    if(self.helper.progressView && [self.helper.progressView respondsToSelector:@selector(playProgressDidChangeElapsedSeconds:totalSeconds:videoURL:)]){
        [self.helper.progressView playProgressDidChangeElapsedSeconds:elapsedSeconds
                                                         totalSeconds:totalSeconds
                                                             videoURL:self.jp_videoURL];
    }
}

- (BOOL)videoPlayerManager:(JPVideoPlayerManager *)videoPlayerManager
shouldPausePlaybackWhenApplicationWillResignActiveForURL:(NSURL *)videoURL {
    if (self.jp_videoPlayerDelegate && [self.jp_videoPlayerDelegate respondsToSelector:@selector(shouldPausePlaybackWhenApplicationWillResignActiveForURL:)]) {
        return [self.jp_videoPlayerDelegate shouldPausePlaybackWhenApplicationWillResignActiveForURL:videoURL];
    }
    return NO;
}

- (BOOL)videoPlayerManager:(JPVideoPlayerManager *)videoPlayerManager
shouldPausePlaybackWhenApplicationDidEnterBackgroundForURL:(NSURL *)videoURL {
    if (self.jp_videoPlayerDelegate && [self.jp_videoPlayerDelegate respondsToSelector:@selector(shouldPausePlaybackWhenApplicationDidEnterBackgroundForURL:)]) {
        return [self.jp_videoPlayerDelegate shouldPausePlaybackWhenApplicationDidEnterBackgroundForURL:videoURL];
    }
    return YES;
}

- (BOOL)videoPlayerManager:(JPVideoPlayerManager *)videoPlayerManager
shouldResumePlaybackWhenApplicationDidBecomeActiveFromBackgroundForURL:(NSURL *)videoURL {
    if (self.jp_videoPlayerDelegate && [self.jp_videoPlayerDelegate respondsToSelector:@selector(shouldResumePlaybackWhenApplicationDidBecomeActiveFromBackgroundForURL:)]) {
        return [self.jp_videoPlayerDelegate shouldResumePlaybackWhenApplicationDidBecomeActiveFromBackgroundForURL:videoURL];
    }
    return YES;
}

- (BOOL)videoPlayerManager:(JPVideoPlayerManager *)videoPlayerManager
shouldResumePlaybackWhenApplicationDidBecomeActiveFromResignActiveForURL:(NSURL *)videoURL {
    if (self.jp_videoPlayerDelegate && [self.jp_videoPlayerDelegate respondsToSelector:@selector(shouldResumePlaybackWhenApplicationDidBecomeActiveFromResignActiveForURL:)]) {
        return [self.jp_videoPlayerDelegate shouldResumePlaybackWhenApplicationDidBecomeActiveFromResignActiveForURL:videoURL];
    }
    return NO;
}

- (BOOL)videoPlayerManager:(JPVideoPlayerManager *)videoPlayerManager
shouldTranslateIntoPlayVideoFromResumePlayForURL:(NSURL *)videoURL {
    if (self.jp_videoPlayerDelegate && [self.jp_videoPlayerDelegate respondsToSelector:@selector(shouldTranslateIntoPlayVideoFromResumePlayForURL:)]) {
        return [self.jp_videoPlayerDelegate shouldTranslateIntoPlayVideoFromResumePlayForURL:videoURL];
    }
    return YES;
}

- (BOOL)videoPlayerManager:(JPVideoPlayerManager *)videoPlayerManager
shouldPausePlaybackWhenReceiveAudioSessionInterruptionNotificationForURL:(NSURL *)videoURL {
    if (self.jp_videoPlayerDelegate && [self.jp_videoPlayerDelegate respondsToSelector:@selector(shouldPausePlaybackWhenReceiveAudioSessionInterruptionNotificationForURL:)]) {
        return [self.jp_videoPlayerDelegate shouldPausePlaybackWhenReceiveAudioSessionInterruptionNotificationForURL:videoURL];
    }
    return YES;
}

- (NSString *)videoPlayerManagerPreferAudioSessionCategory:(JPVideoPlayerManager *)videoPlayerManager {
    if (self.jp_videoPlayerDelegate && [self.jp_videoPlayerDelegate respondsToSelector:@selector(preferAudioSessionCategory)]) {
        return [self.jp_videoPlayerDelegate preferAudioSessionCategory];
    }
    return AVAudioSessionCategoryPlayback;
}

- (BOOL)videoPlayerManager:(JPVideoPlayerManager *)videoPlayerManager
shouldResumePlaybackFromPlaybackRecordForURL:(NSURL *)videoURL
            elapsedSeconds:(NSTimeInterval)elapsedSeconds {
    BOOL shouldResume = NO;
    if (self.jp_videoPlayerDelegate && [self.jp_videoPlayerDelegate respondsToSelector:@selector(shouldResumePlaybackFromPlaybackRecordForURL:elapsedSeconds:)]) {
        shouldResume = [self.jp_videoPlayerDelegate shouldResumePlaybackFromPlaybackRecordForURL:videoURL
                                                                   elapsedSeconds:elapsedSeconds];
    }
    return shouldResume;
}

@end
