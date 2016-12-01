//
//  UIView+JPObserveDealloc.h
//  JPVideoPlayerDemo
//
//  Created by lava on 16/9/13.
//  Hello! I am NewPan from Guangzhou of China, Glad you could use my framework, If you have any question or wanna to contact me, please open https://github.com/Chris-Pan or http://www.jianshu.com/users/e2f2d779c022/latest_articles


/**
 * This category use for observing view's dealloc by AOP, when observe the dealloc view is the showView, this category will post a notification to tell the player, the player will release play resource and stop play when receive the notification.
 * 这个分类使用AOP的思想监听view的释放, 当监听到是承载视频播放的view dealloc的时候就推送一条通知告诉播放器, 播放器接受到这条通知以后就会主动释放当前播放资源, 停止播放
 */
#import <UIKit/UIKit.h>

@interface UIView (JPObserveDealloc)

/** 
 * Record is the showView or not.
 * 是不是承载视频播放的view
 */
@property(nonatomic)BOOL isShowView;

@end
