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

#import "JPMethodInjecting.h"
#import <pthread.h>
#import "JPVideoPlayerSupportUtils.h"

typedef struct JPSpecialProtocol {
    __unsafe_unretained Protocol *protocol;
    Class containerClass;
    BOOL ready;
} JPSpecialProtocol;

static JPSpecialProtocol * restrict jp_specialProtocols = NULL;
static size_t jp_specialProtocolCount = 0;
static size_t jp_specialProtocolCapacity = 0;
static size_t jp_specialProtocolsReady = 0;
static pthread_mutex_t jp_specialProtocolsLock = PTHREAD_MUTEX_INITIALIZER;
static NSRecursiveLock *jpinjecting_recursiveLock;

BOOL rs_loadSpecialProtocol (Protocol *protocol, Class containerClass) {
    @autoreleasepool {
        NSCParameterAssert(protocol != nil);
        if (pthread_mutex_lock(&jp_specialProtocolsLock) != 0) {
            fprintf(stderr, "ERROR: Could not synchronize on special protocol data\n");
            return NO;
        }

        if (jp_specialProtocolCount == SIZE_MAX) {
            pthread_mutex_unlock(&jp_specialProtocolsLock);
            return NO;
        }

        if (jp_specialProtocolCount >= jp_specialProtocolCapacity) {
            size_t newCapacity;
            if (jp_specialProtocolCapacity == 0)
                newCapacity = 1;
            else {
                newCapacity = jp_specialProtocolCapacity << 1;

                if (newCapacity < jp_specialProtocolCapacity) {
                    newCapacity = SIZE_MAX;

                    if (newCapacity <= jp_specialProtocolCapacity) {
                        pthread_mutex_unlock(&jp_specialProtocolsLock);
                        return NO;
                    }
                }
            }

            void * restrict ptr = realloc(jp_specialProtocols, sizeof(*jp_specialProtocols) * newCapacity);
            if (!ptr) {
                pthread_mutex_unlock(&jp_specialProtocolsLock);
                return NO;
            }

            jp_specialProtocols = ptr;
            jp_specialProtocolCapacity = newCapacity;
        }
        assert(jp_specialProtocolCount < jp_specialProtocolCapacity);

#ifndef __clang_analyzer__

        jp_specialProtocols[jp_specialProtocolCount] = (JPSpecialProtocol){
                .protocol = protocol,
                .containerClass = containerClass,
                .ready = NO,
        };
#endif

        ++jp_specialProtocolCount;
        pthread_mutex_unlock(&jp_specialProtocolsLock);
    }

    return YES;
}

static void rs_orderSpecialProtocols(void) {
    qsort_b(jp_specialProtocols, jp_specialProtocolCount, sizeof(JPSpecialProtocol), ^(const void *a, const void *b){
        if (a == b)
            return 0;

        const JPSpecialProtocol *protoA = a;
        const JPSpecialProtocol *protoB = b;

        int (^protocolInjectionPriority)(const JPSpecialProtocol *) = ^(const JPSpecialProtocol *specialProtocol){
            int runningTotal = 0;

            for (size_t i = 0;i < jp_specialProtocolCount;++i) {
                if (specialProtocol == jp_specialProtocols + i)
                    continue;

                if (protocol_conformsToProtocol(specialProtocol->protocol, jp_specialProtocols[i].protocol))
                    runningTotal++;
            }

            return runningTotal;
        };
        return protocolInjectionPriority(protoB) - protocolInjectionPriority(protoA);
    });
}

void rs_specialProtocolReadyForInjection (Protocol *protocol) {
    @autoreleasepool {
        NSCParameterAssert(protocol != nil);

        if (pthread_mutex_lock(&jp_specialProtocolsLock) != 0) {
            fprintf(stderr, "ERROR: Could not synchronize on special protocol data\n");
            return;
        }
        for (size_t i = 0;i < jp_specialProtocolCount;++i) {
            if (jp_specialProtocols[i].protocol == protocol) {
                if (!jp_specialProtocols[i].ready) {
                    jp_specialProtocols[i].ready = YES;
                    assert(jp_specialProtocolsReady < jp_specialProtocolCount);
                    if (++jp_specialProtocolsReady == jp_specialProtocolCount)
                        rs_orderSpecialProtocols();
                }

                break;
            }
        }

        pthread_mutex_unlock(&jp_specialProtocolsLock);
    }
}

static void rs_logInstanceAndClassMethod(Class cls) {
    unsigned imethodCount = 0;
    Method *imethodList = class_copyMethodList(cls, &imethodCount);
    NSLog(@"instance Method--------------------");
    for (unsigned methodIndex = 0;methodIndex < imethodCount;++methodIndex) {
        Method method = imethodList[methodIndex];
        SEL selector = method_getName(method);
        NSLog(@"%@", [NSString stringWithFormat:@"-[%@ %@]", NSStringFromClass(cls), NSStringFromSelector(selector)]);
    }
    free(imethodList); imethodList = NULL;

    unsigned cmethodCount = 0;
    Method *cmethodList = class_copyMethodList(object_getClass(cls), &cmethodCount);

    NSLog(@"class Method--------------------");
    for (unsigned methodIndex = 0;methodIndex < cmethodCount;++methodIndex) {
        Method method = cmethodList[methodIndex];
        SEL selector = method_getName(method);
        NSLog(@"%@", [NSString stringWithFormat:@"+[%@ %@]", NSStringFromClass(cls), NSStringFromSelector(selector)]);
    }

    free(cmethodList); cmethodList = NULL;
    NSLog(@"end----------------------------------------");
}

static void rs_injectConcreteProtocolInjectMethod(Class containerClass, Class pairClass) {
    unsigned imethodCount = 0;
    Method *imethodList = class_copyMethodList(containerClass, &imethodCount);
    for (unsigned methodIndex = 0;methodIndex < imethodCount;++methodIndex) {
        Method method = imethodList[methodIndex];
        SEL selector = method_getName(method);
        IMP imp = method_getImplementation(method);
        const char *types = method_getTypeEncoding(method);
        class_addMethod(pairClass, selector, imp, types);
    }
    free(imethodList); imethodList = NULL;
    (void)[containerClass class];

    unsigned cmethodCount = 0;
    Method *cmethodList = class_copyMethodList(object_getClass(containerClass), &cmethodCount);

    Class metaclass = object_getClass(pairClass);
    for (unsigned methodIndex = 0;methodIndex < cmethodCount;++methodIndex) {
        Method method = cmethodList[methodIndex];
        SEL selector = method_getName(method);

        if (selector == @selector(initialize)) {
            continue;
        }

        IMP imp = method_getImplementation(method);
        const char *types = method_getTypeEncoding(method);
        class_addMethod(metaclass, selector, imp, types);
    }

    free(cmethodList); cmethodList = NULL;
    (void)[containerClass class];
}

static NSArray * rs_injectMethod(id object) {
    NSMutableArray *rs_matchSpecialProtocolsToClass = @[].mutableCopy;
    for (size_t i = 0;i < jp_specialProtocolCount;++i) {
        @autoreleasepool {
            Protocol *protocol = jp_specialProtocols[i].protocol;
            if (!class_conformsToProtocol([object class], protocol)) {
                continue;
            }
            [rs_matchSpecialProtocolsToClass addObject:[NSValue value:&jp_specialProtocols[i] withObjCType:@encode(struct JPSpecialProtocol)]];
        }
    }

    if(!rs_matchSpecialProtocolsToClass.count) {
        return nil;
    }

    struct JPSpecialProtocol protocol;
    for(NSValue *value in rs_matchSpecialProtocolsToClass) {
        [value getValue:&protocol];
        rs_injectConcreteProtocolInjectMethod(protocol.containerClass, [object class]);
    }
    return rs_matchSpecialProtocolsToClass.copy;
}

static bool rs_resolveMethodForObject(id object) {
    @autoreleasepool {
        static dispatch_once_t onceToken;
        dispatch_once(&onceToken, ^{
            jpinjecting_recursiveLock = [NSRecursiveLock new];
        });

        [jpinjecting_recursiveLock lock];

        // 处理继承自有注入的父类.
        Class currentClass = [object class];
        NSArray *matchSpecialProtocolsToClass = nil;
        do {
            NSArray *protocols = rs_injectMethod(currentClass);
            if(!matchSpecialProtocolsToClass) {
                matchSpecialProtocolsToClass = protocols;
            }
        }while((currentClass = class_getSuperclass(currentClass)));

        if(!matchSpecialProtocolsToClass.count) {
            [jpinjecting_recursiveLock unlock];
            return nil;
        }

        [jpinjecting_recursiveLock unlock];
        return YES;
    }
}

BOOL jp_addConcreteProtocol(Protocol *protocol, Class methodContainer) {
    return rs_loadSpecialProtocol(protocol, methodContainer);
}

void jp_loadConcreteProtocol(Protocol *protocol) {
    rs_specialProtocolReadyForInjection(protocol);
}

@interface NSObject(JPInjecting)

@end

@implementation NSObject(JPInjecting)

+ (void)load {
    NSError *iError;
    NSError *cError;
    [self jp_swizzleClassMethod:@selector(resolveInstanceMethod:)
                withClassMethod:@selector(jpinjecting_resolveInstanceMethod:)
                          error:&iError];
    [self jp_swizzleClassMethod:@selector(resolveClassMethod:)
                withClassMethod:@selector(jpinjecting_resolveClassMethod:)
                          error:&cError];
    NSParameterAssert(!iError);
    NSParameterAssert(!cError);
}

+ (BOOL)jpinjecting_resolveClassMethod:(SEL)sel {
    if(rs_resolveMethodForObject(self)) {
        return YES;
    }
    return [self jpinjecting_resolveClassMethod:sel];
}

+ (BOOL)jpinjecting_resolveInstanceMethod:(SEL)sel {
    if(rs_resolveMethodForObject(self)) {
        return YES;
    }
    return [self jpinjecting_resolveInstanceMethod:sel];
}

@end
