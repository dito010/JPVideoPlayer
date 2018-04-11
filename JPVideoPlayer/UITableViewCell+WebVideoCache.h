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

NS_ASSUME_NONNULL_BEGIN

@interface UITableViewCell (WebVideoCache)

/**
 * The video path url.
 * @note The url may a web url or local file url.
 */
@property (nonatomic, nullable) NSURL *jp_videoURL;

/**
 * The view to display video layer.
 */
@property (nonatomic, nullable) UIView *jp_videoPlayView;

@end

NS_ASSUME_NONNULL_END