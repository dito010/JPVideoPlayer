//
//  JPWarpNavigationController.m
//  JPNavigationController
//
//  Hello! I am NewPan from Guangzhou of China, Glad you could use my framework, If you have any question or wanna to contact me, please open https://github.com/Chris-Pan or http://www.jianshu.com/users/e2f2d779c022/latest_articles
//

#import "JPWarpNavigationController.h"
#import "JPLinkContainerView.h"
#import "UINavigationController+JPLink.h"
#import "JPNavigationBar.h"
#import "JPNavigationController.h"
#import "UIViewController+JPNavigationController.h"
#import "UINavigationController+JPFullScreenPopGesture.h"
#import "JPManageSinglePopVCTool.h"

@interface JPWarpNavigationController()

/*!
 * \~english
 * Compatible pop gesture's link view in screen bottom.
 *
 * \~chinese
 * 兼容pop手势的底部联动视图
 */
@property(nonatomic, strong)JPLinkContainerView *linkView;

@end


#define kDefaultBackImageName @"JPImage.bundle/backImage"
#define JPScreenH [UIScreen mainScreen].bounds.size.height
#define JPScreenW [UIScreen mainScreen].bounds.size.width
@implementation JPWarpNavigationController

-(JPLinkContainerView *)linkView{
    if (!_linkView) {
        _linkView = [[JPLinkContainerView alloc]init];
        _linkView.backgroundColor = [UIColor clearColor];
        _linkView.frame = CGRectMake(0, JPScreenH - self.jp_linkViewHeight - 20, JPScreenW, self.jp_linkViewHeight);
        [self.navigationBar addSubview:_linkView];
    }
    return _linkView;
}

-(void)viewDidLoad{
    [super viewDidLoad];
    
    // Replace system's NavigationBar with custom NavigationBar.
    // 用自定义的NavigationBar替换系统的NavigationBar.
    
    JPNavigationBar *navBar = [[JPNavigationBar alloc]init];
    [self setValue:navBar forKey:@"navigationBar"];
    
    
    // Save root navigation Controller.
    // 保存根导航控制器
    
    self.jp_rootNavigationController = (JPNavigationController *)self.navigationController;
    
    
    // Monitor the notification of the range change about interactive pop allowed.
    // 监听最大pop手势范围改变通知
    
    SEL popNoteSel = @selector(setJp_interactivePopMaxAllowedInitialDistanceToLeftEdgeNote:);
    [[NSNotificationCenter defaultCenter]addObserver:self selector:popNoteSel name:kJp_interactivePopMaxNote object:nil];
}


-(void)dealloc{
    [[NSNotificationCenter defaultCenter]removeObserver:self name:kJp_interactivePopMaxNote object:nil];
    self.jp_rootNavigationController = nil;
    
    if (self.jp_linkView.superview) {
        [self.jp_linkView removeFromSuperview];
    }
}

-(void)addLinkView{
    // If jp_linkViewHeight>0, we think this instance have a link view in bottom.
    // If this instance have link view in bottom, this framework will check the viewController passed in by use is a class of UITableViewController or not, if yes, framework will add a contentInset for this viewController.
    // 如果jp_linkViewHeight大于0, 视为有底部联动视图.
    // 有了联动底部视图以后，如果传进来的控制器是一个UITableViewController,我们要为这个UITableViewController底部添加一个额外的滚动区域，防止联动底部视图挡住UITableViewController的内容
    
    UIViewController *childViewController = self.viewControllers.firstObject;
    if (self.jp_linkViewHeight > 0 && self.jp_linkView) {
        
        // Call user's viewDidLoad: method before JPWarpNavigationController's viewDidLoad:.
        // 先调用用户的控制器的viewDidLoad:方法, 再调用JPWarpNavigationController的viewDidLoad:方法
        
        self.jp_linkView.frame = CGRectMake(0, 0, [UIScreen mainScreen].bounds.size.width, self.jp_linkViewHeight);
        [self.linkView addSubview:self.jp_linkView];
        
        if ([childViewController isKindOfClass:[UITableViewController class]]) {
            UITableViewController *aVc = (UITableViewController *)self.viewControllers.firstObject;
            aVc.tableView.contentInset = UIEdgeInsetsMake(0, 0, self.jp_linkViewHeight, 0);
            // for test
            // NSLog(@"avc%@", NSStringFromUIEdgeInsets(aVc.tableView.contentInset));
        }
    }
}

-(void)setJp_interactivePopMaxAllowedInitialDistanceToLeftEdgeNote:(NSNotification *)note{
    
    // It always add observe for the range change of pop gesture when push a new viewController, this lead to all navigation controller will call this method, then lead to fix root navigation controller' pop gesture range agian and agian in once user change the pop gesture range. so we need to filter some repeated notificatoin by comparing user change pop gesture's navigation and self, we only change root navigation controller' pop gesture range when user change pop gesture's navigation is equal self.
    // 每次push都会为当前导航控制器添加监听, 这样一来每个导航控制器都会监听通知, 这样会导致每个导航控制器都来到这个方法, 重复修改根导航控制器的pop手势范围, 这里要用self和设置pop手势范围的导航控制器作对比, 也即是如果发通知和监听通知的控制器是同一控制器, 才更改根控制器的pop手势范围.
    
    NSDictionary *dict = note.object;
    CGFloat edgeValue = [dict[@"tempValue"] floatValue];
    UINavigationController *nav = dict[@"navigation"];
    if (self == nav) {
        self.jp_rootNavigationController.jp_interactivePopMaxAllowedInitialDistanceToLeftEdge = edgeValue;
    }
}

-(void)pushViewController:(UIViewController *)viewController animated:(BOOL)animated{
    
    JPNavigationController *nav = (JPNavigationController *)self.navigationController;
    viewController.jp_navigationController = nav;
    
    UIImage *backImage = [[UIImage imageNamed:kDefaultBackImageName] imageWithRenderingMode:UIImageRenderingModeAlwaysOriginal];
    viewController.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc]initWithImage:backImage style:UIBarButtonItemStylePlain target:self action:@selector(didTapBackButton)];
    
    // Watch out, here push a warped viewController(JPWarpViewController class).
    // 注意, 这里压入的是一个包装过后的控制器JPWarpViewController
    
    JPWarpViewController *warpViewController = [[JPWarpViewController new] warpViewController:viewController];
    viewController.jp_warpViewController = warpViewController;
    [nav pushViewController:warpViewController animated:animated];
}

-(void)didTapBackButton{
    [self.navigationController popViewControllerAnimated:YES];
}

-(UIViewController *)popViewControllerAnimated:(BOOL)animated{
    return [self.navigationController popViewControllerAnimated:animated];
}

-(NSArray<UIViewController *> *)popToRootViewControllerAnimated:(BOOL)animated{
    return [self.navigationController popToRootViewControllerAnimated:animated];
}

-(NSArray<UIViewController *> *)popToViewController:(UIViewController *)viewController animated:(BOOL)animated{
    
    // Watch out, when pop, we should find the warp viewController C(JPWarpViewController class), pop C.
    // 注意, pop时应该找到包裹viewController的那个JPWarpViewController, pop该控制器
    
    JPWarpViewController *warp = viewController.jp_warpViewController;
    return [self.navigationController popToViewController:warp animated:animated];
}

-(void)jp_popToViewControllerClassIs:(id)targetClass animated:(BOOL)animated{
    
    // Pop to target view controller, you just need to pass in the class of target view controller. It's easy to use than system's popToViewController: animated: method.
    // 弹出到指定类的控制器, 对应系统的 popToViewController: animated:方法.
    
    id targetVC = nil;
    NSArray *viewControllers = self.navigationController.viewControllers;
    for (JPWarpViewController *c in viewControllers) {
        UIViewController *vc = c.jp_passInViewController;
        if ([vc isKindOfClass:targetClass]) {
            targetVC = c;
        }
    }
    if (targetVC) {
        [self.navigationController popToViewController:targetVC animated:animated];
    }
}

-(void)dismissViewControllerAnimated:(BOOL)flag completion:(void (^)(void))completion{
    [self.navigationController dismissViewControllerAnimated:flag completion:completion];
}

@end
