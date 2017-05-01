//
//  JPWarpViewController.m
//  JPNavigationController
//
//  Hello! I am NewPan from Guangzhou of China, Glad you could use my framework, If you have any question or wanna to contact me, please open https://github.com/Chris-Pan or http://www.jianshu.com/users/e2f2d779c022/latest_articles
//

#import "JPWarpViewController.h"
#import "JPWarpNavigationController.h"
#import "UIViewController+JPNavigationController.h"

@interface JPWarpViewController()
/*!
 * \~english
 * The warpNav after warped the viewController user passed in(Lazy loading)
 *
 * \~chinese
 * 包装了用户传进来的控制器以后的warpNav(懒加载的)
 */
@property(nonatomic, weak)JPWarpNavigationController *warpNav;

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
@property(nonatomic, weak)UIViewController *jp_passInViewController;

@end


static NSValue *jp_tabBarRectValue;
@implementation JPWarpViewController

-(JPWarpViewController *)warpViewController:(UIViewController *)viewController{
    
    // Alloc warpNav as B, warp the viewController user passed by B, then warp the B by self become C.
    // 创建warpNav导航控制器B, 把用户传进来的控制器A用导航控制器B包装, 再将B用JPWarpViewController包装成为C
    
    JPWarpNavigationController *warpNav = [[JPWarpNavigationController alloc]init];
    warpNav.viewControllers = @[viewController];
    [self addChildViewController:warpNav];
    
    self.jp_passInViewController = viewController;
    self.warpNav = warpNav;
    
    // Reocrd the C(the outest warp ViewController) use to help manage close pop for signle viewControlle.
    // @see jp_closePopVCArr
    // 记录每个warpNav外包的viewController, 用来控制器单个页面的pop
    warpNav.jp_warpViewController = self;

    return self;
}

-(void)viewDidLoad{
    [super viewDidLoad];
    
    // Display the view of user's viewController(lazy loading style).
    // 显示用户viewController的view(懒加载的方式)
    
    [self.view addSubview:self.warpNav.view];
}

-(UIViewController *)warpedNavigationController{
    JPWarpNavigationController *warpNav = self.childViewControllers.firstObject;
    return warpNav.viewControllers.firstObject;
}

-(void)viewDidLayoutSubviews{
    [super viewDidLayoutSubviews];
    if (self.tabBarController && !jp_tabBarRectValue) {
        jp_tabBarRectValue = [NSValue valueWithCGRect:self.tabBarController.tabBar.frame];
    }
}

-(void)viewDidAppear:(BOOL)animated{
    [super viewDidAppear:animated];
    if (self.tabBarController && [self warpedNavigationController].hidesBottomBarWhenPushed) {
        self.tabBarController.tabBar.frame = CGRectZero;
    }
}

-(void)viewWillAppear:(BOOL)animated{
    [super viewWillAppear:animated];
    self.tabBarController.tabBar.translucent = YES;
    if (self.tabBarController && !self.tabBarController.tabBar.hidden && jp_tabBarRectValue) {
        self.tabBarController.tabBar.frame = jp_tabBarRectValue.CGRectValue;
    }
}

-(BOOL)hidesBottomBarWhenPushed{
    return [self warpedNavigationController].hidesBottomBarWhenPushed;
}

-(UITabBarItem *)tabBarItem{
    return [self warpedNavigationController].tabBarItem;
}

-(NSString *)title{
    return [self warpedNavigationController].title;
}

-(UIViewController *)childViewControllerForStatusBarStyle{
    return [self warpedNavigationController];
}

-(UIViewController *)childViewControllerForStatusBarHidden{
    return [self warpedNavigationController];
}

@end
