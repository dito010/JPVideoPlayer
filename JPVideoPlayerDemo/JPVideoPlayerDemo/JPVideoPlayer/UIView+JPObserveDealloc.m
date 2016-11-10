//
//  UIView+JPObserveDealloc.m
//  JPVideoPlayerDemo
//
//  Created by lava on 16/9/13.
//  Hello! I am NewPan from Guangzhou of China, Glad you could use my framework, If you have any question or wanna to contact me, please open https://github.com/Chris-Pan or http://www.jianshu.com/users/e2f2d779c022/latest_articles

#import "UIView+JPObserveDealloc.h"
#import <objc/runtime.h>

@implementation UIView (JPObserveDealloc)

+(void)load{
    
    // Exchange Method.
    
    Method sysMtd = class_getInstanceMethod(self, NSSelectorFromString(@"dealloc"));
    Method useMtd = class_getInstanceMethod(self, @selector(jp_dealloc));
    
    method_exchangeImplementations(sysMtd, useMtd);
}

-(void)jp_dealloc{
    
    // Post notificatoin.
    
    if (self.isShowView) {
        [[NSNotificationCenter defaultCenter]postNotificationName:@"kViewDeallocNote" object:self];
    }
    [self jp_dealloc];
}


#pragma mark --------------------------------------------------
#pragma mark Public

-(void)setIsShowView:(BOOL)isShowView{
    objc_setAssociatedObject(self, @selector(isShowView), @(isShowView), OBJC_ASSOCIATION_ASSIGN);
}

-(BOOL)isShowView{
    return [objc_getAssociatedObject(self, _cmd) boolValue];
}

@end
