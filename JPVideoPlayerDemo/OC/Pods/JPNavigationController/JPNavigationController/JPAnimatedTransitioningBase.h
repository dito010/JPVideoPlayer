//
//  JPAnimatedTransitioningBase.h
//  CustomPopAnimation
//
//  Hello! I am NewPan from Guangzhou of China, Glad you could use my framework, If you have any question or wanna to contact me, please open https://github.com/Chris-Pan or http://www.jianshu.com/users/e2f2d779c022/latest_articles
//

/**
 * This class is a super class for push animation.
 * 这里把这个类作为一个父类, push动画继承于这个类, 为push提供切换动画效果.
 */

#import <UIKit/UIKit.h>

@interface JPAnimatedTransitioningBase : NSObject<UIViewControllerAnimatedTransitioning>

/*!
 * \~english
 * Transition Duration.
 *
 * \~chinese
 * 动画执行时间.
 */
@property (nonatomic) NSTimeInterval  transitionDuration;

/*!
 * \~english
 * From view controller.
 *
 * \~chinese
 * 源控制器.
 */
@property (nonatomic, readonly, weak) UIViewController *fromViewController;

/*!
 * \~english
 * Target view controller.
 *
 * \~chinese
 * 目标控制器.
 */
@property (nonatomic, readonly, weak) UIViewController *toViewController;

/*!
 * \~english
 * containerView.
 *
 * \~chinese
 * containerView.
 */
@property (nonatomic, readonly, weak) UIView *containerView;

/*!
 * \~english
 * Animate Transition Event.
 *
 * \~chinese
 * 动画事件
 */
- (void)animateTransitionEvent;

/*!
 * \~english
 * complete Transition.
 *
 * \~chinese
 * 动画事件结束
 */
- (void)completeTransition;

@end
