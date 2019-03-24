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

#import <Foundation/Foundation.h>

@protocol JPReusableObject <NSObject>

@required
@property(nonatomic, assign) BOOL onUsing;

/**
 * 必须在该方法里把 onUsing 设为 NO.
 * @code
    - (void)prepareToReuse {
        self.onUsing = NO;
    }
 * @endcode
 */
- (void)prepareToReuse;

@end

NS_ASSUME_NONNULL_BEGIN

@interface JPReusePool<__covariant T> : NSObject

@property(nonatomic) Class objectClass;

+ (instancetype)new NS_UNAVAILABLE;

- (instancetype)init NS_UNAVAILABLE;

- (instancetype)initWithReusableObjectClass:(Class)cls NS_DESIGNATED_INITIALIZER;

@property(nonatomic, copy, readonly) NSSet<T<JPReusableObject>> *reusableObjects;

@property(nonatomic, copy, readonly) NSSet<T<JPReusableObject>> *onUsingObjects;

/// 是否需要将所有的操作都分发到自建队列保证线程安全, 默认 YES.
/// 如果能保证外面使用的线程安全, 可以这个值置为 NO 来提高性能.
@property(nonatomic, assign) BOOL preferDispatchAllTasksOnInternalQueue;

/// 对象个数警告阈值, 默认 1000.
@property(nonatomic, assign) NSUInteger reusableObjectsWarningThresholdValue;


#pragma mark - Free Resources

- (void)makeAllObjectsPerformReuse;

- (void)objectPerformReuse:(id <JPReusableObject>)obj;

- (void)objectsPerformReuse:(NSArray<id<JPReusableObject>> *)objs;


#pragma mark - Retrieve Resources

- (T<JPReusableObject>)retrieveReusableObject;

- (NSString *)dumpReusableObjectsDescription;

@end

NS_ASSUME_NONNULL_END