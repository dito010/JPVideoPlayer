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

#import "JPNavigationController.h"
#import "UIViewController+ViewControllers.h"
#import "JPWarpViewController.h"
#import "UINavigationController+FulllScreenPopPush.h"
#import "JPNavigationControllerProtocol.h"
#import "JPNavigationControllerCompat.h"
#import "JPWarpNavigationController.h"
#import "JPNavigationControllerGestureRecognizer.h"
#import "JPNavigationControllerTransition.h"
#import "UIColor+ImageGenerate.h"

@interface JPNavigationController ()

/**
 * Pan gesture.
 */
@property(nonatomic, strong) JPNavigationControllerGestureRecognizer *fullScreenPopGesture;

/**
 * The biggest distance allow pop leave screen left slide in current root navigation controller.
 */
@property(nonatomic, assign) CGFloat interactivePopMaxAllowedInitialDistanceToLeftEdge;

/**
 * Close or open pop gesture for all viewControllers in current root navigation controller.
 */
@property(nonatomic, assign) BOOL closePopForAllViewControllers;

/**
 * System pop gesture target.
 */
@property(nonatomic, weak) id systemPopTarget;

/**
 * Transition.
 */
@property(nonatomic, strong) JPNavigationControllerTransition *transition;

@end

@implementation JPNavigationController

- (instancetype)initWithRootViewController:(UIViewController *)rootViewController{
    NSAssert(rootViewController, @"The root view controller cannot be nil.");
    if (!rootViewController) {
        return nil;
    }
    
    // Initialize, you need care that here we push a warped view controller, @see JPWarpViewController.
    
    self = [super init];
    if (self) {
        JPWarpViewController *warpedViewController = [[JPWarpViewController alloc]initWithRootViewController:rootViewController rootNavigationController:self];
        self.viewControllers = @[warpedViewController];
        
        _interactivePopMaxAllowedInitialDistanceToLeftEdge = JPScreenW;
        _closePopForAllViewControllers = NO;
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    // Hide navigation bar of self.
    self.navigationBar.hidden = YES;
    
    
    // Add pan gesture(lazying load) and, add delegate to pan, close system interactivePopGestureRecognizer at the same time.
    if (![self.interactivePopGestureRecognizer.view.gestureRecognizers containsObject:self.fullScreenPopGesture]) {
        [self.interactivePopGestureRecognizer.view addGestureRecognizer:_fullScreenPopGesture];
        NSArray *targets = [self.interactivePopGestureRecognizer valueForKey:@"targets"];
        _systemPopTarget = [targets.firstObject valueForKey:@"target"];
        self.interactivePopGestureRecognizer.enabled = NO;
        
        [_fullScreenPopGesture addTarget:self action:@selector(gestureDidTriggered:)];
    }
}

- (UIViewController *)childViewControllerForStatusBarStyle{
    return self.topViewController;
}


#pragma mark - Public

- (NSArray<UIViewController *> *)jp_viewControllers {
    NSMutableArray<UIViewController *> *viewControllers = [NSMutableArray array];
    for (JPWarpViewController *warpViewController in self.viewControllers) {
        [viewControllers addObject:warpViewController.userViewController];
    }
    return [viewControllers copy];
}

#pragma mark - UIGestureRecognizerDelegate

- (BOOL)gestureRecognizerShouldBegin:(JPNavigationControllerGestureRecognizer *)gestureRecognizer{
    CGPoint translation = [gestureRecognizer velocityInView:gestureRecognizer.view];
    
    JPWarpViewController *warpVc = self.viewControllers.lastObject;
    if (!warpVc) {
        return NO;
    }
    JPWarpNavigationController *warpNav = warpVc.childViewControllers.firstObject;
    if (!warpNav) {
        return NO;
    }
    
    if (translation.x < 0) {
        
        // left slip, means push action.
        
        if (warpNav.navigationDelegate && [warpNav.navigationDelegate respondsToSelector:@selector(navigationControllerDidPush:)]) {
            [self addPushAction:gestureRecognizer];
            
            return YES;
        }
        
        return NO;
    }
    else{
        
        // right slip, means pop action.
        
        // Forbid pop when the start point beyond user setted range for pop.
        CGPoint beginningLocation = [gestureRecognizer locationInView:gestureRecognizer.view];
        if (_interactivePopMaxAllowedInitialDistanceToLeftEdge >= 0 && beginningLocation.x > _interactivePopMaxAllowedInitialDistanceToLeftEdge) {
            return NO;
        }
        else{
            // forbid pop when transitioning.
            if ([[self valueForKey:@"_isTransitioning"] boolValue]) {
                return NO;
            }
            
            // forbid pop when current viewController is root viewController.
            if (self.viewControllers.count == 1) {
                return NO;
            }
            
            // forbid pop when closed all viewControllers' pop gesture.
            if (_closePopForAllViewControllers) {
                return NO;
            }
            
            // Check current view controller is close pop or not.
            if (warpNav.closePopForCurrentViewController) {
                return NO;
            }
            
            // ask delegate.
            if (warpNav.navigationDelegate && [warpNav.navigationDelegate respondsToSelector:@selector(navigationControllerShouldStartPop:)]) {
                if (![warpNav.navigationDelegate navigationControllerShouldStartPop:self]) {
                    return NO;
                }
            }
            
            // not use system pop action.
            if (warpNav.useCustomPopAnimationForCurrentViewController) {
                return YES;
            }
            
            // use system pop action.
            [self addSystemPopAction:gestureRecognizer];
        }
    }
    
    return YES;
}


#pragma mark - Gesture

- (void)gestureDidTriggered:(JPNavigationControllerGestureRecognizer *)gestureRecognizer{
    
    if (gestureRecognizer.state == UIGestureRecognizerStateBegan) {
       
        CGPoint translation = [gestureRecognizer velocityInView:gestureRecognizer.view];
        if (translation.x < 0) {
            
            JPWarpViewController *warpVc = self.viewControllers.lastObject;
            
            if (!warpVc) {
                return;
            }
            JPWarpNavigationController *warpNav = warpVc.childViewControllers.firstObject;
            if (!warpNav) {
                return;
            }
            
            // ask delegate.
            if (warpNav.navigationDelegate && [warpNav.navigationDelegate respondsToSelector:@selector(navigationControllerDidPush:)]) {
                
                // handle pop transition animation by system.
                self.delegate = self.transition;
                
                [warpNav.navigationDelegate navigationControllerDidPush:self];
            }
        }
    }
    else if (gestureRecognizer.state == UIGestureRecognizerStateEnded || gestureRecognizer.state == UIGestureRecognizerStateCancelled) {
        
        // reset root navigation controller delegate.
        // if not do this, some unexpected error will happen when tap back button.
        self.delegate = nil;
        
        // remove target.
        [self removeAllAction:gestureRecognizer];
        
    }
}


#pragma mark - System Pop Gesture Target

- (void)addSystemPopAction:(JPNavigationControllerGestureRecognizer *)gesture{
    // handle pop transition animation by system.
    self.delegate = nil;
    
    // System pop action.
    SEL popSel = NSSelectorFromString(@"handleNavigationTransition:");
    [gesture addTarget:_systemPopTarget action:popSel];
    gesture.transitionType = JPNavigationControllerTransitionTypePopSystem;
}


#pragma mark - Push Gesture Target

- (void)addPushAction:(JPNavigationControllerGestureRecognizer *)gesture{
    // push action.
    [gesture addTarget:self.transition action:@selector(gestureDidTriggered:)];
    gesture.transitionType = JPNavigationControllerTransitionTypePush;
}


#pragma mark - Remove Gesture Target

- (void)removeAllAction:(JPNavigationControllerGestureRecognizer *)gesture{
    switch (gesture.transitionType) {
        case JPNavigationControllerTransitionTypeNone:
            break;
            
        case JPNavigationControllerTransitionTypePush:{
            [gesture removeTarget:self.transition action:@selector(gestureDidTriggered:)];
        }
            break;
            
        case JPNavigationControllerTransitionTypePopSystem:{
            SEL popSel = NSSelectorFromString(@"handleNavigationTransition:");
            [gesture removeTarget:_systemPopTarget action:popSel];
        }
            break;
            
        case JPNavigationControllerTransitionTypePop:{
        }
            break;
    }
}


#pragma mark - Private

- (JPNavigationControllerGestureRecognizer *)fullScreenPopGesture{
    if (!_fullScreenPopGesture) {
        _fullScreenPopGesture = [JPNavigationControllerGestureRecognizer new];
        _fullScreenPopGesture.maximumNumberOfTouches = 1;
        _fullScreenPopGesture.delegate = self;
        _fullScreenPopGesture.transitionType = JPNavigationControllerTransitionTypeNone;
        _fullScreenPopGesture.gestureType = JPNavigationControllerGestureRecognizerTypeWarp;
    }
    return _fullScreenPopGesture;
}

- (JPNavigationControllerTransition *)transition{
    if (!_transition) {
        _transition = [[JPNavigationControllerTransition alloc] initWithNavigationContollerViewController:self];
    }
    return _transition;
}

- (void)popToViewController:(NSDictionary *)arguments{
    if (!arguments) {
        return;
    }
    
    NSString *targetClassString = arguments[@"targetClassString"];
    JPNavigationContollerPopHandler handler = arguments[@"handle"];
    BOOL animated = [arguments[@"animated"] boolValue];
    
    NSMutableArray <JPWarpViewController *> *viewControllersM = [NSMutableArray array];
    
    // find all viewControllers in stack that class is given class.
    for (JPWarpViewController *vc in self.viewControllers) {
        Class targetClass = NSClassFromString(targetClassString);
        if ([vc.userViewController isKindOfClass:targetClass]) {
            [viewControllersM addObject:vc];
        }
    }
    
    // if find viewController for given class.
    if (viewControllersM.count) {
        
        if (handler) {
            NSMutableArray <UIViewController *> *targetViewControllersM = [NSMutableArray array];
            [viewControllersM enumerateObjectsUsingBlock:^(JPWarpViewController * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
               
                [targetViewControllersM addObject:obj.userViewController];
                
            }];
            
            UIViewController *vc = handler([targetViewControllersM copy], nil);
            if (vc) {
                [self popToViewController:vc.jp_warpViewController animated:animated];
            }
        }
        else{
            
            JPWarpViewController *warpVc = viewControllersM.firstObject;
            [self popToViewController:warpVc animated:animated];
            
        }
    }
    else{
        // don't find viewController in stack for given class.
        
        if (handler) {
            NSError *error = [NSError errorWithDomain:[NSString stringWithFormat:@"JPNavigationController don't find viewController in stack for >> %@ <<.", targetClassString] code:0 userInfo:nil];
            handler(nil, error);
        }
    }
}

@end
