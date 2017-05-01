//
//  JPManageSinglePopVCTool.h
//  JPNavigationController
//
//  Hello! I am NewPan from Guangzhou of China, Glad you could use my framework, If you have any question or wanna to contact me, please open https://github.com/Chris-Pan or http://www.jianshu.com/users/e2f2d779c022/latest_articles
//

/**
 * This is a singleton, be used for manage the single viewController who close pop, framework will check this class is saved the current pop viewController when use pop begain.
 * I try a way to handle this is that I save the hash of navigation view controller to replace save navigation view controller, this way should not add a strong refrence to the navigation view controller.
 * @see JPNavigationController.
 * 这是一个单例, 负责将用户关闭了pop手势的控制器的hash值保存起来, 等用户pop的时候来检查当前保存的关闭pop的控制器中是否有正在pop的控制器.
 * 这里我采用一种比较巧妙的方式, 就是只保存每个对象的hash值, 不引用控制器对象, 所以很巧妙地避免了给控制器增加strong引用的问题.
 * @see JPNavigationController.
 */

#import <UIKit/UIKit.h>

@interface JPManageSinglePopVCTool : NSObject

+(instancetype)shareTool;

/*!
 * \~english
 * The array of the single viewController who close pop, I try a way to handle this is that I save the hash of navigation view controller to replace save navigation view controller, this way should not add a strong refrence to the navigation view controller.
 *
 * \~chinese
 * 当前关闭了pop的单个VC, 数组里只记录控制器的hash值, 避免直接引用控制器导致控制器不能释放, 导致内存泄漏.
 */
@property(nonatomic, strong)NSArray *jp_closePopVCArr;

@end
