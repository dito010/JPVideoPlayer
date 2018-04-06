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
#import "JPVideoPlayerDetailViewController.h"
#import "UIView+WebVideoCache.h"
#import <JPNavigationControllerKit.h>

@interface JPVideoPlayerDetailViewController ()<JPVideoPlayerDelegate>

@property (weak, nonatomic) IBOutlet UISwitch *muteSwitch;

@property (weak, nonatomic) IBOutlet UISwitch *autoReplaySwitch;

@property (nonatomic, strong) UIView *videoContainer;

@end

#warning 注意: 播放视频的工具类是单例, 单例生命周期为整个应用生命周期, 故而须在 `-viewWillDisappear:`(推荐)或其他方法里 调用 `stopPlay` 方法来停止视频播放, 否则当前控制器销毁了, 视频仍然在后台播放, 虽然看不到图像, 但是能听到声音(如果有).
#warning 由于 frame 和 Autolayout 的冲突关系, 所以建议需要横屏的那个视频容器 view 用 frame 的方式进行布局.

@implementation JPVideoPlayerDetailViewController

- (void)dealloc{
    NSLog(@"JPVideoPlayerDetailViewController 释放了");
}

- (void)viewDidLoad{
    [super viewDidLoad];
    
    self.navigationController.navigationBarHidden = YES;
//    self.navigationController.jp_closePopForCurrentViewController = YES;
    
    // 使用 `JPNavigationController` 处理 pop 手势导致 `AVPlayer` 播放器播放视频卡顿.
    self.navigationController.jp_useCustomPopAnimationForCurrentViewController = YES;

    self.videoContainer = ({
        UIView *videoView = [UIView new];
        videoView.backgroundColor = [UIColor clearColor];
        CGFloat screenWid = [UIScreen mainScreen].bounds.size.width;
        videoView.frame = CGRectMake(0, 100, screenWid, screenWid * 9.0 / 16.0);
        [self.view addSubview:videoView];

        videoView;
    });
    
    self.videoContainer.jp_videoPlayerDelegate = self;
}

- (void)viewDidAppear:(BOOL)animated{
    [super viewDidAppear:animated];
    [self.videoContainer jp_playVideoWithURL:[NSURL URLWithString:self.videoPath]
                          bufferingIndicator:nil
                                 controlView:nil
                                progressView:nil];
    
//    [self.videoContainer jp_perfersPlayingProgressViewColor:[UIColor redColor]];
//    [self.videoContainer jp_perfersDownloadProgressViewColor:[UIColor lightGrayColor]];
    self.muteSwitch.on = ![self.videoContainer jp_playerIsMute];
}

- (void)viewWillDisappear:(BOOL)animated{
    [super viewWillDisappear:animated];
    
    [self.videoContainer jp_stopPlay];
}


#pragma mark - Click Events

- (IBAction)muteSwitch:(UISwitch *)sw {
    [self.videoContainer jp_setPlayerMute:!sw.on];
}

- (IBAction)closeBtnClick:(id)sender {
    [self.navigationController popViewControllerAnimated:YES];
}


#pragma mark - JPVideoPlayerDelegate

- (BOOL)shouldDownloadVideoForURL:(NSURL *)videoURL{
    return YES;
}

- (BOOL)shouldAutoReplayAfterPlayCompleteForURL:(NSURL *)videoURL{
    return self.autoReplaySwitch.on;
}

- (BOOL)shouldProgressViewOnTop{
    return NO;
}

- (void)playingStatusDidChanged:(JPVideoPlayerStatus)playingStatus{
}

//- (void)downloadingProgressDidChanged:(CGFloat)downloadingProgress{
//    NSLog(@"%0.2lf", downloadingProgress);
//}
//
//- (void)playingProgressDidChanged:(CGFloat)playingProgress{
//    NSLog(@"%0.2lf", playingProgress);
//}

@end
