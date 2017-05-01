//
//  JPNavigationInteractiveTransition.m
//  JPNavigationController
//
//  Hello! I am NewPan from Guangzhou of China, Glad you could use my framework, If you have any question or wanna to contact me, please open https://github.com/Chris-Pan or http://www.jianshu.com/users/e2f2d779c022/latest_articles
//

#import "JPNavigationInteractiveTransition.h"
#import "JPPushAnimatedTransitioning.h"
#import "JPNavigationController.h"
#import "JPFullScreenPopGestureRecognizerDelegate.h"

@interface JPNavigationInteractiveTransition()

/*!
 * \~english
 * root navigation controller.
 *
 * \~chinese
 * 根导航控制器.
 */
@property (nonatomic, weak) JPNavigationController *nav;

/*!
 * \~english
 * Percent Driven Interactive Transition.
 *
 * \~chinese
 * 百分比手势驱动交互实例.
 */
@property (nonatomic, strong) UIPercentDrivenInteractiveTransition *interactivePopTransition;

/*!
 * \~english
 * is Gesture Push.
 *
 * \~chinese
 * 是否是Push.
 */
@property(nonatomic, assign)BOOL isGesturePush;

/*!
 * \~english
 * Animation srouce.
 *
 * \~chinese
 * 动画提供者.
 */
@property(nonatomic, strong)JPPushAnimatedTransitioning *transitioning;

/*!
 * \~english
 * Snap image.
 *
 * \~chinese
 * 截屏图片.
 */
@property(nonatomic, strong)UIImage *snapImage;

@end

// The borderline value devcide is need push or not when pan gesture end.
// 停止手势时判断是否需要push的临界值.
const CGFloat JPPushBorderlineDelta = 0.5;
@implementation JPNavigationInteractiveTransition

- (instancetype)initWithViewController:(UINavigationController *)nav{
    self = [super init];
    if (self) {
        self.nav = (JPNavigationController *)nav;
        [[NSNotificationCenter defaultCenter]addObserver:self selector:@selector(navigationDidScrolledRight:) name:kJp_navigationDidSrolledRight object:nil];
        [[NSNotificationCenter defaultCenter]addObserver:self selector:@selector(navigationDidScrolledLeft:) name:kJp_navigationDidSrolledLeft object:nil];
    }
    return self;
}

-(void)dealloc{
    [[NSNotificationCenter defaultCenter]removeObserver:self];
}

-(void)navigationDidScrolledRight:(NSNotification *)note{
    // pop
    UINavigationController *nav = note.object;
    if (nav == self.nav) {
        self.nav.delegate = nil;
    }
}

-(void)navigationDidScrolledLeft:(NSNotification *)note{
    // push
    NSDictionary *dict = note.object;
    UINavigationController *nav = dict[@"navigationController"];
    self.snapImage = dict[@"snapImage"];
    if (nav == self.nav) {
        self.nav.delegate = self;
    }
}

- (void)handleControllerPop:(UIPanGestureRecognizer *)recognizer {
    
    // This method be called when pan gesture start, because entrust system handle pop, so only handle push here.
    // Calculate the percent of the point origin-X / screen width, alloc UIPercentDrivenInteractiveTransition instance when push start, and check user is overrided the protocol method or not, if overrided, then start push and, set start percent = 0.
    // Refresh the slip percent when pan gesture changed.
    // Judge the slip percent is more than the JPPushBorderlineDelta when pan gesture end.
    // 当用户滑动的时候就会来到这个方法, 由于pop已经交给系统处理, 所以这里只负责处理push动画.
    // 先计算用户滑动的点占屏幕宽度的百分比, 当push开始的时候, 创建百分比手势驱动过渡动画, 检查用户有没有在这个界面设置需要push, 如果设置了, 就开始push, 并把起点百分比置为0.
    // 在用户滑动的过程中更新手势驱动百分比.
    // 在滑动结束的时候, 判断停止点是否已达到约定的需要pop的范围.
    
    CGFloat progress = [recognizer translationInView:recognizer.view].x / recognizer.view.bounds.size.width;
    CGPoint translation = [recognizer velocityInView:recognizer.view];
    if (recognizer.state == UIGestureRecognizerStateBegan) {
        self.isGesturePush = translation.x<0 ? YES : NO;
    }    
    if (self.isGesturePush) {
        progress = -progress;
    }
    progress = MIN(1.0, MAX(0.0, progress));
    
    if (recognizer.state == UIGestureRecognizerStateBegan) {
        if (self.isGesturePush) {
            if ([self.delegate respondsToSelector:@selector(didPushLeft:)]) {
                self.interactivePopTransition = [[UIPercentDrivenInteractiveTransition alloc] init];
                self.interactivePopTransition.completionCurve = UIViewAnimationCurveEaseOut;
                [self.delegate didPushLeft:self];
                [self.interactivePopTransition updateInteractiveTransition:0];
            }
        }
    }
    else if (recognizer.state == UIGestureRecognizerStateChanged) {
        [self.interactivePopTransition updateInteractiveTransition:progress];
    }
    else if (recognizer.state == UIGestureRecognizerStateEnded || recognizer.state == UIGestureRecognizerStateCancelled) {
        if (progress > JPPushBorderlineDelta) {
            [self.interactivePopTransition finishInteractiveTransition];
        }
        else {
            [self.interactivePopTransition cancelInteractiveTransition];
        }
        
        self.interactivePopTransition = nil;
        self.isGesturePush = NO;
        
        
        // Set root navigation controller's delegate be nil for follow user's gesture.
        // 置空导航控制器代理, 等待用户下一次滑动.
        
        self.nav.delegate = nil;
    }
}

- (id<UIViewControllerAnimatedTransitioning>)navigationController:(UINavigationController *)navigationController
                                  animationControllerForOperation:(UINavigationControllerOperation)operation
                                               fromViewController:(UIViewController *)fromVC
                                                 toViewController:(UIViewController *)toVC {
    
    // If the animation operation now is push, return custom transition.
    // 判断如果当前执行的是Push操作，就返回我们自定义的push动画对象。
    
    if (self.isGesturePush && operation == UINavigationControllerOperationPush) {
        self.transitioning.snapImage = self.snapImage;
        return self.transitioning;
    }
    return nil;
}


- (id<UIViewControllerInteractiveTransitioning>)navigationController:(UINavigationController *)navigationController
                         interactionControllerForAnimationController:(id<UIViewControllerAnimatedTransitioning>)animationController {

    // If the animationController is custom push instance, return interactivePopTransition to manage transition progress.
    // 判断动画对象animationController是我们自定义的Push动画对象，那么就返回interactivePopTransition来监控动画完成度。

    if (self.isGesturePush && [animationController isKindOfClass:[JPPushAnimatedTransitioning class]]) {
        return self.interactivePopTransition;
    }
    
    return nil;
}


# pragma mark --------------------------------------
# pragma mark Private

-(JPPushAnimatedTransitioning *)transitioning{
    if (!_transitioning) {
        _transitioning = [JPPushAnimatedTransitioning new];
    }
    return _transitioning;
}

@end
