/*
 * This file is part of the JPVideoPlayer package.
 * (c) NewPan <13246884282@163.com>
 *
 * For the full copyright and license information, please view the LICENSE
 * file that was distributed with this source code.
 *
 * Click https://github.com/newyjp
 * or http://www.jianshu.com/users/e2f2d779c022/latest_articles to contact me.
 */

#import "AppDelegate.h"
#import "JPVideoPlayerWeiBoViewController.h"
#import "JPVideoPlayerSettingViewController.h"
#import "JPVideoPlayerDouyinViewController.h"
#import "JPVPNetEasyViewController.h"
#import "JPVideoPlayerManager.h"
#import "JPVideoPlayerCollectionViewController.h"
#import <JPNavigationControllerKit.h>

@interface AppDelegate ()

@end

@implementation AppDelegate

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    // 启动图片延时: 2 秒
//    [NSThread sleepForTimeInterval:2];
    
    self.window = [[UIWindow alloc]initWithFrame:[UIScreen mainScreen].bounds];
    
    JPNavigationController *weiboNavigationController = [[JPNavigationController alloc]initWithRootViewController:[JPVideoPlayerWeiBoViewController new]];
    weiboNavigationController.tabBarItem.image = [[UIImage imageNamed:@"jp_videoplayer_weibo"] imageWithRenderingMode:UIImageRenderingModeAlwaysOriginal];
    weiboNavigationController.tabBarItem.selectedImage = [[UIImage imageNamed:@"jp_videoplayer_weibo_selected"] imageWithRenderingMode:UIImageRenderingModeAlwaysOriginal];
    weiboNavigationController.title = @"微博";

    JPVideoPlayerDouyinViewController *douyinViewController = [JPVideoPlayerDouyinViewController new];
    douyinViewController.tabBarItem.image = [[UIImage imageNamed:@"jp_videoplayer_douyin"] imageWithRenderingMode:UIImageRenderingModeAlwaysOriginal];
    douyinViewController.tabBarItem.selectedImage = [[UIImage imageNamed:@"jp_videoplayer_douyin_selected"] imageWithRenderingMode:UIImageRenderingModeAlwaysOriginal];
    douyinViewController.title = @"抖音";
    
    JPNavigationController *netEasyNavigationController = [[JPNavigationController alloc] initWithRootViewController:[JPVPNetEasyViewController new]];
    netEasyNavigationController.tabBarItem.image = [[UIImage imageNamed:@"jp_videoplayer_netease"] imageWithRenderingMode:UIImageRenderingModeAlwaysOriginal];
    netEasyNavigationController.tabBarItem.selectedImage = [[UIImage imageNamed:@"jp_videoplayer_netease_selected"] imageWithRenderingMode:UIImageRenderingModeAlwaysOriginal];
    netEasyNavigationController.title = @"网易云音乐";

    JPNavigationController *collectionViewNavigationController = [[JPNavigationController alloc]initWithRootViewController:[[JPVideoPlayerCollectionViewController alloc]init]];
    collectionViewNavigationController.tabBarItem.image = [[UIImage imageNamed:@"jp_videoplayer_collectionview"] imageWithRenderingMode:UIImageRenderingModeAlwaysOriginal];
    collectionViewNavigationController.tabBarItem.selectedImage = [[UIImage imageNamed:@"jp_videoplayer_collectionview_selected"] imageWithRenderingMode:UIImageRenderingModeAlwaysOriginal];
    collectionViewNavigationController.title = @"CollectionView";
    
    JPNavigationController *settingNavigationController = [[JPNavigationController alloc]initWithRootViewController:[JPVideoPlayerSettingViewController new]];
    settingNavigationController.tabBarItem.image = [[UIImage imageNamed:@"jp_videoplayer_setting"] imageWithRenderingMode:UIImageRenderingModeAlwaysOriginal];
    settingNavigationController.tabBarItem.selectedImage = [[UIImage imageNamed:@"jp_videoplayer_setting_selected"] imageWithRenderingMode:UIImageRenderingModeAlwaysOriginal];
    settingNavigationController.title = @"设置";
    
    
    UITabBarController *tabVC = [[UITabBarController alloc]init];
    tabVC.viewControllers = @[weiboNavigationController, douyinViewController, netEasyNavigationController, collectionViewNavigationController, settingNavigationController];
    tabVC.tabBar.tintColor = [UIColor blackColor];
    tabVC.tabBar.backgroundImage = [UIImage imageNamed:@"jp_videoplayer_tabbar"];
    
    self.window.rootViewController = tabVC;
    [self.window makeKeyAndVisible];
    [[UIApplication sharedApplication]setStatusBarHidden:NO withAnimation:UIStatusBarAnimationFade];

    return YES;
}

@end
