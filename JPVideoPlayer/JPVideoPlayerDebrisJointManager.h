//
//  JPVideoPlayerDebrisJointManager.h
//  JPVideoPlayerDemo
//
//  Created by 尹久盼 on 2018/1/1.
//  Copyright © 2018年 NewPan. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

typedef void(^JPVideoPlayerDebrisJointCompletion)(NSString *);

@interface JPVideoPlayerDebrisJointManager : NSObject

/**
 *  try to joint the debris video data for given key.
 *
 *  @param key  The unique flag for the given url in this framework.
 *
 *  @return the flag of joint is successed or not.
 */

- (BOOL)tryToJointDataDebrisForKey:(NSString *)key ;

@end

NS_ASSUME_NONNULL_END
