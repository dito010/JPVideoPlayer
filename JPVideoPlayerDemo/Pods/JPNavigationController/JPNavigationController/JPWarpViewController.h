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

@class JPNavigationController;

NS_ASSUME_NONNULL_BEGIN

@interface JPWarpViewController : UIViewController

/**
 * The view Controller user passed in(the view controller be pushed in navigationController's stack now).
 * Use for help find the viewController wanna pop to in method popToViewController:animated:.
 *
 * @see jp_rootNavigationController
 */
@property(nonatomic, weak, readonly) UIViewController *userViewController;

/**
 * Initially method.
 * This method be used for warping the ViewController from user by UINavigationController, then warp the UINavigationController by UIViewController and pass the overall ViewController back. Wanna know more details please see http://www.jianshu.com/p/88bc827f0692.
 *
 * @param rootViewController The viewController need be warped.
 * @param rootNavigationController The root navigation controller, @see JPNavigationController.
 *
 * @return The viewController be warped.
 */
- (instancetype)initWithRootViewController:(UIViewController *)rootViewController rootNavigationController:(JPNavigationController *)rootNavigationController;

/**
 * Use customize pop gesture need add pop gesture in current viewController.
 */
- (void)addPopGesture;

/**
 * Remove pop gesture in current viewController.
 */
- (void)removePopGesture;

@end

NS_ASSUME_NONNULL_END
