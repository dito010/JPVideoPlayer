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

static int kJPVideoPlayerGCDExtensionQueueSpecific;

dispatch_queue_t JPNewSyncQueue(const char *label) {
    NSCParameterAssert(label);
    if (!label) return nil;
    dispatch_queue_t queue = dispatch_queue_create(label, DISPATCH_QUEUE_SERIAL);
    static CFStringRef queueSpecificValue;
    queueSpecificValue = (__bridge CFStringRef)([[NSString alloc] initWithCString:label encoding:NSUTF8StringEncoding]);
    dispatch_queue_set_specific(queue, &kJPVideoPlayerGCDExtensionQueueSpecific, (void *)queueSpecificValue, (dispatch_function_t)CFRelease);
    queueSpecificValue = nil;
    return queue;
}

dispatch_queue_t JPNewAsyncQueue(const char *label) {
    NSCParameterAssert(label);
    if (!label) return nil;
    dispatch_queue_t queue = dispatch_queue_create(label, DISPATCH_QUEUE_CONCURRENT);
    static CFStringRef queueSpecificValue;
    queueSpecificValue = (__bridge CFStringRef)([[NSString alloc] initWithCString:label encoding:NSUTF8StringEncoding]);
    dispatch_queue_set_specific(queue, &kJPVideoPlayerGCDExtensionQueueSpecific, (void *)queueSpecificValue, (dispatch_function_t)CFRelease);
    queueSpecificValue = nil;
    return queue;
}

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

    dispatch_async(dispatch_get_main_queue(), block);
}

void JPDispatchAsyncOnNextRunloop(void (^block)(void)) {
    if (!block) {
        return;
    }
    
    dispatch_async(dispatch_get_main_queue(), block);
}

void JPDispatchAsyncOnQueue(dispatch_queue_t queue, void (^block)(void)) {
    if (!block) {
        return;
    }
    
    if (!queue) {
        JPDispatchAsyncOnMainQueue(block);
        return;
    }
    dispatch_async(queue, block);
}

void JPDispatchSyncOnQueue(dispatch_queue_t queue, void (^block)(void)) {
    if (!block) {
        return;
    }
    
    if (!queue) {
        JPDispatchSyncOnMainQueue(block);
        return;
    }

    static CFStringRef currentQueueSpecificValue, targetQueueSpecificValue;
    currentQueueSpecificValue = dispatch_get_specific(&kJPVideoPlayerGCDExtensionQueueSpecific);
    targetQueueSpecificValue = dispatch_queue_get_specific(queue, &kJPVideoPlayerGCDExtensionQueueSpecific);
    if (currentQueueSpecificValue && targetQueueSpecificValue && [(__bridge NSString *)currentQueueSpecificValue isEqualToString:(__bridge NSString *)targetQueueSpecificValue]) {
        currentQueueSpecificValue = nil;
        targetQueueSpecificValue = nil;
        block();
        return;
    }

    dispatch_sync(queue, block);
}

void JPDispatchAfterTimeIntervalInSecond(NSTimeInterval timeInterval, void (^block)(void)) {
    if (!block) {
        return;
    }
    
    JPAssertMainThread;
    ///  dispatch_get_current_queue 已被废弃, 这里只会派发到主线程.
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(timeInterval * NSEC_PER_SEC)), dispatch_get_main_queue(), block);
}
