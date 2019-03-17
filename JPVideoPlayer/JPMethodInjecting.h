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
#import <objc/runtime.h>

/**
 * 依赖注入工具类.
 */

#define jp_metamacro_stringify_(VALUE) # VALUE

#define jp_metamacro_stringify(VALUE) \
        jp_metamacro_stringify_(VALUE)

#define jp_concrete \
    optional \

#define jp_concreteprotocol(NAME) \
    interface NAME ## _JPProtocolMethodContainer : NSObject < NAME > {} \
    @end \
    @implementation NAME ## _JPProtocolMethodContainer \
    + (void)load { \
        if (!jp_addConcreteProtocol(objc_getProtocol(jp_metamacro_stringify(NAME)), self)) \
            fprintf(stderr, "ERROR: Could not load concrete protocol %s\n", jp_metamacro_stringify(NAME)); \
    } \
    __attribute__((constructor)) \
    static void rs_ ## NAME ## _inject (void) { \
        jp_loadConcreteProtocol(objc_getProtocol(jp_metamacro_stringify(NAME))); \
    }

BOOL jp_addConcreteProtocol(Protocol *protocol, Class methodContainer);
void jp_loadConcreteProtocol(Protocol *protocol);
