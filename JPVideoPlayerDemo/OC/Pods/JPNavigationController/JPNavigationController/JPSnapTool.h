//
//  JPSnapTool.h
//  JPNavigationController
//
//  Hello! I am NewPan from Guangzhou of China, Glad you could use my framework, If you have any question or wanna to contact me, please open https://github.com/Chris-Pan or http://www.jianshu.com/users/e2f2d779c022/latest_articles
//

/**
 * This tool be used for screen shot and mix a shadow on left-slide for the view passed in.
 * 这个工具负责截屏以及混合图层阴影的功能.
 */

#import <UIKit/UIKit.h>

#define  JPScreenWidth   [UIScreen mainScreen].bounds.size.width
#define  JPScreenHeight  [UIScreen mainScreen].bounds.size.height
#define shadowWidth 24
@interface JPSnapTool : NSObject

/*!
 * \~english
 * Render the view's layer passed in generate an image.
 * @param view  The view need be shot.
 * @return      An image for the view of passed in.
 *
 * \~chinese
 * 将传进来的view进行截屏, 并返回截屏后的图片.
 * @param view  The view need be shot.
 * @return      An image for the view of passed in.
 */
+(UIImage *)snapShotWithView:(UIView *)view;

/*!
 * \~english
 * Render the view's layer passed in generate an image and, mix a shadow on image left-slide.
 * @param view  The view need be shot.
 * @return      An image for the view of passed in after mix a shadow on left-slide.
 *
 * \~chinese
 * 将传进来的view进行截屏, 然后在左侧合成一个阴影, 返回合成后的图片.
 * @param view  The view need be shot.
 * @return      An image for the view of passed in.
 */
+(UIImage *)mixShadowWithView:(UIView *)view;

/*!
 * \~english
 * Generate an image with the given color.
 * @param color    The given color.
 * @return         The image with the given color.
 *
 * \~chinese
 * 根据传入的颜色色值生成一张图片.
 * @param color    The given color.
 * @return         The image with the given color.
 */
+(UIImage *)imageWithColor:(UIColor *)color;

@end
