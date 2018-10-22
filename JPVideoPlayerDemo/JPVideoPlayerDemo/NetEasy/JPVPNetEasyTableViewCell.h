//
//  JPVPNetEasyTableViewCell.h
//  JPVideoPlayerDemo
//
//  Created by Memet on 2018/4/24.
//  Copyright © 2018 NewPan. All rights reserved.
//

#import <UIKit/UIKit.h>

@class JPVPNetEasyTableViewCell;

@protocol JPVPNetEasyTableViewCellDelegate<NSObject>

@optional
- (void)cellPlayButtonDidClick:(JPVPNetEasyTableViewCell *)cell;

@end

@interface JPVPNetEasyTableViewCell : UITableViewCell

@property (weak, nonatomic) IBOutlet UIButton *playButton;

@property (weak, nonatomic) IBOutlet UIImageView *videoPlayView;

@property(nonatomic, weak) id<JPVPNetEasyTableViewCellDelegate> delegate;

@property(nonatomic, strong)NSIndexPath *indexPath;

@end
