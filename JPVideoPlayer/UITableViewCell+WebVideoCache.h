/*
 * This file is part of the JPVideoPlayer package.
 * (c) NewPan <13246884282@163.com>
 *
 * For the full copyright and license information, please view the LICENSE
 * file that was distributed with this source code.
 *
 * Click https://github.com/newyjp
 * or http://www.jianshu.com/users/e2f2d779c022/latest_articles to contact me.
 */

#import <UIKit/UIKit.h>

typedef NS_OPTIONS(NSUInteger , JPVideoPlayerUnreachableCellType) {
    JPVideoPlayerUnreachableCellTypeNone = 0,
    JPVideoPlayerUnreachableCellTypeTop = 1,
    JPVideoPlayerUnreachableCellTypeDown = 2
};

NS_ASSUME_NONNULL_BEGIN

@interface UITableViewCell (WebVideoCache)

/**
 * The video path url.
 *
 * @note The url may a web url or local file url.
 */
@property (nonatomic, nullable) NSURL *jp_videoURL;

/**
 * The view to display video layer.
 */
@property (nonatomic, nullable) UIView *jp_videoPlayView;

/**
 * The style of cell cannot stop in screen center.
 */
@property(nonatomic) JPVideoPlayerUnreachableCellType jp_unreachableCellType;

/**
 * Returns a Boolean value that indicates whether a given cell is equal to
 * the receiver using `jp_videoURL` comparison.
 *
 * @param cell The cell with which to compare the receiver.
 *
 * @return YES if cell is equivalent to the receiver (if they have the same `jp_videoURL` comparison), otherwise NO.
 */
- (BOOL)jp_isEqualToCell:(UITableViewCell *)cell;

@end

NS_ASSUME_NONNULL_END