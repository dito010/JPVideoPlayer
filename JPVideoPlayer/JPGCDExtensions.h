/*
 * This file is part of the JPVideoPlayer package.
 * (c) NewPan <13246884282@163.com>
 *
 * For the full copyright and license information, please view the LICENSE
 * file that was distributed with this source code.
 *
 * Click https://github.com/newyjp
 * or http://www.jianshu.com/users/e2f2d779c022/latest_articles to contact me.
 */

#import <UIKit/UIKit.h>

UIKIT_EXTERN void JPDispatchSyncOnMainQueue(void (^block)(void));

UIKIT_EXTERN void JPDispatchAsyncOnMainQueue(void (^block)(void));

UIKIT_EXTERN void JPDispatchAsyncOnQueue(dispatch_queue_t queue, void (^block)(void));

UIKIT_EXTERN void JPDispatchSyncOnQueue(dispatch_queue_t queue, void (^block)(void));

UIKIT_EXTERN void JPDispatchAsyncOnNextRunloop(void (^block)(void));

UIKIT_EXTERN void JPDispatchAfterTimeIntervalInSecond(NSTimeInterval timeInterval, void (^block)(void));

#define JPAssertMainThread NSAssert([NSThread isMainThread], @"代码应该在主线程调用.")

#define JPAssertNotMainThread NSAssert(![NSThread isMainThread], @"代码不应该在主线程调用.")