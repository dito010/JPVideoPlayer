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


#import "UIView+WebVideoCache.h"
#import "UIView+WebVideoCacheOperation.h"
#import <objc/runtime.h>
#import "JPVideoPlayerPlayVideoTool.h"

static NSString *JPVideoPlayerErrorDomain = @"JPVideoPlayerErrorDomain";
@implementation UIView (WebVideoCache)

-(void)jp_playVideoWithURL:(NSURL *)url{
    [self jp_playVideoWithURL:url options:JPVideoPlayerContinueInBackground | JPVideoPlayerShowProgressView | JPVideoPlayerShowActivityIndicatorView | JPVideoPlayerLayerVideoGravityResizeAspect progress:nil completed:nil];
}

-(void)jp_playVideoDisplayStatusViewWithURL:(NSURL *)url{
    [self jp_playVideoWithURL:url options:JPVideoPlayerContinueInBackground | JPVideoPlayerShowProgressView | JPVideoPlayerShowActivityIndicatorView | JPVideoPlayerLayerVideoGravityResizeAspect progress:nil completed:nil];
}

-(void)jp_playVideoMutedDisplayStatusViewWithURL:(NSURL *)url{
    [self jp_playVideoWithURL:url options:JPVideoPlayerContinueInBackground | JPVideoPlayerMutedPlay | JPVideoPlayerShowProgressView | JPVideoPlayerShowActivityIndicatorView | JPVideoPlayerLayerVideoGravityResizeAspect | JPVideoPlayerMutedPlay progress:nil completed:nil];
}

-(void)jp_playVideoMutedWithURL:(NSURL *)url{
    [self jp_playVideoWithURL:url options:JPVideoPlayerContinueInBackground | JPVideoPlayerMutedPlay | JPVideoPlayerLayerVideoGravityResizeAspect | JPVideoPlayerMutedPlay progress:nil completed:nil];
}

-(void)jp_playVideoWithURL:(NSURL *)url options:(JPVideoPlayerOptions)options progress:(JPVideoPlayerDownloaderProgressBlock)progressBlock completed:(JPVideoPlayerCompletionBlock)completedBlock{
    
    NSString *validOperationKey = NSStringFromClass([self class]);
    [self jp_cancelVideoLoadOperationWithKey:validOperationKey];
    [self stopPlay];
    self.currentPlayingURL = url;
    
    if (url) {
        __weak typeof(self) wself = self;
        id <JPVideoPlayerOperation> operation = [[JPVideoPlayerManager sharedManager] loadVideoWithURL:url showOnView:self options:options progress:progressBlock completed:^(NSString * _Nullable fullVideoCachePath, NSError * _Nullable error, JPVideoPlayerCacheType cacheType, NSURL * _Nullable videoURL) {
            __strong __typeof (wself) sself = wself;
            if (!sself) return;
            
            dispatch_main_async_safe(^{
                if (completedBlock) {
                    completedBlock(fullVideoCachePath, error, cacheType, url);
                }
            });
        }];
        
        [self jp_setVideoLoadOperation:operation forKey:validOperationKey];
    }
    else {
        dispatch_main_async_safe(^{
            if (completedBlock) {
                NSError *error = [NSError errorWithDomain:JPVideoPlayerErrorDomain code:-1 userInfo:@{NSLocalizedDescriptionKey : @"Trying to load a nil url"}];
                completedBlock(nil, error, JPVideoPlayerCacheTypeNone, url);
            }
        });
    }
}

-(void)stopPlay{
    [[JPVideoPlayerCache sharedImageCache] cancelCurrentComletionBlock];
    [[JPVideoPlayerDownloader sharedDownloader] cancelAllDownloads];
    [[JPVideoPlayerManager sharedManager]stopPlay];
}

-(void)setPlayerMute:(BOOL)mute{
    [[JPVideoPlayerManager sharedManager] setPlayerMute:mute];
}

-(BOOL)playerIsMute{
    return [JPVideoPlayerManager sharedManager].playerIsMute;
}

@end
