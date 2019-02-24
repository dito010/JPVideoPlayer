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

extern const CGFloat JPBaseAnimationTransitionInterlaceFactor;

NS_ASSUME_NONNULL_BEGIN

@interface JPBaseAnimationTransition : NSObject<UIViewControllerAnimatedTransitioning>

/**
 *  Transition Duration.
 */
@property (nonatomic, assign, readonly) NSTimeInterval  transitionDuration;

/**
 *  From view controller.
 */
@property (nonatomic, readonly, weak) UIViewController *fromViewController;

/**
 *  Target view controller.
 */
@property (nonatomic, readonly, weak) UIViewController *toViewController;

/**
 *  Container view.
 */
@property (nonatomic, readonly, weak) UIView *containerView;

/**
 *  Animate Transition.
 */
- (void)animateTransition;

/**
 *  Complete transition.
 */
- (void)transitionComplete;

/**
 *  Fetch tabbar if existed.
 */
- (UITabBar * _Nullable)fetchTabbar;

@end

NS_ASSUME_NONNULL_END
