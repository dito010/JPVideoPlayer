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

#ifndef JPNavigationControllerCompat_h
#define JPNavigationControllerCompat_h

#define JPScreenH [UIScreen mainScreen].bounds.size.height
#define JPScreenW [UIScreen mainScreen].bounds.size.width


typedef NS_ENUM(NSInteger, JPNavigationControllerTransitionType) {
    JPNavigationControllerTransitionTypeNone = 0,
    JPNavigationControllerTransitionTypePush = 1,
    JPNavigationControllerTransitionTypePop = 2,
    JPNavigationControllerTransitionTypePopSystem = 3,
};

#endif /* JPNavigationControllerCompat_h */
