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

@class JPNavigationController;

/**
 * Just follow the JPNavigationControllerDelegate protocol and override the delegate method in this protocol,
 * use [self.navigationController pushViewController:aVc animated:YES]
 * if need push gesture transition animation when left slip.
 * You should preload the data of next viewController need to display for a good experience.
 */
@protocol JPNavigationControllerDelegate <NSObject>

@optional

/**
 * The delegate method need to override if need push gesture transition animation when left slip.
 *
 * @param navigationController the root navigation controller.
 */
-(void)navigationControllerDidPush:(JPNavigationController *)navigationController;

/**
 * Ask the delegate should response right slip.
 * You may need intercept the pop gesture and, handle your events. open this link to know about this 
 * https://github.com/newyjp/JPAnimation.
 *
 * @param navigationController the root navigation controller.
 *
 * @return the result of asking the delegate should framework response right slip gesture.
 */
-(BOOL)navigationControllerShouldStartPop:(JPNavigationController *)navigationController;;

@end

@interface JPNavigationController : UINavigationController<UIGestureRecognizerDelegate>

/*
 * view controllers in navigation controller's stack.
 */
@property(nonatomic, strong, nonnull,readonly) NSArray<UIViewController *> *jp_viewControllers;

@end

NS_ASSUME_NONNULL_END
