//
//  JPWarpViewController.h
//  JPNavigationController
//
//  Hello! I am NewPan from Guangzhou of China, Glad you could use my framework, If you have any question or wanna to contact me, please open https://github.com/Chris-Pan or http://www.jianshu.com/users/e2f2d779c022/latest_articles
//

/**
 * This class be used for warping the ViewController from user by UINavigationController, then warp the UINavigationController by UIViewController and pass the overall ViewController back. Wanna know more details please see http://www.jianshu.com/p/88bc827f0692
 * 这个类负责将用户的ViewController包装一层导航控制器, 再将这个导航控制器外面包装一层ViewController, 并将包装好的控制器返回.具体细节请看我的简书文章http://www.jianshu.com/p/88bc827f0692
 */

#import <UIKit/UIKit.h>

@interface JPWarpViewController : UIViewController

/*!
 * \~english
 * The view Controller user passed in(the view controller be pushed in navigationController's stack now)
 * Use for help find the viewController wanna pop to in method popToViewController:animated:
 * @see jp_rootNavigationController
 *
 * \~chinese
 * 用户传进来的控制器(当前压入栈的控制器)
 * 用于辅助 popToViewController:animated: 找到要pop到的控制器
 * @see jp_rootNavigationController
 */
@property(nonatomic, weak, readonly)UIViewController *jp_passInViewController;

/*!
 * \~english
 * This method be used for warping the ViewController from user by UINavigationController, then warp the UINavigationController by UIViewController and pass the overall ViewController back. Wanna know more details please see http://www.jianshu.com/p/88bc827f0692.
 * @param viewController    The viewController need be warped.
 * @reseult                 The viewController be warped.
 *
 * \~chinese
 * 这个方法用来将用户push的控制器A用导航控制器先包装成为B,再将B用JPWarpViewController包装一层成为C, 然后将包装好的C返回, 具体细节请看我的简书http://www.jianshu.com/p/88bc827f0692.
 * @param viewController    需要被warp的viewController.
 * @result                 包装好的viewController.
 */
-(JPWarpViewController *)warpViewController:(UIViewController *)viewController;

@end
