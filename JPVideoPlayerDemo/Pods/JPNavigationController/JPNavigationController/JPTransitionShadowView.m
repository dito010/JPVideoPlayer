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

#import "JPTransitionShadowView.h"
#import "JPNavigationControllerCompat.h"

static NSString *const kJPNavigationControllerShadowImagePath = @"JPNavigationController.bundle/jp_navigation_controller_shadow";
const CGFloat JPMixShadowViewShadowWidth = 21.f;
@implementation JPTransitionShadowView

- (instancetype)init{
    self = [super init];
    if (self) {
        [self setup];
    }
    return self;
}

- (void)layoutSubviews{
    [super layoutSubviews];
    
    _shadowImv.frame = CGRectMake(0, 0, JPScreenW + JPMixShadowViewShadowWidth, JPScreenH);
}


#pragma mark - Private

- (void)setup{
    self.backgroundColor = [UIColor clearColor];
    
    _shadowImv = ({
        UIImageView *imv = [UIImageView new];
        [self addSubview:imv];
        imv.image = [UIImage imageNamed:kJPNavigationControllerShadowImagePath];
        
        imv;
    });
}

@end
