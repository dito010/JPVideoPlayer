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

#import "JPGCDExtensions.h"
#import <pthread.h>

void JPDispatchSyncOnMainQueue(void (^block)(void)) {
    if (!block) {
        return;
    }

    if (pthread_main_np()) {
        block();
        return;
    }

    dispatch_sync(dispatch_get_main_queue(), block);
}

void JPDispatchAsyncOnMainQueue(void (^block)(void)) {
    if (!block) {
        return;
    }

    if (pthread_main_np()) {
        JPDispatchAsyncOnNextRunloop(block);
        return;
    }

    dispatch_async(dispatch_get_main_queue(), block);
}

void JPDispatchAsyncOnNextRunloop(void (^block)(void)) {
    dispatch_async(dispatch_get_main_queue(), block);
}

void JPDispatchAsyncOnQueue(dispatch_queue_t queue, void (^block)(void)) {
    if (!queue) {
        dispatch_async(dispatch_get_main_queue(), block);
        return;
    }
    dispatch_async(queue, block);
}

void JPDispatchSyncOnQueue(dispatch_queue_t queue, void (^block)(void)) {
    if (!queue) {
        dispatch_sync(dispatch_get_main_queue(), block);
        return;
    }
    dispatch_sync(queue, block);
}

void JPDispatchAfterTimeIntervalInSecond(NSTimeInterval timeInterval, void (^block)(void)) {
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(timeInterval * NSEC_PER_SEC)), dispatch_get_main_queue(), block);
}