#ifdef __OBJC__
#import <UIKit/UIKit.h>
#else
#ifndef FOUNDATION_EXPORT
#if defined(__cplusplus)
#define FOUNDATION_EXPORT extern "C"
#else
#define FOUNDATION_EXPORT extern
#endif
#endif
#endif

#import "JPAnimatedTransitioningBase.h"
#import "JPFullScreenPopGestureRecognizerDelegate.h"
#import "JPLinkContainerView.h"
#import "JPManageSinglePopVCTool.h"
#import "JPNavigationBar.h"
#import "JPNavigationController.h"
#import "JPNavigationControllerKit.h"
#import "JPNavigationInteractiveTransition.h"
#import "JPPushAnimatedTransitioning.h"
#import "JPSnapTool.h"
#import "JPWarpNavigationController.h"
#import "JPWarpViewController.h"
#import "UINavigationController+JPFullScreenPopGesture.h"
#import "UINavigationController+JPLink.h"
#import "UIViewController+JPNavigationController.h"

FOUNDATION_EXPORT double JPNavigationControllerVersionNumber;
FOUNDATION_EXPORT const unsigned char JPNavigationControllerVersionString[];

