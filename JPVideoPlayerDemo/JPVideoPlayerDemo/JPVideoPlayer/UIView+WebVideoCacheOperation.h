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

@interface UIView (WebVideoCacheOperation)

/** 
 * The url of current playing video data. 
 */
@property(nonatomic, nullable)NSURL *currentPlayingURL;

/**
 *  Set the video load operation (storage in a UIView based dictionary).
 *
 *  @param operation the operation.
 *  @param key       key for storing the operation.
 */
- (void)jp_setVideoLoadOperation:(nullable id)operation forKey:(nullable NSString *)key;

/**
 *  Cancel all operations for the current UIView and key.
 *
 *  @param key key for identifying the operations.
 */
- (void)jp_cancelVideoLoadOperationWithKey:(nullable NSString *)key;

/**
 *  Just remove the operations corresponding to the current UIView and key without cancelling them.
 *  @param key key for identifying the operations.
 */
- (void)jp_removeVideoLoadOperationWithKey:(nullable NSString *)key;

@end
