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

@interface JPVideoPlayerDemoVC_present ()


@property (weak, nonatomic) IBOutlet UIImageView *videoImv;

@property (weak, nonatomic) IBOutlet UISwitch *sw;

@end

#warning 注意: 播放视频的工具类是单例, 单例生命周期为整个应用生命周期, 故而须在 `-viewWillDisappear:`(建议)或其他方法里 调用 `stopPlay` 方法来停止视频播放.

@implementation JPVideoPlayerDemoVC_present

-(void)viewDidAppear:(BOOL)animated{
    [super viewDidAppear:animated];
    
    [self.videoImv jp_playVideoWithURL:[NSURL URLWithString:_videoPath]];
    [self.videoImv perfersProgressViewColor:[UIColor redColor]];
    self.sw.on = ![self.videoImv playerIsMute];
}

-(void)viewWillDisappear:(BOOL)animated{
    [super viewWillDisappear:animated];
    
    [self.videoImv stopPlay];
}

- (IBAction)muteSwitch:(UISwitch *)sw {
    [self.videoImv setPlayerMute:!sw.on];
}

-(BOOL)prefersStatusBarHidden{
    return YES;
}

- (IBAction)closeBtnClick:(id)sender {
    [self dismissViewControllerAnimated:YES completion:nil];
}

@end
