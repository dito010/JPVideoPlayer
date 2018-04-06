
//
// Created by NewPan on 2018/3/30.
// Copyright (c) 2018 NewPan. All rights reserved.
//

#import "UITableViewCell+WebVideoCache.h"
#import <objc/runtime.h>

@implementation UITableViewCell (WebVideoCache)

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

@end