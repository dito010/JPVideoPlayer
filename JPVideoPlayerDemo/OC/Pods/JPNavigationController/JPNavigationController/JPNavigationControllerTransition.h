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

NS_ASSUME_NONNULL_BEGIN

@class JPNavigationController, JPNavigationControllerTransition;

@protocol JPNavigationControllerTransitionDelegate <NSObject>

@optional
//- (void)

@end

@interface JPNavigationControllerTransition : NSObject<UINavigationControllerDelegate>

/**
 * Initialze Method.
 *
 * @param navigationController  root navigation controller.
 *
 * @return a instance.
 */
- (instancetype)initWithNavigationContollerViewController:(JPNavigationController *)navigationController;

/**
 * This method will be called when pan gesture be triggered.
 *
 * @param gestureRecognizer A instance of `UIPanGestureRecognizer`.
 */
- (void)gestureDidTriggered:(UIPanGestureRecognizer *)gestureRecognizer;

@end

NS_ASSUME_NONNULL_END
