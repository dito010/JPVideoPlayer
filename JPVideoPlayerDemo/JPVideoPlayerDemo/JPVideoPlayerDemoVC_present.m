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


#import "JPVideoPlayerDemoVC_present.h"
#import "UIView+WebVideoCache.h"

@interface JPVideoPlayerDemoVC_present ()<JPVideoPlayerDelegate>

@property (weak, nonatomic) IBOutlet UIImageView *videoImv;

@property (weak, nonatomic) IBOutlet UISwitch *muteSwitch;

@property (weak, nonatomic) IBOutlet UISwitch *autoReplaySwitch;

@end

#warning 注意: 播放视频的工具类是单例, 单例生命周期为整个应用生命周期, 故而须在 `-viewWillDisappear:`(推荐)或其他方法里 调用 `stopPlay` 方法来停止视频播放, 否则当前控制器销毁了, 视频仍然在后台播放, 虽然看不到图像, 但是能听到声音(如果有).

@implementation JPVideoPlayerDemoVC_present

-(void)viewDidLoad{
    [super viewDidLoad];
    
    self.videoImv.videoPlayerDelegate = self;
}

-(void)viewDidAppear:(BOOL)animated{
    [super viewDidAppear:animated];
    
    [self.videoImv jp_playVideoWithURL:[NSURL URLWithString:_videoPath]];
    [self.videoImv perfersProgressViewColor:[UIColor redColor]];
    self.muteSwitch.on = ![self.videoImv playerIsMute];
}

-(void)viewWillDisappear:(BOOL)animated{
    [super viewWillDisappear:animated];
    
    [self.videoImv stopPlay];
}

-(BOOL)prefersStatusBarHidden{
    return YES;
}


#pragma mark --------------------------------------------------
#pragma mark Click Events

- (IBAction)muteSwitch:(UISwitch *)sw {
    [self.videoImv setPlayerMute:!sw.on];
}

- (IBAction)closeBtnClick:(id)sender {
    [self dismissViewControllerAnimated:YES completion:nil];
}


#pragma mark --------------------------------------------------
#pragma mark JPVideoPlayerDelegate

-(BOOL)shouldAutoReplayAfterPlayCompleteForURL:(NSURL *)videoURL{
    return self.autoReplaySwitch.on;
}


@end
