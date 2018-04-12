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

#import "UINavigationBar+HitTest.h"
#import <objc/runtime.h>

@implementation JPLinkContainerView

@end

@implementation UINavigationBar (HitTest)

+ (void)load {
    Method cus = class_getInstanceMethod(self, @selector(jp_hitTest:withEvent:));
    Method sys = class_getInstanceMethod(self, @selector(hitTest:withEvent:));
    
    method_exchangeImplementations(sys, cus);
}

- (UIView *)jp_hitTest:(CGPoint)point withEvent:(UIEvent *)event{
    
    __block JPLinkContainerView *linkView;
    [self.subviews enumerateObjectsUsingBlock:^(__kindof UIView * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        
        if ([obj isKindOfClass:[JPLinkContainerView class]]) {
            linkView = (JPLinkContainerView *)obj;
            *stop = YES;
        }
    }];
    
    // Link view response touch events when the touch point on link view. keep system action otherwise.
    
    CGPoint viewP = [self convertPoint:point toView:linkView];
    if ([linkView pointInside:viewP withEvent:event]) {
        return [linkView hitTest:viewP withEvent:event];
    }
    else{
        return  [self jp_hitTest:point withEvent:event];
    }
}

@end
