//
//  JPFullScreenPopGestureRecognizerDelegate.h
//  JPNavigationController
//
//  Hello! I am NewPan from Guangzhou of China, Glad you could use my framework, If you have any question or wanna to contact me, please open https://github.com/Chris-Pan or http://www.jianshu.com/users/e2f2d779c022/latest_articles
//

/**
 * This class be used for the delegate of pan gesture and, judge pan gesture recognizer should begin.
 * This class always need to screen shot when push begain and, post this image to JPNavigationInteractiveTransition for push transition animation.
 * 这个类是自定义pan手势的代理, 它在gestureRecognizerShouldBegin:中判断是否允许手势执行.
 * 这个类还负责在left-slip开始的时候, 将窗口截屏并把截屏的图片发送给JPNavigationInteractiveTransition保存, 用于做push动画.
 */

#import <UIKit/UIKit.h>


// a note for navigation controller left slip.
static NSString * kJp_navigationDidSrolledLeft = @"Jp_navigationDidSrolledLeft";
// a note for navigation controller right slip.
static NSString * kJp_navigationDidSrolledRight = @"Jp_navigationDidSrolledRight";

@protocol JPFullScreenPopGestureRecognizerDelegate_Delegate <NSObject>

@optional
-(BOOL)navigationControllerLeftSlipShouldBegain;
-(BOOL)navigationControllerRightSlipShouldBegain;

@end

@interface JPFullScreenPopGestureRecognizerDelegate : NSObject<UIGestureRecognizerDelegate>

/*!
 * \~english
 * Root navigation controller.
 *
 * \~chinese
 * 根导航控制器.
 */
@property (nonatomic, weak) UINavigationController *navigationController;

/*!
 * \~english
 * Close or open pop gesture function for all viewcontrollers in current root navigation controller.
 *
 * \~chinese
 * 在当前根控制器内全局打开或关闭pop手势.
 */
@property(nonatomic, assign)BOOL closePopForAllVC;

/*!
 * \~english
 * System target event for pop.
 * @see JPNavigationController.
 *
 * \~chinese
 * 系统pop的target事件.
 * @see JPNavigationController.
 */
@property(nonatomic, strong)id target;

/*!
 * \~english
 * Delegate.
 *
 * \~chinese
 * Delegate.
 */
@property(nonatomic, weak)id<JPFullScreenPopGestureRecognizerDelegate_Delegate> delegate;

@end
