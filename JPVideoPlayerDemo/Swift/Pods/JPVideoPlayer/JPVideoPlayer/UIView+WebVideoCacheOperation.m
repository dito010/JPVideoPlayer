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


#import "UIView+WebVideoCacheOperation.h"
#import "objc/runtime.h"
#import "JPVideoPlayerOperation.h"

static char loadOperationKey;
static char currentPlayingURLKey;

typedef NSMutableDictionary<NSString *, id> JPOperationsDictionary;

@implementation UIView (WebVideoCacheOperation)

#pragma mark - Public

- (void)setCurrentPlayingURL:(NSURL *)currentPlayingURL{
    objc_setAssociatedObject(self, &currentPlayingURLKey, currentPlayingURL, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (NSURL *)currentPlayingURL{
    return objc_getAssociatedObject(self, &currentPlayingURLKey);
}

- (void)jp_setVideoLoadOperation:(id)operation forKey:(NSString *)key{
    if (key) {
        [self jp_cancelVideoLoadOperationWithKey:key];
        if (operation) {
            JPOperationsDictionary *operationDictionary = [self operationDictionary];
            operationDictionary[key] = operation;
        }
    }
}

- (void)jp_cancelVideoLoadOperationWithKey:(NSString *)key{
    // Cancel in progress downloader from queue.
    JPOperationsDictionary *operationDictionary = [self operationDictionary];
    id operations = operationDictionary[key];
    if (operations) {
        if ([operations isKindOfClass:[NSArray class]]) {
            for (id <JPVideoPlayerOperation> operation in operations) {
                if (operation) {
                    [operation cancel];
                }
            }
        }
        else if ([operations conformsToProtocol:@protocol(JPVideoPlayerOperation)]){
            [(id<JPVideoPlayerOperation>) operations cancel];
        }
        [operationDictionary removeObjectForKey:key];
    }
}

- (void)jp_removeVideoLoadOperationWithKey:(NSString *)key{
    if (key) {
        JPOperationsDictionary *operationDictionary = [self operationDictionary];
        [operationDictionary removeObjectForKey:key];
    }
}

    
#pragma mark - Private

- (JPOperationsDictionary *)operationDictionary {
    JPOperationsDictionary *operations = objc_getAssociatedObject(self, &loadOperationKey);
    if (operations) {
        return operations;
    }
    operations = [NSMutableDictionary dictionary];
    objc_setAssociatedObject(self, &loadOperationKey, operations, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    return operations;
}

@end
