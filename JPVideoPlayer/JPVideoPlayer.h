//
//  JPVideoPlayer.h
//  JPVideoPlayer
//
//  Created by lava on 16/9/13.
//  Hello! I am NewPan from Guangzhou of China, Glad you could use my framework, If you have any question or wanna to contact me, please open https://github.com/Chris-Pan or http://www.jianshu.com/users/e2f2d779c022/latest_articles


/**
 * It is singleton, Through pass in video url(network url only) and the view of video will play on, it can auto play video on the view passed in.
 * It also have the function that play video and save the downloaded video srouce at the same time.
 * It can auto save data as temporary file when requesting data from network.
 * It also can auto move temporary file to the path you assigned when the temporary file is a complete file (mean that the length of temporary file is equal to the file in network) after request finished or canceled.
 * And it will auto delete the temporary file if the temporary file is not a complete file after request finished or canceled.
 * The video player's picture size is equal to the view passed in.
 * When switch video url, it will realease the all configuration before first, and re-create all configuration again.
 * The player logic is that find cache in dick first, if find, take out video data from disk to player. if not find, then play video from network.
 * 这是一个单例, 你只需要传递需要播放的路径(网络路径)和视频图像的载体, 就会自动帮你播放视频.
 * 支持边下边播, 会自动缓存数据.
 * 从网络请求数据，并把数据保存到本地的一个临时文件.
 * 当网络请求结束或取消的时候，如果数据完整，则把数据缓存到指定的路径，不完整就删除.
 * 图像尺寸和传进来的图像载体的尺寸一致.
 * 当切换视频的时候, 会释放之前的所有播放视频所有要的配置, 然后重新创建这些配置.
 * 播放逻辑是, 先从本地缓存中查找有缓存没有, 如果有, 就从本地读取数据播放. 如果没有, 再从网络加载数据播放.
 */

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

@interface JPVideoPlayer : NSObject

/**
 * Singleton
 * 单例
 */
+ (instancetype)sharedInstance;

/**
 * Default is YES
 */
@property (nonatomic, assign) BOOL stopWhenAppDidEnterBackground;

/**
 * mute
 * 静音
 */
@property(nonatomic, assign)BOOL mute;

/**
 * Play video method.
 * Through pass in video url(network url only) and the view of video will play on, it can auto play video on the view passed in.
 * It also have the function that play video and save the downloaded video srouce at the same time.
 * It can auto save data as temporary file when requesting data from network.
 * It also can auto move temporary file to the path you assigned when the temporary file is a complete file (mean that the length of temporary file is equal to the file in network) after request finished or canceled.
 * And it will auto delete the temporary file if the temporary file is not a complete file after request finished or canceled.
 * The video player's picture size is equal to the view passed in.
 * When switch video url, it will realease the all configuration before first, and re-create all configuration again.
 * The player logic is that find cache in dick first, if find, take out video data from disk to player. if not find, then play video from network.
 * 你只需要传递需要播放的路径(网络路径)和视频图像的载体, 就会自动帮你播放视频.
 * 支持边下边播, 会自动缓存数据.
 * 从网络请求数据，并把数据保存到本地的一个临时文件.
 * 当网络请求结束或取消的时候，如果数据完整，则把数据缓存到指定的路径，不完整就删除.
 * 图像尺寸和传进来的图像载体的尺寸一致.
 * 当切换视频的时候, 会释放之前的所有播放视频所有要的配置, 然后重新创建这些配置.
 * 播放逻辑是, 先从本地缓存中查找有缓存没有, 如果有, 就从本地读取数据播放. 如果没有, 再从网络加载数据播放.
 */
- (void)playWithUrl:(NSURL *)url showView:(UIView *)showView;

- (void)resume;
- (void)pause;
- (void)stop;


@end
