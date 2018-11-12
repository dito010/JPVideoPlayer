//
//  UIView+EnlargeEdge.h
//  MonkeyKingTV
//
//  Created by 莫 剑锋 on 2017/8/17.
//  Copyright © 2017年 AppGame. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface UIView (EnlargeEdge)
- (void)setEnlargeEdge:(CGFloat) size;
- (void)setEnlargeEdgeWithTop:(CGFloat) top right:(CGFloat) right bottom:(CGFloat) bottom left:(CGFloat) left;
@end
