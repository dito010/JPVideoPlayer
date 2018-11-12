//
//  UIView+EnlargeEdge.m
//  MonkeyKingTV
//
//  Created by 莫 剑锋 on 2017/8/17.
//  Copyright © 2017年 AppGame. All rights reserved.
//

#import "UIView+EnlargeEdge.h"
#import <objc/runtime.h>

static char *buttonEnlargeEdgeTopNameKey = "com.appgame.mktv.buttonEnlargeEdge.top";
static char *buttonEnlargeEdgeRightNameKey = "com.appgame.mktv.buttonEnlargeEdge.right";
static char *buttonEnlargeEdgeBottomNameKey = "com.appgame.mktv.buttonEnlargeEdge.bottom";
static char *buttonEnlargeEdgeLeftNameKey = "com.appgame.mktv.buttonEnlargeEdge.left";


@implementation UIView (EnlargeEdge)
- (void)setEnlargeEdge:(CGFloat) size{
    objc_setAssociatedObject(self, buttonEnlargeEdgeTopNameKey, [NSNumber numberWithFloat:size], OBJC_ASSOCIATION_COPY_NONATOMIC);
    objc_setAssociatedObject(self, buttonEnlargeEdgeRightNameKey, [NSNumber numberWithFloat:size], OBJC_ASSOCIATION_COPY_NONATOMIC);
    objc_setAssociatedObject(self, buttonEnlargeEdgeBottomNameKey, [NSNumber numberWithFloat:size], OBJC_ASSOCIATION_COPY_NONATOMIC);
    objc_setAssociatedObject(self, buttonEnlargeEdgeLeftNameKey, [NSNumber numberWithFloat:size], OBJC_ASSOCIATION_COPY_NONATOMIC);
}

- (void)setEnlargeEdgeWithTop:(CGFloat) top right:(CGFloat) right bottom:(CGFloat) bottom left:(CGFloat) left{
    objc_setAssociatedObject(self, buttonEnlargeEdgeTopNameKey, [NSNumber numberWithFloat:top], OBJC_ASSOCIATION_COPY_NONATOMIC);
    objc_setAssociatedObject(self, buttonEnlargeEdgeRightNameKey, [NSNumber numberWithFloat:right], OBJC_ASSOCIATION_COPY_NONATOMIC);
    objc_setAssociatedObject(self, buttonEnlargeEdgeBottomNameKey, [NSNumber numberWithFloat:bottom], OBJC_ASSOCIATION_COPY_NONATOMIC);
    objc_setAssociatedObject(self, buttonEnlargeEdgeLeftNameKey, [NSNumber numberWithFloat:left], OBJC_ASSOCIATION_COPY_NONATOMIC);
}

- (CGRect)enlargedRect{
    NSNumber* topEdge = objc_getAssociatedObject(self, buttonEnlargeEdgeTopNameKey);
    NSNumber* rightEdge = objc_getAssociatedObject(self, buttonEnlargeEdgeRightNameKey);
    NSNumber* bottomEdge = objc_getAssociatedObject(self, buttonEnlargeEdgeBottomNameKey);
    NSNumber* leftEdge = objc_getAssociatedObject(self, buttonEnlargeEdgeLeftNameKey);
    if (topEdge && rightEdge && bottomEdge && leftEdge){
        return CGRectMake(self.bounds.origin.x - leftEdge.floatValue,
                          self.bounds.origin.y - topEdge.floatValue,
                          self.bounds.size.width + leftEdge.floatValue + rightEdge.floatValue,
                          self.bounds.size.height + topEdge.floatValue + bottomEdge.floatValue);
    }
    else{
        return self.bounds;
    }
}
- (BOOL)mk_pointInside:(CGPoint)point withEvent:(UIEvent *)event{
    CGRect rect = [self enlargedRect];
    if (CGRectEqualToRect(rect, self.bounds)){
        return [self mk_pointInside:point withEvent:event];
    }
    return CGRectContainsPoint(rect, point) ? YES : NO;
}


+ (void)load
{
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        
        NSArray *selStringsArray = @[@"pointInside:withEvent:"];
        
        [selStringsArray enumerateObjectsUsingBlock:^(NSString *selString, NSUInteger idx, BOOL *stop) {
            NSString *mySelString = [@"mk_" stringByAppendingString:selString];
            
            Method originalMethod = class_getInstanceMethod(self, NSSelectorFromString(selString));
            Method myMethod = class_getInstanceMethod(self, NSSelectorFromString(mySelString));
            method_exchangeImplementations(originalMethod, myMethod);
        }];
    });
}

@end
