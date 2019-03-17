//
//  JPVideoPlayerCustomizedVideoViewController.m
//  JPVideoPlayerDemo
//
//  Created by NewPan on 2019/3/17.
//  Copyright © 2019 NewPan. All rights reserved.
//

#import "JPVideoPlayerCustomizedVideoViewController.h"
#import "JPVideoPlayerKit.h"

@interface JPVideoPlayerCustomizedVideoViewController ()<JPVideoPlayerDelegate>

@property (weak, nonatomic) IBOutlet UITextField *videoURLTextField;

@property (weak, nonatomic) IBOutlet UIView *videoView;

@end

@implementation JPVideoPlayerCustomizedVideoViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"自定义视频播放";
    self.videoView.jp_videoPlayerDelegate = self;
}

- (void)viewDidDisappear:(BOOL)animated {
    [super viewDidDisappear:animated];
    [self.videoView jp_stopPlay];
}

- (IBAction)playButtonDidClick:(id)sender {
    [self.view endEditing:YES];
    NSString *videoURLPath = self.videoURLTextField.text;
    if (!videoURLPath.length) videoURLPath = self.videoURLTextField.placeholder;
    if (!videoURLPath.length) return;
    
    [self.videoView jp_stopPlay];
    [self.videoView jp_resumePlayWithURL:[NSURL URLWithString:videoURLPath]
                      bufferingIndicator:nil
                             controlView:nil
                            progressView:nil
                           configuration:nil];
}


#pragma mark - JPVideoPlayerDelegate

- (void)playVideoFailWithError:(NSError *)error videoURL:(NSURL *)videoURL {
    NSLog(@"%@", error);
}

@end
