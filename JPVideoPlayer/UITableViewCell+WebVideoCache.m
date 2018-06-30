/*
 * This file is part of the JPVideoPlayer package.
 * (c) NewPan <13246884282@163.com>
 *
 * For the full copyright and license information, please view the LICENSE
 * file that was distributed with this source code.
 *
 * Click https://github.com/newyjp
 * or http://www.jianshu.com/users/e2f2d779c022/latest_articles to contact me.
 */

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

- (void)setJp_unreachableCellType:(JPVideoPlayerUnreachableCellType)jp_unreachableCellType {
    objc_setAssociatedObject(self, @selector(jp_unreachableCellType), @(jp_unreachableCellType), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (JPVideoPlayerUnreachableCellType)jp_unreachableCellType {
    return [objc_getAssociatedObject(self, _cmd) integerValue];
}

- (BOOL)jp_isEqualToCell:(UITableViewCell *)cell {
    if(!self.jp_videoURL && !cell.jp_videoURL){
        return self == cell;
    }
    return [self.jp_videoURL.absoluteString isEqualToString:cell.jp_videoURL.absoluteString];
}

@end