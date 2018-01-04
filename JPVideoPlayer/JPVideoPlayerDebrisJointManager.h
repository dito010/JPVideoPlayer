//
//  JPVideoPlayerDebrisJointManager.h
//  JPVideoPlayerDemo
//
//  Created by 尹久盼 on 2018/1/1.
//  Copyright © 2018年 NewPan. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

typedef void(^JPVideoPlayerDebrisJointCompletion)(NSString  *_Nullable fullVideoPath, NSError  *_Nullable error);

@interface JPVideoPlayerDebrisJointManager : NSObject

/**
 *  Try to joint the debris video data for given key.
 *
 *  @param key        The unique flag for the given url in this framework.
 *  @param completion The completion handler after joint finished.
 */

- (void)tryToJointDataDebrisForKey:(NSString *)key
                        completion:(JPVideoPlayerDebrisJointCompletion)completion;

@end

NS_ASSUME_NONNULL_END
