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

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {

    var window: UIWindow?

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplicationLaunchOptionsKey: Any]?) -> Bool {
        
        // 启动图片延时: 2 秒
        Thread.sleep(forTimeInterval: 2)
        
        let screenSize = UIScreen.main.bounds.size
        window = UIWindow(frame: CGRect(x: 0, y: 0, width: screenSize.width, height: screenSize.height))
        let homeVC = JPVideoPlayerDemoVC_home()
        let nav = UINavigationController(rootViewController: homeVC)
        window?.rootViewController = nav
        window?.makeKeyAndVisible()
        
        UIApplication.shared.setStatusBarHidden(false, with: UIStatusBarAnimation.fade)
        
        return true
    }
}
