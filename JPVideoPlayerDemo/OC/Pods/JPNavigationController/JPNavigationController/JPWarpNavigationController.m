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

#import "JPWarpNavigationController.h"
#import "JPNavigationController.h"
#import "UIViewController+ViewControllers.h"
#import "JPWarpViewController.h"
#import "UIColor+ImageGenerate.h"
#import "UINavigationController+FulllScreenPopPush.h"
#import "JPNavigationControllerCompat.h"
#import "UIView+ScreenCapture.h"
#import "UINavigationBar+HitTest.h"

@interface JPWarpNavigationController ()

/**
 * The root navigation controller.
 */
@property(nonatomic, weak) JPNavigationController *rootNavigationController;

/**
 * Link container view.
 */
@property(nonatomic, strong) JPLinkContainerView *linkContainerView;

/*
 * initializedFlagOfTopViewController.
 */
@property(nonatomic, assign) BOOL initializedTopViewController;

@end

static NSString *const kJPWarpNavigationControllerBackImageName = @"JPNavigationController.bundle/jp_navigation_controller_back";

@implementation JPWarpNavigationController

- (instancetype)init{
    self = [super init];
    if (self) {
        [self _setup];
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    // default color for navigation bar.
    [self.navigationBar setBackgroundImage:[[UIColor whiteColor] jp_image] forBarMetrics:UIBarMetricsDefault];
    self.initializedTopViewController = NO;
}

- (void)viewWillLayoutSubviews {
    [super viewWillLayoutSubviews];
    
    NSArray<UIScrollView *> *scrollViews = [self  findAllScrollViewInView:self.topViewController.view];
    for (UIScrollView *scrollView in scrollViews) {
        // offset to the correct position.
        if (!self.initializedTopViewController) {
            [scrollView setContentOffset:CGPointMake(0, -scrollView.contentInset.top)];
            self.initializedTopViewController = YES;
        }
    }
}

- (UIViewController *)childViewControllerForStatusBarStyle{
    return self.topViewController;
}


#pragma mark - JPNavigationControllerProtocol

- (JPNavigationController *)jp_rootNavigationController{
    return self.rootNavigationController;
}

- (void)setJp_interactivePopMaxAllowedInitialDistanceToLeftEdge:(CGFloat)jp_interactivePopMaxAllowedInitialDistanceToLeftEdge{
    CGFloat distance = jp_interactivePopMaxAllowedInitialDistanceToLeftEdge;
    distance = MAX(0, distance);
    distance = MIN(distance, [UIScreen mainScreen].bounds.size.width);
    if (!self.rootNavigationController) {
        return;
    }
    [self.rootNavigationController setValue:@(distance) forKey:@"interactivePopMaxAllowedInitialDistanceToLeftEdge"];
}

- (CGFloat)jp_interactivePopMaxAllowedInitialDistanceToLeftEdge{
    if (self.rootNavigationController) {
        return [[self.rootNavigationController valueForKey:@"interactivePopMaxAllowedInitialDistanceToLeftEdge"] floatValue];
    }
    return JPScreenW;
}

- (void)setJp_closePopForCurrentViewController:(BOOL)jp_closePopForCurrentViewController{
    [self willChangeValueForKey:@"closePopForCurrentViewController"];
    _closePopForCurrentViewController = jp_closePopForCurrentViewController;
    [self didChangeValueForKey:@"closePopForCurrentViewController"];
}

- (BOOL)jp_closePopForCurrentViewController{
    return _closePopForCurrentViewController;
}

- (void)setJp_closePopForAllViewControllers:(BOOL)jp_closePopForAllViewControllers{
    if (!self.rootNavigationController) {
        return;
    }
    [self.rootNavigationController setValue:@(jp_closePopForAllViewControllers) forKey:@"closePopForAllViewControllers"];
}

- (BOOL)jp_closePopForAllViewControllers{
    if (self.rootNavigationController) {
        return [[self.rootNavigationController valueForKey:@"closePopForAllViewControllers"] boolValue];
    }
    return NO;
}

- (void)setJp_useCustomPopAnimationForCurrentViewController:(BOOL)jp_useCustomPopAnimationForCurrentViewController{
    [self willChangeValueForKey:@"useCustomPopAnimationForCurrentViewController"];
    _useCustomPopAnimationForCurrentViewController = jp_useCustomPopAnimationForCurrentViewController;
    
    if (jp_useCustomPopAnimationForCurrentViewController) {
        [self.userViewController.jp_warpViewController addPopGesture];
    }
    else{
        [self.userViewController.jp_warpViewController removePopGesture];;
    }
    
    [self didChangeValueForKey:@"useCustomPopAnimationForCurrentViewController"];
}

- (BOOL)jp_useCustomPopAnimationForCurrentViewController{
    return _useCustomPopAnimationForCurrentViewController;
}

- (void)jp_registerNavigtionControllerDelegate:(id<JPNavigationControllerDelegate>)delegate{
    [self willChangeValueForKey:@"navigationDelegate"];
    _navigationDelegate = delegate;
    [self didChangeValueForKey:@"navigationDelegate"];
}

- (void)jp_popToViewControllerWithClass:(Class _Nonnull __unsafe_unretained)targetClass handler:(JPNavigationContollerPopHandler)handler animated:(BOOL)animated {
    SEL sel = NSSelectorFromString(@"popToViewController:");
    NSMutableDictionary *arguments = [@{} mutableCopy];
    if (targetClass) {
        arguments[@"targetClassString"] = NSStringFromClass(targetClass);
    }
    if (handler) {
        arguments[@"handler"] = handler;
    }
    arguments[@"animated"] = @(animated);
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
    [self.rootNavigationController performSelector:sel withObject:[arguments copy]];
#pragma clang diagnostic pop
}

- (void)setJp_linkView:(UIView *)jp_linkView{
    [self willChangeValueForKey:@"linkView"];
    _linkView = jp_linkView;
    [self addLinkView];
    [self didChangeValueForKey:@"linkView"];
}

- (UIView *)jp_linkView{
    return _linkView;
}

- (void)setJp_linkViewHeight:(CGFloat)jp_linkViewHeight{
    [self willChangeValueForKey:@"linkViewHeight"];
    _linkViewHeight = jp_linkViewHeight;
    [self addLinkView];
    [self didChangeValueForKey:@"linkViewHeight"];
}

- (CGFloat)jp_linkViewHeight{
    return _linkViewHeight;
}


#pragma mark - Link View

- (void)addLinkView{
    // If jp_linkViewHeight > 0, we think have a link view in bottom.
    if (self.linkViewHeight > 0 && self.linkView) {
        
        if (self.linkView.superview) {
            return;
        }
        
        self.linkView.frame = CGRectMake(0, 0, [UIScreen mainScreen].bounds.size.width, self.linkViewHeight);
        [self.linkContainerView addSubview:self.linkView];
    }
}


#pragma mark - Override

- (void)pushViewController:(UIViewController *)viewController animated:(BOOL)animated{
    
    // call -initWithRootViewController: first view controller push in stack.
    JPNavigationController *rootNavigationController = [self rootNavigationController];
    if (!rootNavigationController) {
        [super pushViewController:viewController animated:animated];
        return;
    }
    
    // call pushViewController:animated:.
    viewController.jp_rootNavigationController = rootNavigationController;
    
    UIImage *backImg = [[UIImage imageNamed:kJPWarpNavigationControllerBackImageName] imageWithRenderingMode:UIImageRenderingModeAlwaysOriginal];
    viewController.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc]initWithImage:backImg style:UIBarButtonItemStylePlain target:self action:@selector(didTapBackButton)];
    
    
    JPWarpViewController *warpViewController = [[JPWarpViewController alloc]initWithRootViewController:viewController rootNavigationController:_rootNavigationController];
    
    // capture screen for custom pop if need.
    if (self.view.window) {
        viewController.jp_screenCaptureImg = [self.view.window jp_captureCurrentView];
    }
    
    [rootNavigationController pushViewController:warpViewController animated:animated];
}

- (UIViewController *)popViewControllerAnimated:(BOOL)animated{
    return [self.rootNavigationController popViewControllerAnimated:animated];
}

- (NSArray<UIViewController *> *)popToViewController:(UIViewController *)viewController animated:(BOOL)animated{
    JPWarpViewController *warpVc = viewController.jp_warpViewController;
    if (warpVc) {
        return [self.rootNavigationController popToViewController:warpVc animated:animated];
    }
    return nil;
}

- (NSArray<UIViewController *> *)popToRootViewControllerAnimated:(BOOL)animated{
    return [self.rootNavigationController popToRootViewControllerAnimated:animated];
}

- (void)presentViewController:(UIViewController *)viewControllerToPresent animated:(BOOL)flag completion:(void (^)(void))completion{
    [self.rootNavigationController presentViewController:viewControllerToPresent animated:flag completion:completion];
}

- (void)dismissViewControllerAnimated:(BOOL)flag completion:(void (^)(void))completion{
    [self.rootNavigationController dismissViewControllerAnimated:flag completion:completion];
}


#pragma mark - Private

static NSMutableArray<UIScrollView *>*_allScrollViews;
- (NSArray<UIScrollView *> *)findAllScrollViewInView:(UIView *)view {
    if (!_allScrollViews) {
        _allScrollViews = [NSMutableArray array];
    }
    [_allScrollViews removeAllObjects];
    return [self internalFindAllScrollViewInView:view];
}

- (NSArray<UIScrollView *> *)internalFindAllScrollViewInView:(UIView *)view {
    if ([view isKindOfClass:[UIScrollView class]]) {
        [_allScrollViews addObject:(UIScrollView *)view];
    }
    else {
        for (UIView *subview in view.subviews) {
            [self internalFindAllScrollViewInView:subview];
        }
    }
    
    return _allScrollViews;
}

- (JPLinkContainerView *)linkContainerView{
    if (!_linkContainerView) {
        _linkContainerView = [JPLinkContainerView new];
        _linkContainerView.backgroundColor = self.linkView.backgroundColor;
        
        // height == 812 is iPhone X.
        CGSize screenSize = [UIScreen mainScreen].bounds.size;
        CGFloat statusBarHeight = (NSInteger)screenSize.height == 812 ? 44.f : 20.f;
        CGFloat bottomSafeAreaHeight = (NSInteger)screenSize.height == 812 ? 34.f : 0.f;
        _linkContainerView.frame = CGRectMake(0, JPScreenH - self.linkViewHeight - statusBarHeight - bottomSafeAreaHeight, JPScreenW, self.linkViewHeight + bottomSafeAreaHeight);
        [self.navigationBar addSubview:_linkContainerView];
    }
    return _linkContainerView;
}

- (void)_setup{
    _closePopForCurrentViewController = NO;
    _useCustomPopAnimationForCurrentViewController = NO;
}

- (void)didTapBackButton{
    [self.rootNavigationController popViewControllerAnimated:YES];
}

- (UIViewController *)userViewController{
    return self.childViewControllers.firstObject;
}

@end
