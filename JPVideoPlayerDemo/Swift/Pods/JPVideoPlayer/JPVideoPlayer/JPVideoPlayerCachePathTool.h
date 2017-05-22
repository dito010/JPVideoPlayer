/*
 * This file is part of the JPVideoPlayer package.
 * (c) NewPan <13246884282@163.com>
 *
 * For the full copyright and license information, please view the LICENSE
 * file that was distributed with this source code.
 *
 * Click https://github.com/Chris-Pan
 * or http://www.jianshu.com/users/e2f2d779c022/latest_articles to contact me.
 */


#import <Foundation/Foundation.h>

extern NSString * _Nonnull const JPVideoPlayerCacheVideoPathForTemporaryFile;
extern NSString * _Nonnull const JPVideoPlayerCacheVideoPathForFullFile;

@interface JPVideoPlayerCachePathTool : NSObject

/**
 *  Get the local video cache path for all temporary video file.
 *
 *  @return the temporary file path.
 */
+(nonnull NSString *)videoCachePathForAllTemporaryFile;

/**
 *  Get the local video cache path for all full video file.
 *
 *  @return the full file path.
 */
+(nonnull NSString *)videoCachePathForAllFullFile;

/**
 *  Get the local video cache path for temporary video file.
 *
 *  @param key  The unique flag for the given url in this framework.
 *
 *  @return the temporary file path.
 */
+(nonnull NSString *)videoCacheTemporaryPathForKey:( NSString * _Nonnull )key;

/**
 *  Get the local video cache path for all full video file.
 *
 *  @param key  The unique flag for the given url in this framework.
 *
 *  @return the full file path.
 */
+(nonnull NSString *)videoCacheFullPathForKey:(NSString * _Nonnull)key;

@end
