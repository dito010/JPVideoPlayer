//
//  JPNavigationController.h
//  JPNavigationController
//
//  Hello! I am NewPan from Guangzhou of China, Glad you could use my framework, If you have any question or wanna to contact me, please open https://github.com/Chris-Pan or http://www.jianshu.com/users/e2f2d779c022/latest_articles
//

/**
 * This class is the root navigation controller, it's navigationBar is hidden, it manage all push and pop function.
 * Please use initWithRootViewController: method to initialize this class just like system.
 * This class use UIPanGestureRecognizer to replace system's interactivePopGestureRecognizer and disable system's interactivePopGestureRecognizer. it set JPFullScreenPopGestureRecognizerDelegate be the delegate of pan gesture.
 * This class will add system's pop target to pan gesture and, deliver pop function to system. framework will delete the pop target when left-slip and, the framework will handle push transition animation by itself. you can see more detail in JPFullScreenPopGestureRecognizerDelegate.
 * This class will alloc a JPNavigationInteractiveTransition instance, it be use for update the class's delegate when need refresh. it work to let system handle pop transition animation when right-slip and, handle push transition animation by itself when left-slip happened.
 * This class be responsible for observering closing single viewController's pop gesture and closing all viewControllers's pop gesture, and handle those events.
 * This class is the delegate of JPNavigationInteractiveTransition and, responsible for handling is need push transition animation or not.
 *
 * @see JPFullScreenPopGestureRecognizerDelegate
 * @see JPNavigationInteractiveTransition
 * @see UINavigationController+JPFullScreenPopGesture
 *
 * 这个类是根导航控制器, 他的导航条是hidden的, 所有的控制器的push和pop操作都是由该控制器来管理.
 * 当你使用这个类的时候, 就像使用系统的UINavigationController一样, 使用initWithRootViewController:来初始化当前类.
 * 这个类里使用了UIPanGestureRecognizer替代系统的pop手势, 并且禁用了系统的pop手势. 设置JPFullScreenPopGestureRecognizerDelegate为pan手势的代理.
 * 这个类会在用户右滑时为pan添加系统的pop事件target, 把pop手势交给系统处理. 当用户左滑的时候, 会移除pop事件的target, 由框架去处理左滑对应的push事件. 这些都交给了JPFullScreenPopGestureRecognizerDelegate去实现.
 * 这个类会创建一个JPNavigationInteractiveTransition实例, 负责及时更新当前类的delegate, 当用户pop的时候移除代理, 由系统自己实现pop过渡动画. 在用户push的时候添加代理, 返回自己实现的过渡动画实例.
 * 这个类还监听用户关闭单个控制器和全局关闭pop手势的通知, 对应的处理和更新对应的事件.
 * 这个类是JPNavigationInteractiveTransition的代理, 在用户左滑push的时候检查需不需要执行push动画.
 */

#import <UIKit/UIKit.h>

/*!
 * \~english
 * Just follow the JPNavigationControllerDelegate protocol and override the delegate-method in this protocol use [self.navigationController pushViewController:aVc animated:YES] if need push gesture transition animation when left-slip.
 * You should preload the data of next viewController need to display for a good user experience.
 *
 * \~chinese
 * 如果需要在某个界面实现push左滑手势动画, 只需要遵守这个协议, 并且实现以下这个的协议方法, 在协议方法里使用[self.navigationController pushViewController:aVc animated:YES], 就可拥有左滑push动画了.
 * 关于数据预加载, 为了获得良好的用户体验, 建议在push之前就把要push到的页面的数据请求到本地, push过去直接能展示数据.
 */
@protocol JPNavigationControllerDelegate <NSObject>

@optional
/*!
 * \~english
 * The delegate method need to override if need push gesture transition animation when left-slip.
 *
 * \~chinese
 * 实现push左滑手势需要实现的代理方法.
 */
-(void)jp_navigationControllerDidPushLeft;

/*!
 * \~english
 * Ask the delegate should response right-slip.
 * @return  the result of asking the delegate should response right-slip.
 *
 * \~chinese
 * 是否可以响应右滑手势.
 * @return  the result of asking the delegate should response right-slip.
 */
-(BOOL)jp_navigationControllerShouldPushRight;

@end

@class JPWarpViewController;

@interface JPNavigationController : UINavigationController

/*!
 * \~english
 * The array of viewControllers in this navigationController stack(JPWarpViewController class).
 *
 * \~chinese
 * 根控制器栈里所有的viewControllers集合(JPWarpViewController class).
 */
@property (nonatomic, copy, readonly)NSArray<JPWarpViewController *> *jp_viewControllers;

@end



