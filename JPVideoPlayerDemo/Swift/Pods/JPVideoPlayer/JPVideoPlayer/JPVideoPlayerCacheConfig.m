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


#import "JPVideoPlayerCacheConfig.h"

static const NSInteger kDefaultCacheMaxCacheAge = 60*60*24*7; // 1 week
static const NSInteger kDefaultCacheMaxSize = 1000*1000*1000; // 1 GB

@implementation JPVideoPlayerCacheConfig

- (instancetype)init{
    self = [super init];
    if (self) {
        _maxCacheAge =  kDefaultCacheMaxCacheAge;
        _maxCacheSize = kDefaultCacheMaxSize;
    }
    return self;
}

@end
