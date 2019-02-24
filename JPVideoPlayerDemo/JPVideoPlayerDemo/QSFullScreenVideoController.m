//
//  QSFullScreenVideoController.m
//  ComponentDemo
//
//  Created by Xuzixiang on 2018/6/15.
//  Copyright © 2018年 frankxzx. All rights reserved.
//

#import "QSFullScreenVideoController.h"
#import "JPVideoPlayerKit.h"

@interface QSFullScreenVideoController () <JPVideoPlayerDelegate>

@property (nonatomic, strong) UIView *videoContainer;
@property (nonatomic, strong) UIButton *closeButton;

@end

@implementation QSFullScreenVideoController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.navigationController.navigationBarHidden = YES;
    self.view.backgroundColor = [UIColor blackColor];
    self.videoContainer = ({
        UIView *videoView = [UIView new];
        videoView.backgroundColor = [UIColor clearColor];
        //默认设置 16:9
        if (CGSizeEqualToSize(self.playerSize, CGSizeZero)) {
            self.playerSize = [UIScreen mainScreen].bounds.size;
        }
        videoView.frame = CGRectMake(0, 0, self.playerSize.width, self.playerSize.height);
        videoView.center = self.view.center;
        videoView.jp_videoPlayerDelegate = self;
        videoView;
    });
    
    [self.view addSubview:self.videoContainer];
    
    self.closeButton = [[UIButton alloc]init];
    [self.closeButton setTitle:@"关闭" forState:UIControlStateNormal];
    [self.closeButton addTarget:self action:@selector(closePlayer:) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:self.closeButton];
    
}

-(void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    [[JPVideoPlayerManager sharedManager]stopPlay];
}

-(void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
    self.closeButton.frame = CGRectMake(30, 64, 44, 44);;
}

-(void)closePlayer:(UIButton *)sender {
    [self dismissViewControllerAnimated:YES completion:nil];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self.videoContainer jp_resumePlayWithURL:self.videoURL
                           bufferingIndicator:nil
                                  controlView:[[JPVideoPlayerControlView alloc] initWithControlBar:nil blurImage:nil]
                                 progressView:nil
                                configuration:^(UIView * _Nonnull view, JPVideoPlayerModel * _Nonnull playerModel) { }];
}

-(void)display {
    UIViewController *root = [UIApplication sharedApplication].keyWindow.rootViewController;
    [root presentViewController:self animated:YES completion:nil];
}

#pragma mark - JPVideoPlayerDelegate
- (BOOL)shouldAutoReplayForURL:(nonnull NSURL *)videoURL {
    return NO;
}

-(BOOL)prefersStatusBarHidden {
    return YES;
}

@end
