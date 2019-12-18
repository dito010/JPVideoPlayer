/*
 * This file is part of the JPVideoPlayer package.
 * (c) NewPan <13246884282@163.com>
 *
 * For the full copyright and license information, please view the LICENSE
 * file that was distributed with this source code.
 *
 * Click https://github.com/newyjp
 * or http://www.jianshu.com/users/e2f2d779c022/latest_articles to contact me.
 */

#import <UIKit/UIKit.h>
#import "JPVideoPlayerCompat.h"

UIKIT_EXTERN NSString * _Nonnull const JPVideoPlayerCacheVideoPathForTemporaryFile;
UIKIT_EXTERN NSString * _Nonnull const JPVideoPlayerCacheVideoPathForFullFile;

NS_ASSUME_NONNULL_BEGIN

@interface JPVideoPlayerCachePath : NSObject

/**
 *  Get the video cache path on version 3.x.
 *
 *  @return The file path.
 */
+ (NSString *)videoCachePath;

/**
 * Fetch the video cache path for given key on version 3.x.
 *
 * @param key A given key.
 *
 * @return The file path.
 */
+ (NSString *)videoCachePathForKey:(NSString *)key;

/**
 * Fetch the video cache path and create video file for given key on version 3.x.
 *
 * @param key A given key.
 *
 * @return The file path.
 */
+ (NSString *)createVideoFileIfNeedThenFetchItForKey:(NSString *)key;

/**
 * Fetch the index file path for given key on version 3.x.
 *
 * @param key A given key.
 *
 * @return The path of index file.
 */
+ (NSString *)videoCacheIndexFilePathForKey:(NSString *)key;

/**
 * Fetch the index file path and create video index file for given key on version 3.x.
 *
 * @param key A given key.
 *
 * @return The path of index file.
 */
+ (NSString *)createVideoIndexFileIfNeedThenFetchItForKey:(NSString *)key;

/**
 * Fetch the playback record file path.
 *
 * @return The path of playback record.
 */
+ (NSString *)videoPlaybackRecordFilePath;

@end


@interface JPVideoPlayerCachePath(Deprecated)

/**
 *  Get the local video cache path for temporary video file.
 *
 *  @param key  The unique flag for the given url in this framework.
 *
 *  @return the temporary file path.
 */
+ (NSString *)videoCacheTemporaryPathForKey:(NSString *)key JPDEPRECATED_ATTRIBUTE("`videoCacheTemporaryPathForKey:` is deprecated on 3.0.")

/**
 *  Get the local video cache path for all full video file.
 *
 *  @param key  The unique flag for the given url in this framework.
 *
 *  @return the full file path.
 */
+ (NSString *)videoCacheFullPathForKey:(NSString *)key JPDEPRECATED_ATTRIBUTE("`videoCacheFullPathForKey:` is deprecated on 3.0.")

/**
 *  Get the local video cache path for all temporary video file on version 2.x.
 *
 *  @return the temporary file path.
 */
+ (NSString *)videoCachePathForAllTemporaryFile JPDEPRECATED_ATTRIBUTE("`videoCachePathForAllTemporaryFile` is deprecated on 3.0.")

/**
 *  Get the local video cache path for all full video file on version 2.x.
 *
 *  @return the full file path.
 */
+ (NSString *)videoCachePathForAllFullFile JPDEPRECATED_ATTRIBUTE("`videoCachePathForAllFullFile` is deprecated on 3.0.")

@end

NS_ASSUME_NONNULL_END