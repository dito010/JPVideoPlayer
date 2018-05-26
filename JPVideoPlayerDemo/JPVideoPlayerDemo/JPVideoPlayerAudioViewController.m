//
//  JPVideoPlayerAudioViewController.m
//  JPVideoPlayerDemo
//
//  Created by NewPan on 2018/5/25.
//  Copyright © 2018年 NewPan. All rights reserved.
//

#import "JPVideoPlayerAudioViewController.h"
#import "JPVideoPlayerKit.h"

@interface JPVideoPlayerAudioViewController ()<JPVideoPlayerDelegate>

@property (weak, nonatomic) IBOutlet UIImageView *audioView;

@end

@implementation JPVideoPlayerAudioViewController

- (void)viewDidLoad {
    [super viewDidLoad];
   
    self.title = @"音频播放";
    [self.audioView jp_playVideoWithURL:[NSURL URLWithString:@"http://p11s9kqxf.bkt.clouddn.com/remember%20me.mp3"]
                     bufferingIndicator:nil
                            controlView:nil progressView:nil
                configurationCompletion:nil];
    self.audioView.jp_videoPlayerDelegate = self;
}

- (void)viewDidDisappear:(BOOL)animated {
    [super viewDidDisappear:animated];
    [self.audioView jp_stopPlay];
}


#pragma mark - JPVideoPlayerDelegate

- (BOOL)shouldShowBlackBackgroundWhenPlaybackStart {
    return NO;
}

@end
