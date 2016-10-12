//
//  JPVideoPlayerCell.m
//  JPVideoPlayer
//
//  Created by lava on 16/9/8.
//  Hello! I am NewPan from Guangzhou of China, Glad you could use my framework, If you have any question or wanna to contact me, please open https://github.com/Chris-Pan or http://www.jianshu.com/users/e2f2d779c022/latest_articles


#import "JPVideoPlayerCell.h"

@implementation JPVideoPlayerCell

-(void)awakeFromNib{
    [super awakeFromNib];
    
    // Thanks @大墙66370 (http://www.jianshu.com/users/6266c6477c99?utm_campaign=hugo&utm_medium=reader_share&utm_content=user&utm_source=qq) submmit this question on Jianshu.
    // 处理在切换视频的短暂时间内, 当前播放视频的cell吸收了滑动事件, 如果滑动当前播放视频的cell, 会导致tableView无法接收到滑动事件, 造成tableView假死. 这个问题很简单, 因为这个容器视图只是负责显示视频的, 所以把它的userInteractionEnabled关掉就可以了.
    
    self.containerView.userInteractionEnabled = NO;
}

@end
