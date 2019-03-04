//
//  JPVideoPlayerCollectionViewCell.h
//  qs
//
//  Created by xzx on 2018/6/29.
//  Copyright © 2017年 xzx. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface JPVideoPlayerCollectionViewCell : UICollectionViewCell

/// 视频
@property (nonatomic, strong) UIImageView *videoPlayerView;

@property(nonatomic, strong) NSIndexPath *indexPath;

@end
