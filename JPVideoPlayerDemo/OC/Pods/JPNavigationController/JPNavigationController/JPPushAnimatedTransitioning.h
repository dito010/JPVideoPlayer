//
//  JPPushAnimatedTransitioning.h
//  JPNavigationControllerDemo
//
//  Hello! I am NewPan from Guangzhou of China, Glad you could use my framework, If you have any question or wanna to contact me, please open https://github.com/Chris-Pan or http://www.jianshu.com/users/e2f2d779c022/latest_articles
//

/**
 * This class provide push animation for interative transition and, it subclass of JPAnimatedTransitioningBase.
 * Shot screen and alloc an instance of UIImageView A to display this image and, add A as a subview to containerView when push begain, check it have a tabBar in current window at the same time, then set tabBar.hidden be YES. the reason of to do this is that the tabBar layer is above the containerView, so we cannot performance graciously the interative transition.
 * We need to shot the toViewController's view as an image and mix a shadow at image's left slide.
 * So we performance interative transition elements are two pictures.
 * JPSnapTool content screen shot and mix shadow function.
 * 这个类继承于JPAnimatedTransitioningBase, 为push提供切换动画效果.
 * 这个类的具体的切换动画实现思路为, 当用户左滑开始触发push的时候, 把当前的界面截屏, 并创建一个UIImageView实例A来展现截屏, 把这个A作为subview添加到动画容器containerView中, 并且判断如果当前窗口有tabBar, 那么先把tabBar.hidden设为YES. 这么做的原因就是, 当当前窗口有显示tabBar的时候, tabBar图层是在动画容器图层之上的, 所以我们无法优雅的做百分手势驱动.
 * 与此同时, 把目标控制器的视图截图保存, 并且为这张截图的左侧合成一个阴影来模仿系统的阴影.
 * 所以实质上我们看到的百分比手势驱动的是两张图片在做过渡动画.
 * 截屏和合成阴影是由JPSnapTool负责实现的.
 */

#import "JPAnimatedTransitioningBase.h"

@interface JPPushAnimatedTransitioning : JPAnimatedTransitioningBase

/*!
 * \~english
 * The image of screen shot before push begain.
 *
 * \~chinese
 * push之前窗口截屏的图片
 */
@property(nonatomic, strong)UIImage *snapImage;

@end
