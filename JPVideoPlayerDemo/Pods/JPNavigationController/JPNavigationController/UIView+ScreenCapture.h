/*
 * This file is part of the JPNavigationController package.
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

@interface UIView (ScreenCapture)

/**
 * Capture current view generate a image.
 *
 * @return a image of current view.
 */
- (UIImage *)jp_captureCurrentView;

@end

NS_ASSUME_NONNULL_END
