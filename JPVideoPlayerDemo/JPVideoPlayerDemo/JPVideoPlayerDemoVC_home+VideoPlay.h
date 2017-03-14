/*
 * This file is part of the JPVideoPlayer package.
 * (c) NewPan <13246884282@163.com>
 *
 * For the full copyright and license information, please view the LICENSE
 * file that was distributed with this source code.
 *
 * Click https://github.com/Chris-Pan
 * or http://www.jianshu.com/users/e2f2d779c022/latest_articles to contact me.
 */


#import "JPVideoPlayerDemoVC_home.h"

@class JPVideoPlayerDemoCell;

UIKIT_EXTERN CGFloat const JPVideoPlayerDemoNavAndStatusTotalHei;
#define JPVideoPlayerDemoRowHei ([UIScreen mainScreen].bounds.size.width*9.0/16.0)

/*
 * The scroll derection of tableview.
 * 滚动类型
 */
typedef NS_ENUM(NSUInteger, JPVideoPlayerDemoScrollDerection) {
    JPVideoPlayerDemoScrollDerectionNone = 0,
    JPVideoPlayerDemoScrollDerectionUp = 1, // 向上滚动
    JPVideoPlayerDemoScrollDerectionDown = 2 // 向下滚动
};

@interface JPVideoPlayerDemoVC_home (VideoPlay)

/**
 * The cell of playing video.
 * 正在播放视频的cell.
 */
@property(nonatomic, nullable)JPVideoPlayerDemoCell *playingCell;

/**
 * The number of cells cannot stop in screen center.
 * 滑动不可及cell个数.
 */
@property(nonatomic)NSUInteger maxNumCannotPlayVideoCells;

/**
 * The scroll derection of tableview now.
 * 当前滚动方向类型.
 */
@property(nonatomic)JPVideoPlayerDemoScrollDerection currentDerection;

/**
 * The dictionary of record the number of cells that cannot stop in screen center.
 * 滑动不可及cell字典.
 */
@property(nonatomic, nonnull)NSDictionary *dictOfVisiableAndNotPlayCells;

-(void)playVideoInVisiableCells;

-(void)handleScrollStop;

-(void)handleQuickScroll;

-(void)stopPlay;

@end
