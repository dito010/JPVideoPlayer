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

@protocol JPNavigationControllerDelegate;

@interface JPWarpNavigationController : UINavigationController

/**
 * Close or open pop gesture for current viewController in current root navigation controller.
 * NO by default.
 */
@property(nonatomic, assign, readonly) BOOL closePopForCurrentViewController;

/**
 * Use custom pop animation for current viewController in current root navigation controller.
 * Default is NO.
 */
@property(nonatomic, assign, readonly) BOOL useCustomPopAnimationForCurrentViewController;

/**
 * Link view height at screen bottom.
 */
@property(nonatomic, assign, readonly)CGFloat linkViewHeight;

/**
 * Link view at screen bottom.
 * You just need pass your link view to this property, framework will display your link view automatically.
 */
@property(nonatomic, strong, readonly)UIView * linkView;

/**
 * Delegate to observer delegate events.
 *
 * @see JPNavigationControllerDelegate.
 */
@property(nonatomic, weak, readonly) id<JPNavigationControllerDelegate> navigationDelegate;

@end

NS_ASSUME_NONNULL_END
