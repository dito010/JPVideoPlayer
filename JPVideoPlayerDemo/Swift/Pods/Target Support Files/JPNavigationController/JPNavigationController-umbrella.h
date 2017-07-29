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

#import "JPBaseAnimationTransition.h"
#import "JPNavigationBar.h"
#import "JPNavigationController.h"
#import "JPNavigationControllerCompat.h"
#import "JPNavigationControllerGestureRecognizer.h"
#import "JPNavigationControllerKit.h"
#import "JPNavigationControllerProtocol.h"
#import "JPNavigationControllerTransition.h"
#import "JPPushAnimationTransition.h"
#import "JPTransitionShadowView.h"
#import "JPWarpNavigationController.h"
#import "JPWarpViewController.h"
#import "UIColor+ImageGenerate.h"
#import "UINavigationController+FulllScreenPopPush.h"
#import "UIView+ScreenCapture.h"
#import "UIViewController+ViewControllers.h"

FOUNDATION_EXPORT double JPNavigationControllerVersionNumber;
FOUNDATION_EXPORT const unsigned char JPNavigationControllerVersionString[];

