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

#import "JPReusePool.h"
#import "JPGCDExtensions.h"

@interface JPReusePool ()

@property(nonatomic, strong) NSMutableArray<id<JPReusableObject>> *internalReusableObjects;

@property(nonatomic, strong) NSMutableArray<id<JPReusableObject>> *internalOnUsingObjects;

@property(nonatomic, strong) dispatch_queue_t syncQueue;

@end

@implementation JPReusePool

+ (instancetype)new {
    NSAssert(NO, @"请使用指定的方法初始化该类.");
    return nil;
}

- (instancetype)init {
    NSAssert(NO, @"请使用指定的方法初始化该类.");
    return nil;
}

- (instancetype)initWithReusableObjectClass:(Class)cls {
    NSParameterAssert(cls);
    if (!cls) return nil;

    self = [super init];
    if (self) {
        _objectClass = cls;
        _internalReusableObjects = @[].mutableCopy;
        _internalOnUsingObjects = @[].mutableCopy;
        _syncQueue = JPNewSyncQueue("com.skyplan.reusepool.sync.queue.www");
        _preferDispatchAllTasksOnInternalQueue = YES;
        _reusableObjectsWarningThresholdValue = 1000;
    }
    return self;
}

- (NSSet *)reusableObjects {
    if (self.preferDispatchAllTasksOnInternalQueue) {
        __block NSSet<id<JPReusableObject>> *objs = nil;
        JPDispatchSyncOnQueue(self.syncQueue, ^{

            objs = [NSSet setWithArray:self.internalReusableObjects.copy];

        });
        return objs;
    }
    else {
        return [NSSet setWithArray:self.internalReusableObjects.copy];;
    }
}

- (NSSet *)usingObjects {
    if (self.preferDispatchAllTasksOnInternalQueue) {
        __block NSSet<id<JPReusableObject>> *objs = nil;
        JPDispatchSyncOnQueue(self.syncQueue, ^{

            objs = [NSSet setWithArray:self.internalOnUsingObjects.copy];

        });
        return objs;
    }
    else {
        return [NSSet setWithArray:self.internalOnUsingObjects.copy];;
    }
}

- (void)makeAllObjectsPerformReuse {
    if (self.preferDispatchAllTasksOnInternalQueue) {
        JPDispatchSyncOnQueue(self.syncQueue, ^{

            /// 使用 for-in 比 enumerateObjectsUsingBlock 快七倍.
            /// https://stackoverflow.com/questions/4486622/when-to-use-enumerateobjectsusingblock-vs-for
            /// 在这个类里, 性能变得非常关键, 所以选择高性能的 for-in.
            for (id o in self.internalOnUsingObjects) {
                [o prepareToReuse];
            }
            [self.internalReusableObjects addObjectsFromArray:self.internalOnUsingObjects];
            [self.internalOnUsingObjects removeAllObjects];

        });
    }
    else {
        for (id o in self.internalOnUsingObjects) {
            [o prepareToReuse];
        }
        [self.internalReusableObjects addObjectsFromArray:self.internalOnUsingObjects];
        [self.internalOnUsingObjects removeAllObjects];
    }
}

- (void)objectPerformReuse:(id<JPReusableObject>)obj {
    if (!obj) return;

    if (self.preferDispatchAllTasksOnInternalQueue) {
        JPDispatchSyncOnQueue(self.syncQueue, ^{

            [obj prepareToReuse];
            [self.internalReusableObjects addObject:obj];
            [self.internalOnUsingObjects removeObject:obj];

        });
    }
    else {
        [obj prepareToReuse];
        [self.internalReusableObjects addObject:obj];
        [self.internalOnUsingObjects removeObject:obj];
    }
}

- (void)objectsPerformReuse:(NSArray *)objs {
    if (!objs.count) return;

    if (self.preferDispatchAllTasksOnInternalQueue) {
        JPDispatchSyncOnQueue(self.syncQueue, ^{

            for (id o in objs) {
                [o prepareToReuse];
            }
            [self.internalReusableObjects addObjectsFromArray:objs];
            [self.internalOnUsingObjects removeObjectsInArray:objs];

        });
    }
    else {
        for (id o in objs) {
            [o prepareToReuse];
        }
        [self.internalReusableObjects addObjectsFromArray:objs];
        [self.internalOnUsingObjects removeObjectsInArray:objs];
    }
}

- (id)retrieveReusableObject {
    __block id <JPReusableObject> o = nil;
    if (self.preferDispatchAllTasksOnInternalQueue) {
        JPDispatchSyncOnQueue(self.syncQueue, ^{

            o = self.internalReusableObjects.lastObject;
            [self.internalReusableObjects removeLastObject];
            if (!o) {
                o = (id <JPReusableObject>) [[self.objectClass alloc] init];

                /// 阈值警告.
                if (self.internalOnUsingObjects.count > self.reusableObjectsWarningThresholdValue) {
                    NSLog(@"[JPReusePool 阈值警告, 考虑资源一直创建, 没有释放, 起不到循环利用的效果] ==> %@", [self dumpReusableObjectsDescription]);
                }
            }
            [self.internalOnUsingObjects addObject:o];
            o.onUsing = YES;

        });
    }
    else {
        o = self.internalReusableObjects.lastObject;
        [self.internalReusableObjects removeLastObject];
        if (!o) {
            o = (id <JPReusableObject>) [[self.objectClass alloc] init];

            /// 阈值警告.
            if (self.internalOnUsingObjects.count > self.reusableObjectsWarningThresholdValue) {
                NSLog(@"[JPReusePool 阈值警告, 考虑资源一直创建, 没有释放, 起不到循环利用的效果] ==> %@", [self dumpReusableObjectsDescription]);
            }
        }
        [self.internalOnUsingObjects addObject:o];
        o.onUsing = YES;
    }
    return o;
}

- (NSString *)dumpReusableObjectsDescription {
    return [NSString stringWithFormat:@"总资源数: %lu, 可复用资源数: %lu, 当前使用数: %lu", self.internalOnUsingObjects.count + self.internalReusableObjects.count, self.internalReusableObjects.count, self.internalOnUsingObjects.count];
}

- (NSString *)description {
    return [self dumpReusableObjectsDescription];
}

@end
