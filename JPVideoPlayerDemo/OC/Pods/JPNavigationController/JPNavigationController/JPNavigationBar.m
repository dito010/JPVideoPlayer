//
//  JPNavigationBar.m
//  JPNavigationController
//
//  Hello! I am NewPan from Guangzhou of China, Glad you could use my framework, If you have any question or wanna to contact me, please open https://github.com/Chris-Pan or http://www.jianshu.com/users/e2f2d779c022/latest_articles
//

#import "JPNavigationBar.h"
#import "JPLinkContainerView.h"

@implementation JPNavigationBar

-(UIView *)hitTest:(CGPoint)point withEvent:(UIEvent *)event{
    
    JPLinkContainerView *linkView;
    for (UIView *subview in self.subviews) {
        if ([subview isKindOfClass:[JPLinkContainerView class]]) {
            linkView = (JPLinkContainerView *)subview;
            break;
        }
    }
    
    // Link view response touch events when the touch point on link view. keep system action otherwise.
    // 如果点击的点在联动视图linkView上, 就由linkView来响应事件.
    // 否则, 执行系统默认的做法.
    
    CGPoint viewP = [self convertPoint:point toView:linkView];
    if ([linkView pointInside:viewP withEvent:event]) {
        return [linkView hitTest:viewP withEvent:event];
    }
    else{
        return  [super hitTest:point withEvent:event];
    }
}

@end
