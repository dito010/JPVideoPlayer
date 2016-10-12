//
//  JPVideoPlayerCell.h
//  JPVideoPlayer
//
//  Created by lava on 16/9/8.
//  Hello! I am NewPan from Guangzhou of China, Glad you could use my framework, If you have any question or wanna to contact me, please open https://github.com/Chris-Pan or http://www.jianshu.com/users/e2f2d779c022/latest_articles


#import <UIKit/UIKit.h>

/**
 * The style of cell cannot stop in screen center.
 * 播放滑动不可及cell的类型
 */
typedef NS_ENUM(NSUInteger, PlayUnreachCellStyle) {
    PlayUnreachCellStyleUp = 1, // top 顶部不可及
    PlayUnreachCellStyleDown = 2, // bottom 底部不可及
    PlayUnreachCellStyleNone = 3 // normal 播放滑动可及cell
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
