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

#import "JPVideoPlayerDemoVC_push.h"
#import "UIView+WebVideoCache.h"

@interface JPVideoPlayerDemoVC_push ()<JPVideoPlayerDelegate>

@property (nonatomic, strong) UIImageView *videoImv;

@property (weak, nonatomic) IBOutlet UISwitch *muteSwitch;

@property (weak, nonatomic) IBOutlet UISwitch *autoReplaySwitch;

@property (weak, nonatomic) IBOutlet UISwitch *playOrPauseSwitch;

@end

#warning 注意: 播放视频的工具类是单例, 单例生命周期为整个应用生命周期, 故而须在 `-viewWillDisappear:`(推荐)或其他方法里 调用 `stopPlay` 方法来停止视频播放, 否则当前控制器销毁了, 视频仍然在后台播放, 虽然看不到图像, 但是能听到声音(如果有).

@implementation JPVideoPlayerDemoVC_push

-(void)viewDidLoad{
    [super viewDidLoad];
    
    self.navigationController.navigationBarHidden = YES;
    {
        self.videoImv = [UIImageView new];
        CGRect screenBounds = [UIScreen mainScreen].bounds;
        self.videoImv.frame = CGRectMake(0, 120, screenBounds.size.width, screenBounds.size.width*9.0/16.0);
        [self.view addSubview:self.videoImv];
        self.videoImv.userInteractionEnabled = YES;
        
        UITapGestureRecognizer *tapGestureRecognizer = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(handleTapGesture:)];
        [self.videoImv addGestureRecognizer:tapGestureRecognizer];
    }
    
    self.videoImv.jp_videoPlayerDelegate = self;
    [self.videoImv jp_perfersLandscapeForViewController:self];
}

-(void)viewDidAppear:(BOOL)animated{
    [super viewDidAppear:animated];
    
    [self.videoImv jp_playVideoWithURL:[NSURL URLWithString:_videoPath]];
    
    [self.videoImv jp_perfersPlayingProgressViewColor:[UIColor redColor]];
    [self.videoImv jp_perfersDownloadProgressViewColor:[UIColor lightGrayColor]];
    self.muteSwitch.on = ![self.videoImv jp_playerIsMute];
    self.playOrPauseSwitch.on = self.videoImv.playingStatus == JPVideoPlayerPlayingStatusPlaying ? NO : YES;
}

-(void)viewWillDisappear:(BOOL)animated{
    [super viewWillDisappear:animated];
    
    [self.videoImv jp_stopPlay];
}


#pragma mark --------------------------------------------------
#pragma mark - Tap Event

- (void)handleTapGesture:(UITapGestureRecognizer *)sender {
    if (sender.state == UIGestureRecognizerStateEnded) {
        if (self.videoImv.viewStatus == JPVideoPlayerVideoViewStatusPortrait) {
            [self.videoImv jp_landscape];
        }
        else if (self.videoImv.viewStatus == JPVideoPlayerVideoViewStatusLandscape) {
            [self.videoImv jp_portrait];
        }
    }
}


#pragma mark --------------------------------------------------
#pragma mark Click Events

- (IBAction)muteSwitch:(UISwitch *)sw {
    [self.videoImv jp_setPlayerMute:!sw.on];
}

- (IBAction)closeBtnClick:(id)sender {
    [self.navigationController popViewControllerAnimated:YES];
}

- (IBAction)playOrPause:(id)sender {
    JPVideoPlayerPlayingStatus status = self.videoImv.playingStatus;
    if (status == JPVideoPlayerPlayingStatusPlaying) {
        [self.videoImv jp_pause];
    }
    else{
        [self.videoImv jp_resume];
    }
}


#pragma mark --------------------------------------------------
#pragma mark JPVideoPlayerDelegate

-(BOOL)shouldDownloadVideoForURL:(NSURL *)videoURL{
    return YES;
}

-(BOOL)shouldAutoReplayAfterPlayCompleteForURL:(NSURL *)videoURL{
    return self.autoReplaySwitch.on;
}

-(BOOL)shouldProgressViewOnTop{
    return NO;
}

-(void)playingStatusDidChanged:(JPVideoPlayerPlayingStatus)playingStatus{
}

//-(void)downloadingProgressDidChanged:(CGFloat)downloadingProgress{
//    NSLog(@"%0.2lf", downloadingProgress);
//}
//
//-(void)playingProgressDidChanged:(CGFloat)playingProgress{
//    NSLog(@"%0.2lf", playingProgress);
//}

@end
