//
//  UIViewController+JPNavigationController.m
//
//  Hello! I am NewPan from Guangzhou of China, Glad you could use my framework, If you have any question or wanna to contact me, please open https://github.com/Chris-Pan or http://www.jianshu.com/users/e2f2d779c022/latest_articles
//

#import "UIViewController+JPNavigationController.h"
#import "objc/runtime.h"

@implementation UIViewController (JPNavigationController)

-(void)setJp_navigationController:(JPNavigationController *)jp_navigationController{
    objc_setAssociatedObject(self, @selector(jp_navigationController), jp_navigationController, OBJC_ASSOCIATION_ASSIGN);
}

-(JPNavigationController *)jp_navigationController{
    return objc_getAssociatedObject(self, _cmd);
}

-(void)setJp_warpViewController:(JPWarpViewController *)jp_warpViewController{
    objc_setAssociatedObject(self, @selector(jp_warpViewController), jp_warpViewController, OBJC_ASSOCIATION_ASSIGN);
}

-(JPWarpViewController *)jp_warpViewController{
    return objc_getAssociatedObject(self, _cmd);
}

@end
