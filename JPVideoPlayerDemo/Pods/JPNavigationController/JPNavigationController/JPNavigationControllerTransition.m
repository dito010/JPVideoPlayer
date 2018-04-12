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

#import "JPNavigationControllerTransition.h"
#import "JPNavigationController.h"
#import "JPNavigationControllerCompat.h"
#import "JPPushAnimationTransition.h"
#import "JPNavigationControllerGestureRecognizer.h"

@interface JPNavigationControllerTransition()

/**
 * The root navigation controller.
 */
@property(nonatomic, weak) JPNavigationController *navigationController;

/**
 * Percent Driven Interactive Transition.
 */
@property (nonatomic, strong) UIPercentDrivenInteractiveTransition *interactivePopTransition;

/**
 * The current gesture is push or pop.
 */
@property(nonatomic, assign) JPNavigationControllerTransitionType transitionType;

/**
 * Pop animation transition.
 */
@property(nonatomic, strong) JPPushAnimationTransition *pushAnimTransition;

@end

// The borderline value devcide is need push pop or not when gesture end.
const CGFloat kJPNavigationControllerTransitionBorderlineDelta = 0.3;
@implementation JPNavigationControllerTransition

- (instancetype)initWithNavigationContollerViewController:(JPNavigationController *)navigationController{
    self = [super init];
    if (self) {
        _navigationController = navigationController;
        _transitionType = JPNavigationControllerTransitionTypeNone;
    }
    return self;
}

- (void)gestureDidTriggered:(JPNavigationControllerGestureRecognizer *)gestureRecognizer{
    
    // Calculate the percent of the point origin-X / screen width, alloc UIPercentDrivenInteractiveTransition instance when push start, and check user is overrided the protocol method or not, if overrided, then start push and, set start percent = 0.
    // Refresh the slip percent when pan gesture changed.
    // Judge the slip percent is more than the JPPushBorderlineDelta when pan gesture end.
    
    CGFloat progress = [gestureRecognizer translationInView:gestureRecognizer.view].x / gestureRecognizer.view.bounds.size.width;
    
    if (gestureRecognizer.state == UIGestureRecognizerStateBegan) {
        
        _transitionType = gestureRecognizer.transitionType;
        [self.interactivePopTransition updateInteractiveTransition:0];
        
    }
    else if (gestureRecognizer.state == UIGestureRecognizerStateChanged) {
        
        if (_transitionType == JPNavigationControllerTransitionTypePush) {
            if (progress <= 0) {
                progress = fabs(progress);
                progress = MIN(1.0, MAX(0.0, progress));
            }
            else{
                progress = 0;
            }
            
            [self.interactivePopTransition updateInteractiveTransition:progress];
        }
        
    }
    else if (gestureRecognizer.state == UIGestureRecognizerStateEnded || gestureRecognizer.state == UIGestureRecognizerStateCancelled) {
        
        if (fabs(progress) > kJPNavigationControllerTransitionBorderlineDelta) {
            [self.interactivePopTransition finishInteractiveTransition];
        }
        else {
            [self.interactivePopTransition cancelInteractiveTransition];
        }
        _transitionType = JPNavigationControllerTransitionTypeNone;
    }
}


#pragma mark - UINavigationControllerDelegate

- (id<UIViewControllerAnimatedTransitioning>)navigationController:(UINavigationController *)navigationControxller
                                  animationControllerForOperation:(UINavigationControllerOperation)operation
                                               fromViewController:(UIViewController *)fromVC
                                                 toViewController:(UIViewController *)toVC {
    
    // return custom animation transition for given situtation.
    if (operation == UINavigationControllerOperationPush) {
        return self.pushAnimTransition;
    }
    
    return nil;
}


- (id<UIViewControllerInteractiveTransitioning>)navigationController:(UINavigationController *)navigationController
                         interactionControllerForAnimationController:(id<UIViewControllerAnimatedTransitioning>)animationController {
    
    // If the animationController is custom instance, return interactivePopTransition to manage transition progress.
    if (self.interactivePopTransition) {
        return _interactivePopTransition;
    }
    
    return nil;
}


#pragma mark - Private

- (UIPercentDrivenInteractiveTransition *)interactivePopTransition{
    if (!_interactivePopTransition) {
        _interactivePopTransition = [[UIPercentDrivenInteractiveTransition alloc] init];
        _interactivePopTransition.completionCurve = UIViewAnimationCurveEaseOut;
    }
    return _interactivePopTransition;
}

- (JPPushAnimationTransition *)pushAnimTransition{
    if (!_pushAnimTransition) {
        _pushAnimTransition = [JPPushAnimationTransition new];
    }
    return _pushAnimTransition;
}

@end
