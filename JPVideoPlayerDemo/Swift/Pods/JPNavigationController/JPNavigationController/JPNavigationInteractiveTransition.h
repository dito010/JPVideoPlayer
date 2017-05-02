//
//  JPNavigationInteractiveTransition.h
//  JPNavigationController
//
//  Hello! I am NewPan from Guangzhou of China, Glad you could use my framework, If you have any question or wanna to contact me, please open https://github.com/Chris-Pan or http://www.jianshu.com/users/e2f2d779c022/latest_articles
//

/**
 * This class is responsible for observe user's push and pop action. it will set self be the delegate of root navigation controller and alloc UIPercentDrivenInteractiveTransition instance, return custom push transition animation when user push. it will set root navigation controller delegate be nil, let system handle pop gesture when pop.
 * 这个类负责监听用户的左滑push和右滑pop. 当监听到push的时候, 把根导航控制器的delegate设为自身, 并创建UIPercentDrivenInteractiveTransition实例, 返回自定义的push过渡动画, 在用户滑动的时候更新界面. 当监听到pop的时候, 把根导航控制器的delegate置nil, 由系统处理pop.
 */

#import <UIKit/UIKit.h>

@class UIViewController, UIPercentDrivenInteractiveTransition, JPNavigationInteractiveTransition;

@protocol JPNavigationInteractiveTransitionDelegate <NSObject>

@required
/*!
 * \~english
 * This method will be called when user left-slip.
 * @param navInTr   the delegate of root navigation controller.
 *
 * \~chinese
 * 当用户左滑push的时候会调用这个方法.
 * @param navInTr   根导航控制器代理.
 */
-(void)didPushLeft:(JPNavigationInteractiveTransition *)navInTr;

@end

@interface JPNavigationInteractiveTransition : NSObject <UINavigationControllerDelegate>

/*!
 * \~english
 * delegate
 *
 * \~chinese
 * 代理
 */
@property(nonatomic, strong)id<JPNavigationInteractiveTransitionDelegate> delegate;

/*!
 * \~english
 * Initialze Method.
 * @param nav  root navigation controller.
 * @return     a instance.
 *
 * \~chinese
 * 初始化方法
 * @param nav  根导航控制器.
 * @return     当前类的实例对象.
 */
- (instancetype)initWithViewController:(UINavigationController *)nav;

/*!
 * \~english
 * This method will be called when pan gesture be triggered.
 * @param recognizer    pan gesture.
 *
 * \~chinese
 * 当触发pan手势的时候会来到这个方法.
 * @param recognizer    pan手势.
 */
- (void)handleControllerPop:(UIPanGestureRecognizer *)recognizer;

@end
