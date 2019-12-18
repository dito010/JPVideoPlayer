//
// Created by NewPan on 2018/9/5.
// Copyright (c) 2018 NewPan. All rights reserved.
//

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
