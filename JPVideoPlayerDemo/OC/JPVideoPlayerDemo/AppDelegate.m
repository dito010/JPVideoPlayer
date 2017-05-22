/*
 * This file is part of the JPVideoPlayer package.
 * (c) NewPan <13246884282@163.com>
 *
 * For the full copyright and license information, please view the LICENSE
 * file that was distributed with this source code.
 *
 * Click https://github.com/Chris-Pan
 * or http://www.jianshu.com/users/e2f2d779c022/latest_articles to contact me.
 */


#import "AppDelegate.h"
#import "JPVideoPlayerDemoVC_home.h"
#import "JPVideoPlayerDemoVC_Setting.h"
#import <JPNavigationControllerKit.h>

@interface AppDelegate ()

@end

@implementation AppDelegate

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    
    // 启动图片延时: 2 秒
    [NSThread sleepForTimeInterval:2];
    
    self.window = [[UIWindow alloc]initWithFrame:[UIScreen mainScreen].bounds];
    
    JPNavigationController *nav_home = [[JPNavigationController alloc]initWithRootViewController:[JPVideoPlayerDemoVC_home new]];
    nav_home.tabBarItem.image = [[UIImage imageNamed:@"player"] imageWithRenderingMode:UIImageRenderingModeAlwaysOriginal];
    nav_home.tabBarItem.selectedImage = [[UIImage imageNamed:@"player_select"] imageWithRenderingMode:UIImageRenderingModeAlwaysOriginal];
    nav_home.title = @"Player";
    
    JPNavigationController *nav_setting = [[JPNavigationController alloc]initWithRootViewController:[JPVideoPlayerDemoVC_Setting new]];
    nav_setting.tabBarItem.image = [[UIImage imageNamed:@"setting"] imageWithRenderingMode:UIImageRenderingModeAlwaysOriginal];
    nav_setting.tabBarItem.selectedImage = [[UIImage imageNamed:@"setting_select"] imageWithRenderingMode:UIImageRenderingModeAlwaysOriginal];
    nav_setting.title = @"Setting";
    
    UITabBarController *tabVC = [[UITabBarController alloc]init];
    tabVC.viewControllers = @[nav_home, nav_setting];
    tabVC.tabBar.tintColor = [UIColor colorWithRed:64.0/255.0 green:146.0/255.0 blue:75.0/255.0 alpha:1];
    
    self.window.rootViewController = tabVC;
    
    [self.window makeKeyAndVisible];
    
    [[UIApplication sharedApplication]setStatusBarHidden:NO withAnimation:UIStatusBarAnimationFade];
    
    return YES;
}

@end
