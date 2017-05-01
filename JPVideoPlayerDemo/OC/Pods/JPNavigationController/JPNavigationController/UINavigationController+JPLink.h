//
//  UINavigationController+JPLink.h
//  JPNavigationController
//
//  Hello! I am NewPan from Guangzhou of China, Glad you could use my framework, If you have any question or wanna to contact me, please open https://github.com/Chris-Pan or http://www.jianshu.com/users/e2f2d779c022/latest_articles
//

/**
 * This category be used for easy use link view.
 * 这是导航控制器的分类, 用来负责方便用户使用底部联动视图.
 */

#import <UIKit/UIKit.h>

@class JPLinkContainerView;

@interface UINavigationController (JPLink)

/*!
 * \~english
 * Link view height on screen bottom.
 *
 * \~chinese
 * 底部联动视图的高度.
 */
@property(nonatomic)CGFloat jp_linkViewHeight;

/*!
 * \~english
 * Link view on screen bottom.
 * You just need pass your link view to this property, framework will display your link view automatically.
 * Watch out: If the of current display in window is a UITableViewController class, frame will add a contentInset automatically to avoid the link view cover on UITableViewController. but if you add a UITableView on UIViewController's, framework will do nothing for that, you may handle this by yourself.
 * @see JPWarpNavigationController
 *
 * \~chinese
 * 联动底部视图.
 * 你只需要在viewDidLoad:方法里把你的联动视图传给框架, 框架会制动帮你显示.
 * 注意 : 如果识别到你当前控制器为UITableViewController的时候, 如果有联动底部视图, 就会自动为你添加jp_linkViewHeight高度的底部额外滚动区域. 但是, 如果你的控制器是UIViewController上添加了UITableView, 那我不会自动为你添加底部额外滚动区域, 需要你自己为UITableView添加contentInset
 * @see JPWarpNavigationController
 */
@property(nonatomic)UIView *jp_linkView;

@end
