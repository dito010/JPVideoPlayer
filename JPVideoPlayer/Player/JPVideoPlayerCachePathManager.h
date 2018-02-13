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

#import <UIKit/UIKit.h>
#import "JPVideoPlayerCompat.h"

UIKIT_EXTERN NSString * _Nonnull const JPVideoPlayerCacheVideoPathForTemporaryFile;
UIKIT_EXTERN NSString * _Nonnull const JPVideoPlayerCacheVideoPathForFullFile;

@interface JPVideoPlayerCachePathManager : NSObject

/**
 *  Get the local video cache path for all temporary video file on version 3.x.
 *
 *  @return the temporary file path.
 */
+(nonnull NSString *)newVideoCachePathForAllTemporaryFile;

/**
 *  Get the local video cache path for all full video file on version 3.x.
 *
 *  @return the full file path.
 */
+(nonnull NSString *)newVideoCachePathForAllFullFile;

/**
 *  Get the local video cache models store path on version 3.x.
 *
 *  @param key  The unique flag for the given url in this framework.
 *
 *  @return the models store path.
 */
+ (nullable NSString *)videoCacheModelsSavePathForKey:(NSString * _Nonnull)key;

/**
 *  Get the local video cache path for all temporary video file on version 2.x.
 *
 *  @return the temporary file path.
 */
+(nonnull NSString *)videoCachePathForAllTemporaryFile JPDEPRECATED_ATTRIBUTE("`videoCachePathForAllTemporaryFile` is deprecated on 3.0, please use `newVideoCachePathForAllTemporaryFile`")

/**
 *  Get the local video cache path for all full video file on version 2.x.
 *
 *  @return the full file path.
 */
+(nonnull NSString *)videoCachePathForAllFullFile JPDEPRECATED_ATTRIBUTE("`videoCachePathForAllFullFile` is deprecated on 3.0, please use `newVideoCachePathForAllFullFile`")

/**
 *  Get the local video cache path for temporary video file.
 *
 *  @param key  The unique flag for the given url in this framework.
 *
 *  @return the temporary file path.
 */
+(nullable NSString *)videoCacheTemporaryPathForKey:(NSString * _Nonnull)key;

/**
 *  Get the local video cache path for all full video file.
 *
 *  @param key  The unique flag for the given url in this framework.
 *
 *  @return the full file path.
 */
+(nullable NSString *)videoCacheFullPathForKey:(NSString * _Nonnull)key;

@end
