//
//  JPWarpNavigationController.h
//  JPNavigationController
//
//  Hello! I am NewPan from Guangzhou of China, Glad you could use my framework, If you have any question or wanna to contact me, please open https://github.com/Chris-Pan or http://www.jianshu.com/users/e2f2d779c022/latest_articles
//

/**
 * This class use for warping the viewController user passed in, this framework will warp all viewControllers user passed in by this class, so actually set navigationBar's properties of this class's  when user set navigationBar's properties.
 * It always call this class's matching method when user call pushViewController:animated: or popViewControllerAnimated: etc.. so we need to handle matching method in this class, it's mean that call the rootNavigationController's matching method.
 * This class have a custom NavigationBar(JPNavigationBar class), we add a link view as custom navigationBar's subview. this link view use for add hover view in screen bottom and this link can response pop gesture at the same time, this function always need in E-commerce's application. click this link for more detail http://www.jianshu.com/p/3ed21414551a.
 * @see JPNavigationBar
 * @see JPLinkContainerView
 * @see UINavigationController+JPLink
 *
 * 这个类是包装用户传进来的控制器的navigationController, 框架会为用户的每一个控制器都包装一个navigationController, 所以当用户设置导航条的属性的时候, 其实就是在设置这个导航控制器的导航条属性. 
 * 当用户调用pushViewController:animated:压入栈或者popViewControllerAnimated:出栈等方法的时候, 都会来到当前类的对应方法, 所以需要在当前类的对应方法中处理对应的入栈和出栈操作, 即调用根导航控制器的对应的入栈和出栈方法.
 * 这个类的NavigationBar是自定义的JPNavigationBar, 我们在NavigationBar上添加一个联动视图, 用来满足当ViewController需要在底部有个悬停且兼容pop手势的联动视图, 这个使用场景多数发生在电商APP上. 详细请参见我的简述文章http://www.jianshu.com/p/3ed21414551a
 */

#import <UIKit/UIKit.h>

@interface JPWarpNavigationController : UINavigationController

/*!
 * \~english
 * The UIViewController(JPWarpViewController class) warp this class.
 * Be used for manage close pop for single viewController.
 * @see JPManageSinglePopVCTool
 * @see closePopForCurViewControllerNote: in JPNavigationController
 *
 * \~chinese
 * Nav外包装的viewController(JPWarpViewController class).
 * 用来辅助管理关闭单个页面的pop手势.
 * @see JPManageSinglePopVCTool
 * @see closePopForCurViewControllerNote: in JPNavigationController
 */
@property(nonatomic, weak)UIViewController *jp_warpViewController;

@end
