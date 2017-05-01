//
//  UIViewController+JPNavigationController.h
//
//  Hello! I am NewPan from Guangzhou of China, Glad you could use my framework, If you have any question or wanna to contact me, please open https://github.com/Chris-Pan or http://www.jianshu.com/users/e2f2d779c022/latest_articles
//

/**
 * You do not need to care about this category.
 * 这个分类是辅助JPNavigationController导航控制实现对应功能的, 用户不用关心.
 */

#import <UIKit/UIKit.h>
#import "JPNavigationController.h"
#import "JPWarpViewController.h"

@interface UIViewController (JPNavigationController)

/*!
 * \~english
 * The warped navigation controller.
 * @see JPWarpNavigationController.
 *
 * \~chinese
 * 每个VC外包的导航控制器.
 * @see JPWarpNavigationController.
 */
@property (nonatomic) JPNavigationController *jp_navigationController;

/*!
 * \~english
 * The warped view Controller.
 * @see JPWarpViewController.
 *
 * \~chinese
 * 用户传进来的VC外包的UIViewController.
 * @see JPWarpViewController.
 */
@property(nonatomic)JPWarpViewController *jp_warpViewController;

@end
