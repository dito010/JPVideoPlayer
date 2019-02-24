//
//  QSFeedVideoCell.m
//  qs
//
//  Created by xzx on 2018/6/29.
//  Copyright © 2017年 xzx. All rights reserved.
//

#import "QSFeedVideoCell.h"

@implementation QSFeedVideoCell

- (id)initWithFrame:(CGRect)frame {
	if (self = [super initWithFrame:frame]) {
		[self.contentView addSubview:self.videoPlayerView];
	}
	return self;
}

-(void)layoutSubviews {
    [super layoutSubviews];
    self.videoPlayerView.frame = CGRectInset(self.contentView.bounds, 20, 0);
}

#pragma mark - # Private Methods


#pragma mark - # Getter
- (UIImageView *)videoPlayerView {
	if (!_videoPlayerView) {
		_videoPlayerView = [[UIImageView alloc]initWithFrame:CGRectInset(self.contentView.bounds, 20, 0)];
        _videoPlayerView.contentMode = UIViewContentModeScaleAspectFill;
        _videoPlayerView.clipsToBounds = YES;
	}
	return _videoPlayerView;
}

@end
