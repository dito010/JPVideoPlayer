/*
 * This file is part of the JPVideoPlayer package.
 * (c) NewPan <13246884282@163.com>
 *
 * For the full copyright and license information, please view the LICENSE
 * file that was distributed with this source code.
 *
 * Click https://github.com/Chris-Pan
 * or http://www.jianshu.com/users/e2f2d779c022/latest_articles to contact me.
 */


#import "UIView+PlayerStatusAndDownloadIndicator.h"
#import <objc/runtime.h>
#import "JPVideoPlayerPlayVideoTool.h"
#import "JPVideoPlayerActivityIndicator.h"

@interface UIView ()

@property(nonatomic)UIProgressView *progressView;

@property(nonatomic)UIView *videoLayerView;

@property(nonatomic)UIView *indicatorView;

@property(nonatomic)UIColor *progressViewTintColor;

@property(nonatomic)UIColor *progressViewBackgroundColor;

@property(nonatomic)JPVideoPlayerActivityIndicator *activityIndicatorView;

@end

static char progressViewKey;
static char progressViewTintColorKey;
static char progressViewBackgroundColorKey;
static char activityIndicatorViewKey;
static char videoLayerViewKey;
static char indicatorViewKey;
@implementation UIView (PlayerStatusAndDownloadIndicator)

#pragma mark -----------------------------------------
#pragma mark Public

-(void)perfersProgressViewColor:(UIColor * _Nonnull)tintColor{
    if (tintColor)
        self.progressViewTintColor = tintColor;
}

-(void)perfersProgressViewBackgroundColor:(UIColor * _Nonnull)backgroundColor{
    if (backgroundColor) {
        self.progressViewBackgroundColor = backgroundColor;
    }
}

-(void)showProgressView{
    if (!self.progressView.superview) {
        [self.indicatorView addSubview:self.progressView];
        self.progressView.progress = 0;
        self.progressView.hidden = NO;
    }
}

-(void)hideProgressView{
    if (self.progressView.superview) {
        self.progressView.hidden = YES;
        [self.progressView removeFromSuperview];
    }
}

-(void)progressViewStatusChangedWithReceivedSize:(NSUInteger)receivedSize expectSize:(NSUInteger)expectSize{
    CGFloat progress = (CGFloat)receivedSize/expectSize;
    progress = MAX(0, progress);
    progress = MIN(progress, 1);
    self.progressView.progress = progress;
}

-(void)showActivityIndicatorView{
    if (!self.activityIndicatorView.superview) {
        [self.indicatorView addSubview:self.activityIndicatorView];
        [self.activityIndicatorView startAnimating];
    }
}

-(void)hideActivityIndicatorView{
    if (self.activityIndicatorView.superview) {
        [self.activityIndicatorView stopAnimating];
        [self.activityIndicatorView removeFromSuperview];
    }
}

-(void)setupVideoLayerViewAndIndicatorView{
    if (!self.videoLayerView.superview && !self.indicatorView.superview) {
        [self addSubview:self.videoLayerView];
        [self addSubview:self.indicatorView];
    }
}

-(void)removeVideoLayerViewAndIndicatorView{
    if (self.videoLayerView.superview && self.indicatorView.superview) {
        [self.videoLayerView removeFromSuperview];
        [self.indicatorView removeFromSuperview];
    }
}


#pragma mark -----------------------------------------
#pragma mark Progress

-(void)setProgressViewTintColor:(UIColor *)progressViewTintColor{
    objc_setAssociatedObject(self, &progressViewTintColorKey, progressViewTintColor, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

-(UIColor *)progressViewTintColor{
    UIColor *color = objc_getAssociatedObject(self, &progressViewTintColorKey);
    if (!color) {
        color = [UIColor colorWithRed:0.0/255 green:118.0/255 blue:255.0/255 alpha:1];
    }
    return color;
}

-(void)setProgressViewBackgroundColor:(UIColor *)progressViewBackgroundColor{
    objc_setAssociatedObject(self, &progressViewBackgroundColorKey, progressViewBackgroundColor, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

-(UIColor *)progressViewBackgroundColor{
    UIColor *color = objc_getAssociatedObject(self, &progressViewTintColorKey);
    if (!color) {
        color = [UIColor colorWithRed:155.0/255 green:155.0/255 blue:155.0/255 alpha:1.0];
    }
    return color;
}

-(UIProgressView *)progressView{
    UIProgressView *progressView = objc_getAssociatedObject(self, &progressViewKey);
    if (!progressView) {
        progressView = [UIProgressView new];
        progressView.hidden = YES;
        progressView.frame = CGRectMake(0, 0, self.frame.size.width, JPVideoPlayerLayerFrameY);
        progressView.tintColor = self.progressViewTintColor;
        progressView.backgroundColor = self.progressViewBackgroundColor;
        objc_setAssociatedObject(self, &progressViewKey, progressView, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    return progressView;
}

-(JPVideoPlayerActivityIndicator *)activityIndicatorView{
    JPVideoPlayerActivityIndicator *acv = objc_getAssociatedObject(self, &activityIndicatorViewKey);
    if (!acv) {
        acv = [JPVideoPlayerActivityIndicator new];
        CGSize viewSize = self.frame.size;
        CGFloat selfX = (viewSize.width-ActivityIndicatorWH)*0.5;
        CGFloat selfY = (viewSize.height-ActivityIndicatorWH)*0.5;
        acv.frame = CGRectMake(selfX, selfY, ActivityIndicatorWH, ActivityIndicatorWH);
        acv.hidden = YES;
        objc_setAssociatedObject(self, &activityIndicatorViewKey, acv, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    return acv;
}

-(UIView *)videoLayerView{
    UIView *view = objc_getAssociatedObject(self, &videoLayerViewKey);
    if (!view) {
        view = [UIView new];
        view.frame = self.bounds;
        view.backgroundColor = [UIColor clearColor];
        view.userInteractionEnabled = NO;
        objc_setAssociatedObject(self, &videoLayerViewKey, view, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    return view;
}

-(UIView *)indicatorView{
    UIView *view = objc_getAssociatedObject(self, &indicatorViewKey);
    if (!view) {
        view = [UIView new];
        view.frame = self.bounds;
        view.backgroundColor = [UIColor clearColor];
        view.userInteractionEnabled = NO;
        objc_setAssociatedObject(self, &indicatorViewKey, view, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    return view;
}

@end
