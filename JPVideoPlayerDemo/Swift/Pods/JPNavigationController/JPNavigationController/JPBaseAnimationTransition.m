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

#import "JPBaseAnimationTransition.h"

@interface JPBaseAnimationTransition()

@property (nonatomic, weak) id <UIViewControllerContextTransitioning> transitionContext;

@end

const CGFloat JPBaseAnimationTransitionInterlaceFactor = 0.3f;
@implementation JPBaseAnimationTransition

- (instancetype)init {
    self = [super init];
    if (self) {
        _transitionDuration = 0.35f;
    }
    return self;
}

- (NSTimeInterval)transitionDuration:(id <UIViewControllerContextTransitioning>)transitionContext {
    return _transitionDuration;
}

- (void)animateTransition:(id <UIViewControllerContextTransitioning>)transitionContext {
    _fromViewController = [transitionContext viewControllerForKey:UITransitionContextFromViewControllerKey];
    _toViewController = [transitionContext viewControllerForKey:UITransitionContextToViewControllerKey];
    _containerView = [transitionContext containerView];
    _transitionContext = transitionContext;
    
    [self animateTransition];
}

- (void)animateTransition{
}

- (void)transitionComplete {
    [self.transitionContext completeTransition:!self.transitionContext.transitionWasCancelled];
}


#pragma mark - Private

- (UITabBar *)fetchTabbar{
    UIViewController *rootVc = [UIApplication sharedApplication].keyWindow.rootViewController;
    UITabBarController *tabbarVc = [self fetchTabbarVcFromRootViewController:rootVc];
    if (tabbarVc) {
        return tabbarVc.tabBar;
    }
    return nil;
}

- (UITabBarController *)fetchTabbarVcFromRootViewController:(UIViewController *)rootVc{
    if ([rootVc isKindOfClass:[UITabBarController class]]) {
        return (UITabBarController *)rootVc;
    }
    else{
        return [self fetchTabbarVcFromRootViewController:rootVc.childViewControllers.firstObject];
    }
}

@end
