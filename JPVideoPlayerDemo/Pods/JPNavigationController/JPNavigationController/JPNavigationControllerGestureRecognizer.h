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
#import "JPNavigationControllerCompat.h"

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSInteger, JPNavigationControllerGestureRecognizerType) {
    JPNavigationControllerGestureRecognizerTypeRoot = 0,
    JPNavigationControllerGestureRecognizerTypeWarp = 1
};

@interface JPNavigationControllerGestureRecognizer : UIPanGestureRecognizer

/**
 * The current transition type.
 */
@property(nonatomic, assign) JPNavigationControllerTransitionType transitionType;

/**
 * Gesture recognizer type.
 */
@property(nonatomic, assign) JPNavigationControllerGestureRecognizerType gestureType;

@end

NS_ASSUME_NONNULL_END
