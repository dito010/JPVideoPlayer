//
//  JPManageSinglePopVCTool.m
//  JPNavigationController
//
//  Hello! I am NewPan from Guangzhou of China, Glad you could use my framework, If you have any question or wanna to contact me, please open https://github.com/Chris-Pan or http://www.jianshu.com/users/e2f2d779c022/latest_articles
//

#import "JPManageSinglePopVCTool.h"

@implementation JPManageSinglePopVCTool

static JPManageSinglePopVCTool *_manageInstance;

+(instancetype)shareTool{
    return [[JPManageSinglePopVCTool alloc]init];
}

+(instancetype)allocWithZone:(struct _NSZone *)zone{
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        if (!_manageInstance) {
            _manageInstance = [super allocWithZone:zone];
        }
    });
    return _manageInstance;
}

@end
