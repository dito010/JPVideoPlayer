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

#import "UIViewController+ViewControllers.h"
#import <objc/runtime.h>

static char kJPNavigationControllerRootNavigationKey;
static char kJPNavigationControllerWarpViewControllerKey;
static char kJPNavigationControllerScreenCaptureImageKey;

@implementation UIViewController (ViewControllers)

- (void)setJp_rootNavigationController:(JPNavigationController *)jp_rootNavigationController{
    objc_setAssociatedObject(self, &kJPNavigationControllerRootNavigationKey, jp_rootNavigationController, OBJC_ASSOCIATION_ASSIGN);
}

- (JPNavigationController *)jp_rootNavigationController{
    return objc_getAssociatedObject(self, &kJPNavigationControllerRootNavigationKey);
}

- (void)setJp_warpViewController:(JPWarpViewController *)jp_warpViewController{
    objc_setAssociatedObject(self, &kJPNavigationControllerWarpViewControllerKey, jp_warpViewController, OBJC_ASSOCIATION_ASSIGN);
}

- (JPWarpViewController *)jp_warpViewController{
    return objc_getAssociatedObject(self, &kJPNavigationControllerWarpViewControllerKey);
}

- (void)setJp_screenCaptureImg:(UIImage *)jp_screenCaptureImg{
    objc_setAssociatedObject(self, &kJPNavigationControllerScreenCaptureImageKey, jp_screenCaptureImg, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (UIImage *)jp_screenCaptureImg{
    return objc_getAssociatedObject(self, &kJPNavigationControllerScreenCaptureImageKey);
}

@end
