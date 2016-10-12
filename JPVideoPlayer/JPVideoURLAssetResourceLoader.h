//
//  JPVideoURLAssetResourceLoader.h
//  JPVideoPlayer
//
//  Created by lava on 16/9/13.
//  Hello! I am NewPan from Guangzhou of China, Glad you could use my framework, If you have any question or wanna to contact me, please open https://github.com/Chris-Pan or http://www.jianshu.com/users/e2f2d779c022/latest_articles


/**
 * It use to take out data according to the offset and length that the player requested in cache, and pass back the data to player.
 * 这个类的功能是把缓存到本地的临时数据根据播放器需要的 offset 和 length 去取出数据, 并返回给播放器
 */


#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>

@class JPDownloadManager;

@protocol JPVideoURLAssetResourceLoaderDelegate <NSObject>

@optional

/**
 * Finished load(pass the save path of file)
 * 完成下载(传递文件的路径)
 */
- (void)didFinishLoadingWithManager:(JPDownloadManager *)manager fileSavePath:(NSString *)filePath;

/**
 * Fail load(pass error)
 * 下载失败(传递错误码)
 */
- (void)didFailLoadingWithManager:(JPDownloadManager *)manager WithError:(NSError *)errorCode;

/**
 * The file to load is already existed(pass the filePath)
 * 已经存在下载好的这个文件了(传递文件路径)
 */
-(void)manager:(JPDownloadManager *)manager fileExistedWithPath:(NSString *)filePath;

@end


@interface JPVideoURLAssetResourceLoader : NSObject<AVAssetResourceLoaderDelegate>

/**
 * To be the delegate, It can pass the statu of download by Delegate-Method
 * @see JPVideoURLAssetResourceLoaderDelegate
 * 成为代理, 就能获得下载状态
 */
@property (nonatomic, weak) id<JPVideoURLAssetResourceLoaderDelegate> delegate;

/**
 * This method be used to re-scheme the url, it use on fixing the scheme from other to "streaming", then through change request strategies, will be of huge capacity to piecewise continuous media data, divided into numerous small files for transfer.
 * NSURLComponents用来替代NSMutableURL，可以readwrite修改URL，这里通过更改请求策略，将容量巨大的连续媒体数据进行分段，分割为数量众多的小文件进行传递。采用了一个不断更新的轻量级索引文件来控制分割后小媒体文件的下载和播放，可同时支持直播和点播
 * @param url   Request url
 * @return      Fixed url
 */
- (NSURL *)getSchemeVideoURL:(NSURL *)url;

@end
