//
//  JPVideoPlayerCollectionViewCell.m
//  qs
//
//  Created by xzx on 2018/6/29.
//  Copyright © 2017年 xzx. All rights reserved.
//

#import "JPVideoPlayerCollectionViewCell.h"

@implementation JPVideoPlayerCollectionViewCell

- (instancetype)initWithFrame:(CGRect)frame {
	if (self = [super initWithFrame:frame]) {
		self.videoPlayerView = ({
			UIImageView *videoPlayerView = [UIImageView new];
			videoPlayerView.contentMode = UIViewContentModeScaleAspectFill;
			videoPlayerView.clipsToBounds = YES;
			[self.contentView addSubview:videoPlayerView];

			videoPlayerView;
		});

	}
	return self;
}

-(void)layoutSubviews {
    [super layoutSubviews];
    self.videoPlayerView.frame = self.bounds;
}

- (void)setIndexPath:(NSIndexPath *)indexPath{
	_indexPath = indexPath;
	if (indexPath.row % 2) {
		self.videoPlayerView.image = [UIImage imageNamed:@"placeholder1"];
	}
	else{
		self.videoPlayerView.image = [UIImage imageNamed:@"placeholder2"];
	}
}

@end
