//
//  JPPushAnimatedTransitioning.m
//  JPNavigationControllerDemo
//
//  Hello! I am NewPan from Guangzhou of China, Glad you could use my framework, If you have any question or wanna to contact me, please open https://github.com/Chris-Pan or http://www.jianshu.com/users/e2f2d779c022/latest_articles
//

#import "JPPushAnimatedTransitioning.h"
#import "JPSnapTool.h"

// Interative transition factor, bottom layer move place percent when user slip screen.
// 交互错位因子值, 用户push时, 底部图层移动距离相对于用户滑动距离的值.
const CGFloat moveFactor = 0.2;
@implementation JPPushAnimatedTransitioning

- (void)animateTransitionEvent {
    
    // Mix shadow for toViewController' view.
    [self.containerView insertSubview:self.toViewController.view aboveSubview:self.fromViewController.view];
     UIImage *snapImage = [JPSnapTool mixShadowWithView:self.toViewController.view];
    
    // Alloc toView's ImageView.
    UIImageView *ivForToView = [[UIImageView alloc]initWithImage:snapImage];
    [self.toViewController.view removeFromSuperview];
    ivForToView.frame = CGRectMake(JPScreenWidth, 0, snapImage.size.width, JPScreenHeight);
    [self.containerView insertSubview:ivForToView aboveSubview:self.fromViewController.view];
    
    // Alloc fromView's ImageView.
    UIImageView *ivForSnap = [[UIImageView alloc]initWithImage:self.snapImage];
    ivForSnap.frame = CGRectMake(0, 0, JPScreenWidth, JPScreenHeight);
    [self.containerView insertSubview:ivForSnap belowSubview:ivForToView];
    
    // A gray color shadow view for formView.
    UIColor *grayColor = [UIColor colorWithRed:0 green:0 blue:0 alpha:1];
    UIImage *grayImage = [JPSnapTool imageWithColor:grayColor];
    UIImageView *grayImageView = [[UIImageView alloc]initWithFrame:ivForSnap.bounds];
    grayImageView.image = grayImage;
    [ivForSnap addSubview:grayImageView];
    grayImageView.alpha = 0;
    
    // Hide tabBar if need.
    UIViewController *rootVc = [UIApplication sharedApplication].keyWindow.rootViewController;
    if ([rootVc isKindOfClass:[UITabBarController class]]) {
        UITabBarController *r = (UITabBarController *)rootVc;
        UITabBar *tabBar = r.tabBar;
        tabBar.hidden = YES;
    }
    
    self.fromViewController.view.hidden = YES;
    [UIView animateWithDuration:self.transitionDuration animations:^{
        
        // Interative transition animation.
        ivForToView.frame = CGRectMake(-shadowWidth, 0, snapImage.size.width, JPScreenHeight);
        ivForSnap.frame = CGRectMake(-moveFactor*JPScreenWidth, 0, JPScreenWidth, JPScreenHeight);
        grayImageView.alpha = 0.1;
        
    }completion:^(BOOL finished) {
        
        self.fromViewController.view.hidden = NO;
        self.toViewController.view.frame = CGRectMake(0, 0, JPScreenWidth, JPScreenHeight);
        [self.containerView insertSubview:self.toViewController.view belowSubview:ivForToView];
        [ivForToView removeFromSuperview];
        [ivForSnap removeFromSuperview];
        [self completeTransition];
    }];
}

@end
