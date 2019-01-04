//
//  UICollectionViewCell+videoPlayer.m
//  ComponentDemo
//
//  Created by Xuzixiang on 2018/7/5.
//  Copyright © 2018年 frankxzx. All rights reserved.
//

#import "UICollectionViewCell+videoPlayer.h"
#import <objc/runtime.h>

@implementation UICollectionViewCell (videoPlayer)

- (void)setJp_videoURL:(NSURL *)jp_videoURL {
    objc_setAssociatedObject(self, @selector(jp_videoURL), jp_videoURL, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (NSURL *)jp_videoURL {
    return objc_getAssociatedObject(self, _cmd);
}

- (void)setJp_videoPlayView:(UIView *)jp_videoPlayView {
    objc_setAssociatedObject(self, @selector(jp_videoPlayView), jp_videoPlayView, OBJC_ASSOCIATION_ASSIGN);
}

- (UIView *)jp_videoPlayView {
    return objc_getAssociatedObject(self, _cmd);
}

- (void)setJp_unreachableCellType:(JPVideoPlayerUnreachableCellType)jp_unreachableCellType {
    objc_setAssociatedObject(self, @selector(jp_unreachableCellType), @(jp_unreachableCellType), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (JPVideoPlayerUnreachableCellType)jp_unreachableCellType {
    return [objc_getAssociatedObject(self, _cmd) integerValue];
}

- (BOOL)jp_isEqualToCell:(UICollectionViewCell *)cell {
    if(!self.jp_videoURL && !cell.jp_videoURL){
        return self == cell;
    }
    return [self.jp_videoURL.absoluteString isEqualToString:cell.jp_videoURL.absoluteString];
}


@end
