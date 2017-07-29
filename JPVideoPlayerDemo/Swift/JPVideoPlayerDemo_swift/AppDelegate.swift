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

import UIKit
import JPNavigationController

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {

    var window: UIWindow?

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplicationLaunchOptionsKey: Any]?) -> Bool {
        
        // 启动图片延时: 2 秒
        Thread.sleep(forTimeInterval: 2)
        
        let screenSize = UIScreen.main.bounds.size
        window = UIWindow(frame: CGRect(x: 0, y: 0, width: screenSize.width, height: screenSize.height))
        
        let homeVC = JPVideoPlayerDemoVC_home()
        let nav_home = JPNavigationController(rootViewController: homeVC)
        nav_home.tabBarItem.image = #imageLiteral(resourceName: "player")
        nav_home.tabBarItem.selectedImage = #imageLiteral(resourceName: "player_select")
        nav_home.tabBarItem.title = "Player"
        
        let settingVC = JPVideoPlayerDemoVC_Setting()
        let nav_setting = JPNavigationController(rootViewController: settingVC)
        nav_setting.tabBarItem.image = #imageLiteral(resourceName: "setting")
        nav_setting.tabBarItem.selectedImage = #imageLiteral(resourceName: "setting_select")
        nav_setting.tabBarItem.title = "Setting"
        
        let tabVC = UITabBarController()
        tabVC.viewControllers = [nav_home, nav_setting]
        tabVC.tabBar.tintColor = UIColor(red: 64.0/255.0, green: 146.0/255.0, blue: 75.0/255.0, alpha: 1.0)
        
        window?.rootViewController = tabVC
        window?.makeKeyAndVisible()
        
        UIApplication.shared.setStatusBarHidden(false, with: UIStatusBarAnimation.fade)
        
        return true
    }
}
