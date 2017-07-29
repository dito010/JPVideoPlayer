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

/**
 * This class is custom navigation bar.
 * Framework add the link container view on it, then the link view is out of its super class' range, this lead to link view cannot response user's touch events. we need handle this situation by override hitTest:withEvent: method.
 */

#import <UIKit/UIKit.h>

@interface JPLinkContainerView : UIView

@end

@interface JPNavigationBar : UINavigationBar

@end
