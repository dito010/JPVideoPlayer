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

/// 该方法会把当前队列添加一个标识, 使用 JPDispatchSyncOnQueue 时, 实现当前队列可重入.
UIKIT_EXTERN dispatch_queue_t JPNewSyncQueue(const char *_Nullable label);

/// 该方法会把当前队列添加一个标识, 使用 JPDispatchSyncOnQueue 时, 实现当前队列可重入.
UIKIT_EXTERN dispatch_queue_t JPNewAsyncQueue(const char *_Nullable label);

UIKIT_EXTERN void JPDispatchSyncOnMainQueue(void (^block)(void));

UIKIT_EXTERN void JPDispatchAsyncOnMainQueue(void (^block)(void));

UIKIT_EXTERN void JPDispatchAsyncOnQueue(dispatch_queue_t queue, void (^block)(void));

UIKIT_EXTERN void JPDispatchSyncOnQueue(dispatch_queue_t queue, void (^block)(void));

UIKIT_EXTERN void JPDispatchAsyncOnNextRunloop(void (^block)(void));

UIKIT_EXTERN void JPDispatchAfterTimeIntervalInSecond(NSTimeInterval timeInterval, void (^block)(void));

#define JPAssertMainThread NSAssert([NSThread isMainThread], @"代码应该在主线程调用.")

#define JPAssertNotMainThread NSAssert(![NSThread isMainThread], @"代码不应该在主线程调用.")