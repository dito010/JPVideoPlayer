//
//  JPDownloadManager.h
//  JPVideoPlayer
//
//  Created by lava on 16/8/18.
//  Hello! I am NewPan from Guangzhou of China, Glad you could use my framework, If you have any question or wanna to contact me, please open https://github.com/Chris-Pan or http://www.jianshu.com/users/e2f2d779c022/latest_articles


/*
 * It be used to save data as temporary file when requesting data from network
 * It also can auto move temporary file to the path you assigned when the temporary file is a complete file (mean that the length of temporary file is equal to the file in network) after request finished or canceled
 * And it will delete the temporary file if the temporary file is not a complete file after request finish or cancel
 * 这个类的功能是从网络请求数据，并把数据保存到本地的一个临时文件.
 * 当网络请求结束或取消的时候，如果数据完整，则把数据缓存到指定的路径，不完整就删除
 */


#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>

@class JPDownloadManager;

@protocol JPDownloadManagerDelegate <NSObject>

@optional

/**
 * Start load data(pass data-length and data-mineType)
 * 开始下载数据(传递长度和类型)
 */
- (void)manager:(JPDownloadManager *)manager didReceiveVideoLength:(NSUInteger)videoLength mimeType:(NSString *)mimeType;

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

/**
 * It is loading file from network(pass the data received and downloaded position and the path of temporary file)
 * 正在下载(传递获取到的数据和下载的偏移量以及临时文件存储路径)
 */
-(void)manager:(JPDownloadManager *)manager didReceiveData:(NSData *)data downloadOffset:(NSInteger)offset tempFilePath:(NSString *)filePath;

@end


/**
 * Save path
 * 存储路径
 */
static NSString *jp_tempPath = @"/JPVideoPlayer_temp"; // temporary file(临时文件)
static NSString *jp_savePath = @"/JPVideoPlayer_save"; // complete file(完成文件)
@interface JPDownloadManager : NSObject

/**
 * The url of network file
 * 要下载的文件的URL
 */
@property (nonatomic, strong, readonly) NSURL *url;

/**
 * The value of start download position
 * 下载位置的偏移量
 */
@property (nonatomic, readonly) NSUInteger offset;

/**
 * The total length of file
 * 文件总长度
 */
@property (nonatomic, readonly) NSUInteger fileLength;

/**
 * The current length of downloaded file
 * 当前下载了的文件的位置
 */
@property (nonatomic, readonly) NSUInteger downLoadingOffset;

/**
 * The mimeType of the downloading file
 * mineType 类型
 */
@property (nonatomic, strong, readonly) NSString *mimeType;

/**
 * Query is finished download
 * 查询是否已经下载完成
 */
@property (nonatomic, assign)BOOL isFinishLoad;

/**
 * To be the delegate, It can pass the statu of download by Delegate-Method
 * @see JPDownloadManagerDelegate
 * 成为代理, 就能获得下载状态
 */
@property(nonatomic, weak)id<JPDownloadManagerDelegate> delegate;


/**
 * It be used to save data as temporary file when requesting data from network
 * It also can auto move temporary file to the path you assigned when the temporary file is a complete file (mean that the length of temporary file is equal to the file in network) after request finished or canceled
 * And it will delete the temporary file if the temporary file is not a complete file after request finish or cancel
 * 传递要下载的文件的URL和下载初始偏移量, 这个方法功能是从网络请求数据，并把数据保存到本地的一个临时文件.
 * 当网络请求结束或取消的时候，如果数据完整，则把数据缓存到指定的路径，不完整就删除
 * @param url       The url of network file
 * @param offset    The value of start download position, it can be 0
 */
- (void)setUrl:(NSURL *)url offset:(NSUInteger)offset;

/**
 * Cancel current download task
 * 取消当前下载进程
 */
- (void)cancel;

@end
