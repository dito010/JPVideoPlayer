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

#import "JPVideoPlayerDetailViewController.h"
#import "JPVideoPlayerKit.h"
#import <JPNavigationControllerKit.h>
#import <Masonry.h>

@interface JPVideoPlayerDetailControlView : JPVideoPlayerControlView

@property (nonatomic, strong) UILabel *label;

@end

@implementation JPVideoPlayerDetailControlView

- (instancetype)initWithControlBar:(UIView <JPVideoPlayerProtocol> *_Nullable)controlBar
                         blurImage:(UIImage *_Nullable)blurImage {
    self = [super initWithControlBar:controlBar
                           blurImage:blurImage];
    if(self){
        self.label = ({
            UILabel *label = [UILabel new];
            label.text = @"测试 Masonry 布局";
            [self addSubview:label];
            label.backgroundColor = [UIColor colorWithWhite:1 alpha:0.7];
            [label mas_makeConstraints:^(MASConstraintMaker *make) {
                make.center.equalTo(self);
            }];

            label;
        });
    }
    return self;
}

@end

@interface JPVideoPlayerDetailViewController ()<JPVideoPlayerDelegate>

@property (weak, nonatomic) IBOutlet UISwitch *muteSwitch;

@property (weak, nonatomic) IBOutlet UISwitch *autoReplaySwitch;

@property (nonatomic, strong) UIView *videoContainer;

@end

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
        videoView.jp_videoPlayerDelegate = self;

        videoView;
    });
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];

    [self.videoContainer jp_resumePlayWithURL:[NSURL URLWithString:self.videoPath]
                           bufferingIndicator:nil
                                  controlView:[[JPVideoPlayerDetailControlView alloc] initWithControlBar:nil blurImage:nil]
                                 progressView:nil
                                configuration:^(UIView *view, JPVideoPlayerModel *playerModel) {
                                    self.muteSwitch.on = ![self.videoContainer jp_muted];
                                }];
}
- (void)viewDidAppear:(BOOL)animated{
    [super viewDidAppear:animated];
}




#pragma mark - Click Events

- (IBAction)muteSwitch:(UISwitch *)sw {
    self.videoContainer.jp_muted = !sw.on;
}

- (IBAction)closeBtnClick:(id)sender {
    [self.navigationController popViewControllerAnimated:YES];
}

- (IBAction)resumePlayDidClick:(id)sender {
    [self.videoContainer jp_resumePlayWithURL:[NSURL URLWithString:self.videoPath]
                           bufferingIndicator:nil
                                  controlView:[[JPVideoPlayerDetailControlView alloc] initWithControlBar:nil blurImage:nil]
                                 progressView:nil
                                configuration:^(UIView *view, JPVideoPlayerModel *playerModel) {
                                    self.muteSwitch.on = ![self.videoContainer jp_muted];
                                }];
}


#pragma mark - JPVideoPlayerDelegate

- (BOOL)shouldAutoReplayForURL:(nonnull NSURL *)videoURL {
    return self.autoReplaySwitch.on;
}

@end
