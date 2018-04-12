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

#import "JPWarpViewController.h"
#import "JPWarpNavigationController.h"
#import "UIViewController+ViewControllers.h"
#import "JPNavigationController.h"
#import "JPNavigationControllerCompat.h"
#import "JPTransitionShadowView.h"
#import "JPNavigationControllerGestureRecognizer.h"

@interface JPWarpViewController ()

/**
 * The warped navigation controller by self.
 */
@property(nonatomic, strong) JPWarpNavigationController *warpedNavigationController;

/**
 * User viewController.
 */
@property(nonatomic, weak) UIViewController *userViewController;

/**
 * Pop gesture.
 */
@property(nonatomic, strong) JPNavigationControllerGestureRecognizer *panGesture;

/**
 * The current gesture is push or pop.
 */
@property(nonatomic, assign) JPNavigationControllerTransitionType transitionType;

/**
 * ImageView for toViewController.
 */
@property(nonatomic, strong) UIImageView *toImv_anim;

/**
 * Shadow View.
 */
@property(nonatomic, strong) JPTransitionShadowView *shadowView;

@end

static NSValue *kJPWarpViewControllerTabbarRectValue;
// The borderline value devcide is need push pop or not when gesture end.
const CGFloat kJPWarpViewControllerTransitionBorderlineDelta = 0.4;
const CGFloat kJPWarpViewControllerTransitionDuration = 0.25;
const CGFloat kJPWarpViewControllerInterlaceFactor = 0.3;
@implementation JPWarpViewController

- (instancetype)initWithRootViewController:(UIViewController *)rootViewController rootNavigationController:(JPNavigationController *)rootNavigationController{
    
    // Alloc warpNav as B, warp the viewController user passed by B, then warp the B by self become C.
    
    self = [super init];
    if (self) {
        rootViewController.jp_warpViewController = self;
        
        JPWarpNavigationController *warpNav = [[JPWarpNavigationController alloc] initWithRootViewController:rootViewController];
        [warpNav setValue:rootNavigationController forKey:@"rootNavigationController"];
        [self addChildViewController:warpNav];
        
        _userViewController = rootViewController;
        _warpedNavigationController = warpNav;
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.view.backgroundColor = [UIColor whiteColor];
    _warpedNavigationController.view.frame = self.view.bounds;
    [self.view addSubview:_warpedNavigationController.view];
    _transitionType = JPNavigationControllerTransitionTypeNone;
}

- (UIViewController *)childViewControllerForStatusBarStyle{
    return self.childViewControllers.firstObject;
}

- (void)addPopGesture{
    _panGesture = ({
        JPNavigationControllerGestureRecognizer *panGesture = [[JPNavigationControllerGestureRecognizer alloc]initWithTarget:self action:@selector(gestureDidTriggered:)];
        [self.view addGestureRecognizer:panGesture];
        panGesture.maximumNumberOfTouches = 1;
        JPNavigationController *rootNav = _userViewController.jp_rootNavigationController;
        panGesture.delegate = rootNav;
        panGesture.gestureType = JPNavigationControllerGestureRecognizerTypeWarp;
        [panGesture addTarget:rootNav action:NSSelectorFromString(@"gestureDidTriggered:")];
        
        panGesture;
    });
}

- (void)removePopGesture{
    _panGesture.delegate = nil;
    [_panGesture removeTarget:self action:@selector(gestureDidTriggered:)];
    _panGesture = nil;
}


#pragma mark - Gesture

- (void)gestureDidTriggered:(JPNavigationControllerGestureRecognizer *)gestureRecognizer{
   
    // Calculate the percent of the point origin-X / screen width, alloc UIPercentDrivenInteractiveTransition instance when push start, and check user is overrided the protocol method or not, if overrided, then start push and, set start percent = 0.
    // Refresh the slip percent when pan gesture changed.
    // Judge the slip percent is more than the JPPushBorderlineDelta when pan gesture end.
    
    
    CGFloat progress = [gestureRecognizer translationInView:gestureRecognizer.view].x / gestureRecognizer.view.bounds.size.width;
    
    if (gestureRecognizer.state == UIGestureRecognizerStateBegan) {
        _transitionType = JPNavigationControllerTransitionTypePop;
        
        // add animation imageView.
        self.toImv_anim.image = [_userViewController jp_screenCaptureImg];
        self.toImv_anim.frame = CGRectMake(-kJPWarpViewControllerInterlaceFactor * JPScreenW, 0, JPScreenW, JPScreenH);
        [self.view.superview insertSubview:self.toImv_anim atIndex:0];
        
        // add shadow view.
        self.shadowView.frame = CGRectMake(-JPMixShadowViewShadowWidth, 0, JPScreenW + JPMixShadowViewShadowWidth, JPScreenH);
        [self.view.superview insertSubview:self.shadowView aboveSubview:self.toImv_anim];
        
    }
    else if (gestureRecognizer.state == UIGestureRecognizerStateChanged) {
        {
            
            if (_transitionType != JPNavigationControllerTransitionTypePop) {
                return;
            }
            
            if (progress < 0) {
                progress = 0;
            }
            progress = MIN(1.0, MAX(0.0, progress));
            
            CGFloat tx_to = JPScreenW * kJPWarpViewControllerInterlaceFactor * progress;
            self.toImv_anim.transform = CGAffineTransformTranslate(CGAffineTransformIdentity, tx_to, 0);
            CGFloat tx_from = JPScreenW * progress;
            self.view.transform = CGAffineTransformTranslate(CGAffineTransformIdentity, tx_from, 0);
            self.shadowView.transform = CGAffineTransformTranslate(CGAffineTransformIdentity, tx_from, 0);
        }
    }
    else if (gestureRecognizer.state == UIGestureRecognizerStateEnded || gestureRecognizer.state == UIGestureRecognizerStateCancelled) {
        
        if (_transitionType != JPNavigationControllerTransitionTypePop) {
            return;
        }
        
        NSTimeInterval duration;
        
        if (progress > kJPWarpViewControllerTransitionBorderlineDelta) {
            duration = kJPWarpViewControllerTransitionDuration;
            
            [UIView animateWithDuration:duration delay:0 options:UIViewAnimationOptionCurveEaseOut animations:^{
                
                CGFloat tx_to = JPScreenW * kJPWarpViewControllerInterlaceFactor;
                self.toImv_anim.transform = CGAffineTransformTranslate(CGAffineTransformIdentity, tx_to, 0);
                CGFloat tx_from = JPScreenW;
                self.view.transform = CGAffineTransformTranslate(CGAffineTransformIdentity, tx_from, 0);
                self.shadowView.transform = CGAffineTransformTranslate(CGAffineTransformIdentity, tx_from, 0);
                
            } completion:^(BOOL finished) {
                
                [_userViewController.navigationController popViewControllerAnimated:NO];
                self.toImv_anim.transform = CGAffineTransformIdentity;
                self.view.transform = CGAffineTransformIdentity;
                self.shadowView.transform = CGAffineTransformIdentity;
                [self.toImv_anim removeFromSuperview];
                [self.shadowView removeFromSuperview];
                
            }];
        }
        else {
            duration = kJPWarpViewControllerTransitionDuration * progress;
            
            [UIView animateWithDuration:duration delay:0 options:UIViewAnimationOptionCurveEaseOut animations:^{
                
                self.toImv_anim.transform = CGAffineTransformIdentity;
                self.view.transform = CGAffineTransformIdentity;
                self.shadowView.transform = CGAffineTransformIdentity;
                
            } completion:^(BOOL finished) {
                
                [self.toImv_anim removeFromSuperview];
                [self.shadowView removeFromSuperview];
                
            }];
        }
        
        _transitionType = JPNavigationControllerTransitionTypeNone;
    }
}


#pragma mark - Override

- (BOOL)hidesBottomBarWhenPushed{
    return _userViewController.hidesBottomBarWhenPushed;
}


#pragma mark - Private

- (JPTransitionShadowView *)shadowView{
    if (!_shadowView) {
        _shadowView = [JPTransitionShadowView new];
    }
    return _shadowView;
}

- (UIImageView *)toImv_anim{
    if (!_toImv_anim) {
        _toImv_anim = [UIImageView new];
    }
    return _toImv_anim;
}

@end
