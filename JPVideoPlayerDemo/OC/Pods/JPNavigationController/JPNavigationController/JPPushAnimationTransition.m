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

#import "JPPushAnimationTransition.h"
#import "JPNavigationControllerCompat.h"
#import "UIView+ScreenCapture.h"
#import "UIViewController+ViewControllers.h"
#import "JPTransitionShadowView.h"
#import "UIView+ScreenCapture.h"

@interface JPPushAnimationTransition()

/**
 * ImageView for toViewController to animate.
 */
@property(nonatomic, strong) JPTransitionShadowView *toShadowView_anim;

/**
 * From ImageView for fromViewController to animate.
 */
@property(nonatomic, strong) UIImageView *fromImv_anim;

@end

@implementation JPPushAnimationTransition

- (void)animateTransition{
    BOOL tabbarIsHidden = self.toViewController.hidesBottomBarWhenPushed;
    
    if (tabbarIsHidden) {
        // hide tabbar.
        [self animateTransitionForHiddenTabbar];
    }
    else{
        [self animateTransitionForDisplayTabbar];
    }
}


#pragma mark - Animation

- (void)animateTransitionForHiddenTabbar{
    
    UIImage *fromImg = [self.fromViewController.view.window jp_captureCurrentView];
    self.fromImv_anim.image = fromImg;
    self.fromImv_anim.frame = CGRectMake(0, 0, JPScreenW, JPScreenH);
    [self.containerView addSubview:self.fromImv_anim];
    
    CGRect toViewFrame = CGRectMake(JPScreenW - JPMixShadowViewShadowWidth, 0, JPScreenW + JPMixShadowViewShadowWidth, JPScreenH);
    self.toShadowView_anim.frame = toViewFrame;
    self.toViewController.view.frame = CGRectMake(JPMixShadowViewShadowWidth, 0, JPScreenW, JPScreenH);
    [self.toShadowView_anim addSubview:self.toViewController.view];
    [self.containerView addSubview:self.toShadowView_anim];
    
    // hide tabbar.
    UITabBar *tabbar = [self fetchTabbar];
    if (tabbar) {
        tabbar.hidden = YES;
    }
    
    [UIView animateWithDuration:self.transitionDuration delay:0 options:UIViewAnimationOptionCurveEaseOut animations:^{
        
        CGRect fromViewFrame = self.fromImv_anim.frame;
        fromViewFrame.origin.x = -JPBaseAnimationTransitionInterlaceFactor * JPScreenW;
        self.fromImv_anim.frame = fromViewFrame;
        
        CGRect toViewframe = self.toShadowView_anim.frame;
        toViewframe.origin.x = -JPMixShadowViewShadowWidth;
        self.toShadowView_anim.frame = toViewframe;
        
    } completion:^(BOOL finished) {
        
        [self.toViewController.view removeFromSuperview];
        self.toViewController.view.frame = CGRectMake(0, 0, JPScreenW, JPScreenH);
        [self.containerView addSubview:self.toViewController.view];
        [self transitionComplete];
        self.fromImv_anim.image = nil;
        [self.fromImv_anim removeFromSuperview];
        [self.toShadowView_anim removeFromSuperview];
        
        tabbar.hidden = NO;
    }];
}

- (void)animateTransitionForDisplayTabbar{
    
    self.fromViewController.view.frame = CGRectMake(0, 0, JPScreenW, JPScreenH);
    [self.containerView addSubview:self.fromViewController.view];
    
    CGRect toViewFrame = CGRectMake(JPScreenW - JPMixShadowViewShadowWidth, 0, JPScreenW + JPMixShadowViewShadowWidth, JPScreenH);
    self.toShadowView_anim.frame = toViewFrame;
    self.toViewController.view.frame = CGRectMake(JPMixShadowViewShadowWidth, 0, JPScreenW, JPScreenH);
    [self.toShadowView_anim addSubview:self.toViewController.view];
    [self.containerView addSubview:self.toShadowView_anim];
    
    [UIView animateWithDuration:self.transitionDuration delay:0 options:UIViewAnimationOptionCurveEaseOut animations:^{
        
        CGRect fromViewFrame = self.fromViewController.view.frame;
        fromViewFrame.origin.x = -JPBaseAnimationTransitionInterlaceFactor * JPScreenW;
        self.fromViewController.view.frame = fromViewFrame;
        
        CGRect toViewframe = self.toShadowView_anim.frame;
        toViewframe.origin.x = -JPMixShadowViewShadowWidth;
        self.toShadowView_anim.frame = toViewframe;
        
    } completion:^(BOOL finished) {
        
        [self.toViewController.view removeFromSuperview];
        self.toViewController.view.frame = CGRectMake(0, 0, JPScreenW, JPScreenH);
        [self.containerView addSubview:self.toViewController.view];
        [self transitionComplete];
        [self.toShadowView_anim removeFromSuperview];
        
    }];
}


#pragma mark - Private

- (UIImageView *)fromImv_anim{
    if (!_fromImv_anim) {
        _fromImv_anim = [UIImageView new];
    }
    return _fromImv_anim;
}

- (JPTransitionShadowView *)toShadowView_anim{
    if (!_toShadowView_anim) {
        _toShadowView_anim = [JPTransitionShadowView new];
    }
    return _toShadowView_anim;
}

@end
