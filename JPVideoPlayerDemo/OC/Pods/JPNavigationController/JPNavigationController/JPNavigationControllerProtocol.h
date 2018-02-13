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

#import "JPNavigationController.h"

NS_ASSUME_NONNULL_BEGIN

// When use jp_popToViewControllerClass:handle:animated:, may some error happened, or may more than one viewControllers are the same class, developers will be notificated use this block if this situation happened.
typedef UIViewController *_Nullable(^JPNavigationContollerPopHandler)(NSArray<UIViewController *> * _Nullable viewControllers, NSError * _Nullable error);

@protocol JPNavigationControllerProtocol <NSObject>

#pragma mark - Properties

/**
 * The root navigation controller.
 *
 * @see JPNavigationController
 */
@property(nonatomic, readonly) JPNavigationController * jp_rootNavigationController;

/**
 * The biggest distance allow pop leave screen left slide in current root navigation controller.
 * Full screen width by default, mean can call pop anywhere in screen.
 */
@property (nonatomic) CGFloat jp_interactivePopMaxAllowedInitialDistanceToLeftEdge;

/**
 * Close or open pop gesture for current viewController in current root navigation controller.
 * NO by default.
 */
@property(nonatomic) BOOL jp_closePopForCurrentViewController;

/**
 * Close or open pop gesture for all viewControllers in current root navigation controller.
 * NO by default.
 */
@property(nonatomic) BOOL jp_closePopForAllViewControllers;

/**
 * Use custom pop animation for current viewController in current root navigation controller.
 * Default is NO.
 *
 * This property always be used in situations that the current viewController need to play video or audio by `AVPlayer`, or need to play `CoreAnimation`, because system have some bugs on this situations.
 *
 * @watchout:
 *  If set this property as YES, framework will insert a image carptured from `toViewController` as background in current viewController, and make the view of current viewController to move drived by a binded `UIPanGestureRecognizer` when excute the pop animation actually.
 *  So the -viewWillDisappear:, -viewDidDisappear:, -viewWillAppear:, -viewDidAppear: will never be called when excute custom pop animation.
 */
@property(nonatomic) BOOL jp_useCustomPopAnimationForCurrentViewController;

/**
 * Link view height at screen bottom.
 */
@property(nonatomic)CGFloat jp_linkViewHeight;

/**
 * Link view at screen bottom.
 * You just need pass your link view to this property, framework will display your link view automatically.
 *
 * @see `JPWarpNavigationController`.
 */
@property(nonatomic)UIView * jp_linkView;

#pragma mark - Method

/**
 * Register delegate to observer the delegate events.
 *
 * @param delegate A instance implementation `JPNavigationControllerDelegate` protocol.
 * 
 * @see JPNavigationControllerDelegate.
 */
- (void)jp_registerNavigtionControllerDelegate:(id<JPNavigationControllerDelegate>)delegate;

/**
 * Pop to target view controller, you just need to pass in the class of target view controller. It's easy to use than system's popToViewController: animated: method.
 *
 * @param targetClass        The class of viewController need pop to, it should be pushed in root navigationController.
 * @param handler            May some error happened, or may more than one viewControllers are the same class, developers will be notificated use this block if this situation happened.
 *   Pass nil means that if existed many viewControllers for given class, framework will pop the first object in viewControllers array.
 *
 *   First param viewControllers  This method will find all the `UIViewController` instance in stack of root navigation controller for given class,so this array may have multi-elements. And all the viewControllers will ordered by the order of the instance in stack of root navigation controller.
 *
 *   Secondary param error        If not found a `UIViewController` instance in stack of root navigation controller for given class, error will have value.
 *
 *   Return `UIViewController`    Return the need to pop `UIViewController` instance.
 *
 * @param animated          The flag of need animation or not.
 * 
 * @code
 *
 *  [self.navigationController jp_popToViewControllerWithClass:[JPNavigationControllerDemo_linkBar class] handler:^UIViewController * _Nullable(NSArray<UIViewController *> * _Nullable viewControllers, NSError * _Nullable error) {
 *
 *      if (!error) {
 *           return viewControllers.firstObject;
 *      }
 *       else{
 *          NSLog(@"%@", error);
 *          return nil;
 *      }
 *
 *   } animated:YES];
 *
 * @endcode
 */
- (void)jp_popToViewControllerWithClass:(Class _Nonnull __unsafe_unretained)targetClass handler:(JPNavigationContollerPopHandler _Nullable)handler animated:(BOOL)animated;

@end

NS_ASSUME_NONNULL_END

