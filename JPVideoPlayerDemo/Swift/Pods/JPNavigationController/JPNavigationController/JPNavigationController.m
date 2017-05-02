//
//  JPNavigationController.m
//  JPNavigationController
//
//  Hello! I am NewPan from Guangzhou of China, Glad you could use my framework, If you have any question or wanna to contact me, please open https://github.com/Chris-Pan or http://www.jianshu.com/users/e2f2d779c022/latest_articles
//

#import "JPNavigationController.h"
#import "UIViewController+JPNavigationController.h"
#import "JPWarpViewController.h"
#import "JPFullScreenPopGestureRecognizerDelegate.h"
#import "UINavigationController+JPFullScreenPopGesture.h"
#import "JPNavigationInteractiveTransition.h"
#import "JPWarpNavigationController.h"
#import "JPManageSinglePopVCTool.h"
#import "JPSnapTool.h"

#import <objc/runtime.h>

@interface JPNavigationController()<JPNavigationInteractiveTransitionDelegate, JPFullScreenPopGestureRecognizerDelegate_Delegate>

/*!
 * \~english
 * The instance of pan gesture.
 *
 * \~chinese
 * 全屏pan手势实例.
 */
@property (nonatomic, strong)UIPanGestureRecognizer *jp_fullscreenPopGestureRecognizer;

/*!
 * \~english
 * The delegate of pan gesture.
 *
 * \~chinese
 * pan手势代理者.
 */
@property (nonatomic, strong) JPFullScreenPopGestureRecognizerDelegate *jp_popGestureRecognizerDelegate;

/*!
 * \~english
 * The delegate of current navigation controller.
 *
 * \~chinese
 * 当前导航控制器代理
 */
@property(nonatomic, strong)JPNavigationInteractiveTransition *navInTr;

@end

@implementation JPNavigationController

-(instancetype)initWithRootViewController:(UIViewController *)rootViewController{
    
    // Initialize, you need care that here we push a warped view controller.
    // 实例化当前类, 注意这里是将用户的控制器先进行包装载压入栈. 更多细节请看JPWarpViewController
    
    self = [super initWithRootViewController:rootViewController];
    if (self) {
        rootViewController.jp_navigationController = self;
        JPWarpViewController *warp = [[JPWarpViewController new]warpViewController:rootViewController];
        self.viewControllers = @[warp];
    }
    return self;
}

-(instancetype)initWithCoder:(NSCoder *)aDecoder{
    self = [super initWithCoder:aDecoder];
    if (self) {
        self.viewControllers.firstObject.jp_navigationController = self;
        JPWarpViewController *warp = [[JPWarpViewController new]warpViewController:self.viewControllers.firstObject];
        self.viewControllers = @[warp];
    }
    return self;
}


-(void)viewDidLoad{
    [super viewDidLoad];
    
    // Hide navigation bar.
    // 隐藏导航栏
//    [self setNavigationBarHidden:YES];
    self.navigationBar.hidden = YES;
    
    
    // Add pan gesture(lazying load) and, add delegate to pan, close system interactivePopGestureRecognizer at the same time.
    // Default the range of pan gesture is full-sreen.
    // 添加pan手势(懒加载), 并为pan手势添加代理, 同时关闭系统的手势
    // 默认pan手势的范围为全屏支持pop.
    
    if (![self.interactivePopGestureRecognizer.view.gestureRecognizers containsObject:self.jp_fullscreenPopGestureRecognizer]) {
        [self.interactivePopGestureRecognizer.view addGestureRecognizer:self.jp_fullscreenPopGestureRecognizer];
        NSArray *targets = [self.interactivePopGestureRecognizer valueForKey:@"targets"];
        id target = [targets.firstObject valueForKey:@"target"];
        self.jp_fullscreenPopGestureRecognizer.delegate = [self jp_popGestureRecognizerDelegate];
        self.jp_popGestureRecognizerDelegate.target = target;
        
        self.interactivePopGestureRecognizer.enabled = NO;
        
        self.navInTr = [[JPNavigationInteractiveTransition alloc]initWithViewController:self];
        self.navInTr.delegate = self;
        [self.jp_fullscreenPopGestureRecognizer addTarget:self.navInTr action:@selector(handleControllerPop:)];

        self.jp_interactivePopMaxAllowedInitialDistanceToLeftEdge = [UIScreen mainScreen].bounds.size.width;
    }
    
    
    // Add observe for close single view controller notification and close all view controllers notificatoin.
    // 添加监听关闭所有控制器pop手势和关闭单个页面pop手势通知.
    
    [[NSNotificationCenter defaultCenter]addObserver:self selector:@selector(closePopForAllViewControllerNote:) name:kJp_closePopForAllViewControllersNote object:nil];
    [[NSNotificationCenter defaultCenter]addObserver:self selector:@selector(closePopForCurViewControllerNote:) name:kJp_closePopForCurrentViewControllerNote object:nil];
    [[NSNotificationCenter defaultCenter]addObserver:self selector:@selector(perfersStatusBarStyle:) name:kJp_prefersStatusBarStyleNote object:nil];
}

-(void)dealloc{
    [[NSNotificationCenter defaultCenter]removeObserver:self];
}


#pragma mark --------------------------------------------------
#pragma mark JPFullScreenPopGestureRecognizerDelegate_Delegate

-(BOOL)navigationControllerLeftSlipShouldBegain{
    
    // Find the displaying warp navigation controller first now when left-slip, check this navigation is overrided protocol method or not after, if yes, then return Yes For UIPanGestureDelegate.
    // 左滑push的时候, 先去找到当前在窗口的用于包装的导航控制器, 再检查这个控制器有没有遵守左滑push协议, 看这个界面有没有实现左滑调起push的代理方法, 如果实现了, 就告诉pan手势代理.可以执行pop.
    
    NSArray *childs = self.childViewControllers;
    JPWarpViewController *warp = (JPWarpViewController *)childs.lastObject;
    JPWarpNavigationController *nav = (JPWarpNavigationController *)warp.childViewControllers.firstObject;
    if (nav) {
        if ([nav.jp_pushDelegate respondsToSelector:@selector(jp_navigationControllerDidPushLeft)]) {
            return YES;
        }
    }
    return NO;
}

-(BOOL)navigationControllerRightSlipShouldBegain{
    
    // Ask the is need pop.
    // 右滑的时候检查用户是否允许pop继续
    
    NSArray *childs = self.childViewControllers;
    JPWarpViewController *warp = (JPWarpViewController *)childs.lastObject;
    JPWarpNavigationController *nav = (JPWarpNavigationController *)warp.childViewControllers.firstObject;
    if (nav) {
        if ([nav.jp_pushDelegate respondsToSelector:@selector(jp_navigationControllerShouldPushRight)]) {
            return [nav.jp_pushDelegate jp_navigationControllerShouldPushRight];
        }
        else{
            return YES;
        }
    }
    return NO;
}


# pragma mark --------------------------------------
# pragma mark JPNavigationInteractiveTransitionDelegate

-(void)didPushLeft:(JPNavigationInteractiveTransition *)navInTr{
    
    // Find the displaying warp navigation controller first now when left-slip, check this navigation is overrided protocol method or not after, if yes, call this method.
    // 左滑push的时候, 先去找到当前在窗口的用于包装的导航控制器, 再检查这个控制器有没有遵守左滑push协议, 看这个界面有没有实现左滑调起push的代理方法, 如果实现了, 就执行代理方法.
    
    NSArray *childs = self.childViewControllers;
    JPWarpViewController *warp = (JPWarpViewController *)childs.lastObject;
    JPWarpNavigationController *nav = (JPWarpNavigationController *)warp.childViewControllers.firstObject;
    if (nav) {
        if ([nav.jp_pushDelegate respondsToSelector:@selector(jp_navigationControllerDidPushLeft)]) {
            [nav.jp_pushDelegate jp_navigationControllerDidPushLeft];
        }
    }
}


#pragma mark --------------------------------------------------
#pragma mark Notification

-(void)perfersStatusBarStyle:(NSNotification *)note{
    
    // Every notification will call this method when alloc many instance of this class, so we need a flag to distinguish those notification, this flag is the root navigation controller. see jp_prefersStatusBarStyle.
    // 如果一次加载了多个nav, 通知混在一起了, 要用一个标示(临时关闭pop功能的根控制器)区分. 更多信息, 请看jp_prefersStatusBarStyle
    
    NSDictionary *dict = note.object;
    JPStatusBarStyle style = [dict[@"tempValue"] integerValue];
    JPNavigationController *nav= dict[@"rootNavigationForCurVC"];
    if (self == nav) {
        if (style & JPStatusBarStyleDefault) {
            self.navigationBar.barStyle = UIBarStyleDefault;
        }
        else if (style & JPStatusBarStyleLight){
            self.navigationBar.barStyle = UIBarStyleBlack;
        }
    }
}

-(void)closePopForAllViewControllerNote:(NSNotification *)note{
    
    // Every notification will call this method when alloc many instance of this class, so we need a flag to distinguish those notification, this flag is the root navigation controller. see jp_closePopForAllViewController.
    // 如果一次加载了多个nav, 通知混在一起了, 要用一个标示(临时关闭pop功能的根控制器)区分. 更多信息, 请看jp_closePopForAllViewController
    
    NSDictionary *dict = note.object;
    BOOL isClose = [dict[@"tempValue"] boolValue];
    JPNavigationController *nav= dict[@"rootNavigationForAllVC"];
    if (self == nav) {
        if (self.jp_popGestureRecognizerDelegate.closePopForAllVC != isClose) {
            self.jp_popGestureRecognizerDelegate.closePopForAllVC = isClose;
        }
    }
}

-(void)closePopForCurViewControllerNote:(NSNotification *)note{
    
    // Here need a flag to distinguish those notification too.
    // We need think about this question is that the manager of an array to record the close single navigation view controller's pop gesture is a singleton, so if we add a strong refrence to the navigation view controller, it always lead to the navigation view controller can not to be release and, leak will emerge at last.
    // For handle this problem, I try to refresh the refrence for navigation view controller when push and pop hanppen, but I cannot watch out all pop action like pop gesture, so this way is unfavorable.
    // I try a way to handle this is that I save the hash of navigation view controller to replace save navigation view controller, this way should not add a strong refrence to the navigation view controller.
    // 如果一次加载了多个nav, 通知混在一起了, 要用唯一标示(临时关闭pop功能的根控制器)区分开来
    // 这里有一个问题, 如果保存每个导航控制器到单例管理的数组中就会给导航控制器添加一个strong引用, 导致控制器释放不了, 最后出现内存泄漏
    // 并且我尝试在每一次根导航控制器入栈和出栈的时候更新单个需要关闭pop手势的数组, 释放对控制器的strong引用, 以缓解内存泄漏, 但是由于pop手势是交给系统处理的, 我无法监听到所有的pop, 所以还是不能理想的及时更新单个需要关闭pop手势的数组.
    // 这里我采用一种比较巧妙的方式, 就是只保存每个对象的hash值, 不引用控制器对象, 所以很巧妙地避免了引用的问题.
    
    NSDictionary *dict = note.object;
    BOOL isClose = [dict[@"tempValue"] boolValue];
    JPNavigationController *nav= dict[@"rootNavigationForCurVC"];
    JPWarpNavigationController *warpNav = dict[@"warpNav"];
    JPWarpViewController *warpViewController = (JPWarpViewController *)warpNav.jp_warpViewController;
    NSUInteger warpVCHash = [warpViewController hash];
    if (self == nav) {
        if (isClose) {
            
            // 添加关闭pop的VC
            
            NSMutableArray *arrM = [[JPManageSinglePopVCTool shareTool].jp_closePopVCArr mutableCopy];
            if (!arrM) {
                arrM = [NSMutableArray array];
            }
            [arrM addObject:@(warpVCHash)];
            [JPManageSinglePopVCTool shareTool].jp_closePopVCArr = [arrM copy];
        }
        else{
            
            // 移除关闭pop的VC
            
            NSMutableArray *arrM = [[JPManageSinglePopVCTool shareTool].jp_closePopVCArr mutableCopy];
            if ([arrM containsObject:@(warpVCHash)]) {
                [arrM removeObject:@(warpVCHash)];
            }
            [JPManageSinglePopVCTool shareTool].jp_closePopVCArr = [arrM copy];
        }
    }
}


# pragma mark --------------------------------------
# pragma mark Private

-(UIPanGestureRecognizer *)jp_fullscreenPopGestureRecognizer{
    if (!_jp_fullscreenPopGestureRecognizer) {
        _jp_fullscreenPopGestureRecognizer = [UIPanGestureRecognizer new];
        _jp_fullscreenPopGestureRecognizer.maximumNumberOfTouches = 1;
    }
    return _jp_fullscreenPopGestureRecognizer;
}

- (JPFullScreenPopGestureRecognizerDelegate *)jp_popGestureRecognizerDelegate{
    if (!_jp_popGestureRecognizerDelegate) {
        _jp_popGestureRecognizerDelegate = [JPFullScreenPopGestureRecognizerDelegate new];
        _jp_popGestureRecognizerDelegate.delegate = self;
        _jp_popGestureRecognizerDelegate.navigationController = self;
    }
    return _jp_popGestureRecognizerDelegate;
}

-(NSArray *)jp_viewControllers{
    NSMutableArray *arrM = [NSMutableArray array];
    for (JPWarpViewController *warpViewController in self.viewControllers) {
        [arrM addObject:warpViewController.jp_passInViewController];
    }
    return arrM.copy;
}

@end


