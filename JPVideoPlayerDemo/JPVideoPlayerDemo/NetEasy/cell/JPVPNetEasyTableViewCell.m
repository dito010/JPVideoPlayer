//
//  JPVPNetEasyTableViewCell.m
//  JPVideoPlayerDemo
//
//  Created by Memet on 2018/4/24.
//  Copyright © 2018 NewPan. All rights reserved.
//

#import "JPVPNetEasyTableViewCell.h"

@interface JPVPNetEasyTableViewCell()

@property (nonatomic,strong) UIButton *playBtn;

@end

@implementation JPVPNetEasyTableViewCell

- (void)awakeFromNib {
    [super awakeFromNib];
    //添加一个按钮
    if (!_playBtn) {
        _playBtn = [UIButton buttonWithType:UIButtonTypeCustom];
        _playBtn.frame = CGRectMake(0, 0, 50, 50);
        _playBtn.backgroundColor =  [UIColor colorWithRed:87.0/255.0 green:159.0/255.0 blue:251.0/255.0 alpha:100];
        _playBtn.layer.cornerRadius = 25;
        [_playBtn setTitle:@"▷" forState:UIControlStateNormal];
        [_playBtn setTitle:@"❖" forState:UIControlStateSelected];
        [_playBtn addTarget:self action:@selector(playBtnDidClicked:) forControlEvents:UIControlEventTouchUpInside];
        _playBtn.center = CGPointMake([UIScreen mainScreen].bounds.size.width/2, self.videoPlayView.frame.size.height/2.0);
        [self.videoPlayView addSubview:_playBtn];
    }
}

#pragma mark - 交互

- (void)playBtnDidClicked:(UIButton *)sender {
    self.PlayBtnClicked();
}

@end
