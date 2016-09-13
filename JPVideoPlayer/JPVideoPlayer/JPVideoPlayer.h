//
//  JPVideoPlayer.h
//  JPVideoPlayer
//
//  Created by lava on 16/9/13.
//  Copyright © 2016年 lavaMusic. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

FOUNDATION_EXPORT NSString *const kJPPlayerStateChangedNotification;
FOUNDATION_EXPORT NSString *const kJPPlayerProgressChangedNotification;
FOUNDATION_EXPORT NSString *const kJPPlayerLoadProgressChangedNotification;


@interface JPVideoPlayer : NSObject

@property (nonatomic, assign) BOOL stopWhenAppDidEnterBackground; // default is YES

+ (instancetype)sharedInstance;

- (void)playWithUrl:(NSURL *)url showView:(UIView *)showView;

- (void)resume;
- (void)pause;
- (void)stop;

/** 静音 */
@property(nonatomic, assign)BOOL mute;

@end
