//
//  JPPlaySingleVideoVC.m
//  JPVideoPlayerDemo
//
//  Created by lava on 2016/11/10.
//  Copyright © 2016年 NewPan. All rights reserved.
//

#import "JPPlaySingleVideoVC.h"
#import "JPVideoPlayer.h"

@interface JPPlaySingleVideoVC ()

@property (weak, nonatomic) IBOutlet UIView *videoContainerView;

@end

@implementation JPPlaySingleVideoVC

- (void)viewDidLoad {
    [super viewDidLoad];
    
}

-(void)setVideoPath:(NSString *)videoPath{
    _videoPath = videoPath;
    [[JPVideoPlayer sharedInstance]playWithUrl:[NSURL URLWithString:videoPath] showView:self.videoContainerView];
}

- (IBAction)closeBtnClick:(id)sender {
    [self dismissViewControllerAnimated:YES completion:nil];
}

- (IBAction)muteSwitch:(UISwitch *)sw {
    [JPVideoPlayer sharedInstance].mute = !sw.on;
}

-(BOOL)prefersStatusBarHidden{
    return YES;
}

@end
