//
//  JPVideoPlayerCell.h
//  JPVideoPlayer
//
//  Created by lava on 16/9/8.
//  Copyright © 2016年 lavaMusic. All rights reserved.
//

#import <UIKit/UIKit.h>

// 播放滑动不可及cell的类型
typedef NS_ENUM(NSUInteger, PlayUnreachCellStyle) {
    PlayUnreachCellStyleUp = 1, // 顶部不可及
    PlayUnreachCellStyleDown = 2, // 底部不可及
    PlayUnreachCellStyleNone = 3 // 播放滑动可及cell
};

@interface JPVideoPlayerCell : UITableViewCell

@property (weak, nonatomic) IBOutlet UIView *containerView;

/** videoPath */
@property(nonatomic, strong)NSString *videoPath;

/** indexPath */
@property(nonatomic, strong)NSIndexPath *indexPath;

/** cell类型 */
@property(nonatomic, assign)PlayUnreachCellStyle cellStyle;

@end
