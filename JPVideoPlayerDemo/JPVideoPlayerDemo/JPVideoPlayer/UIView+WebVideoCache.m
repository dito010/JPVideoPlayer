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

@interface UIView ()

@property(nonatomic, getter=isMuted) BOOL mute;

@end

static char videoURLKey;
static char mutedKey;
static NSString *JPVideoPlayerErrorDomain = @"JPVideoPlayerErrorDomain";
@implementation UIView (WebVideoCache)

#pragma mark -----------------------------------------
#pragma mark Public

-(void)jp_playVideoWithURL:(NSURL *)url{
    
    self.mute = NO;
    
    [self jp_playVideoWithURL:url options:JPVideoPlayerContinueInBackground | JPVideoPlayerShowProgressView | JPVideoPlayerShowActivityIndicatorView | JPVideoPlayerLayerVideoGravityResizeAspect operationKey:nil progress:nil completed:nil];
}

-(void)jp_playVideoDisplayStatusViewWithURL:(NSURL *)url{
    
    self.mute = NO;
    
    [self jp_playVideoWithURL:url options:JPVideoPlayerContinueInBackground | JPVideoPlayerShowProgressView | JPVideoPlayerShowActivityIndicatorView | JPVideoPlayerLayerVideoGravityResizeAspect operationKey:nil progress:nil completed:nil];
}

-(void)jp_playVideoMutedDisplayStatusViewWithURL:(NSURL *)url{
    
    self.mute = YES;
    
    [self jp_playVideoWithURL:url options:JPVideoPlayerContinueInBackground | JPVideoPlayerMutedPlay | JPVideoPlayerShowProgressView | JPVideoPlayerShowActivityIndicatorView | JPVideoPlayerLayerVideoGravityResizeAspect operationKey:nil progress:nil completed:nil];
}

-(void)jp_playVideoMutedWithURL:(NSURL *)url{
    
    self.mute = YES;
    
    [self jp_playVideoWithURL:url options:JPVideoPlayerContinueInBackground | JPVideoPlayerMutedPlay | JPVideoPlayerLayerVideoGravityResizeAspect operationKey:nil progress:nil completed:nil];
}

-(void)jp_playVideoWithURL:(NSURL *)url
                           options:(JPVideoPlayerOptions)options
                      operationKey:(NSString *)operationKey
                          progress:(JPVideoPlayerDownloaderProgressBlock)progressBlock
                         completed:(JPVideoPlayerCompletionBlock)completedBlock{
    
    NSString *validOperationKey = operationKey ?: NSStringFromClass([self class]);
    [self jp_cancelVideoLoadOperationWithKey:validOperationKey];
    [[JPVideoPlayerPlayVideoTool sharedTool]stopPlay];
    [[JPVideoPlayerCache sharedImageCache] cancelCurrentComletionBlock];
    
    objc_setAssociatedObject(self, &videoURLKey, url, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    
    if (url) {
        __weak __typeof(self)wself = self;
        
        BOOL isFileURL = [url isFileURL];
        if (isFileURL) {
            
            // location file in disk.
            NSString *path = [url.absoluteString stringByReplacingOccurrencesOfString:@"file://" withString:@""];
            if ([[NSFileManager defaultManager] fileExistsAtPath:path]) {
                [[JPVideoPlayerPlayVideoTool sharedTool] playExistedVideoWithURL:url fullVideoCachePath:path options:options showOnView:self error:^(NSError * _Nullable error) {
                    if (completedBlock) {
                        completedBlock(nil, error, JPVideoPlayerCacheTypeNone, url);
                    }
                }];
            }
            else{
                dispatch_main_async_safe(^{
                    if (completedBlock) {
                        NSError *error = [NSError errorWithDomain:JPVideoPlayerErrorDomain code:-1 userInfo:@{NSLocalizedDescriptionKey : @"Trying to load a invalid location url"}];
                        completedBlock(nil, error, JPVideoPlayerCacheTypeNone, url);
                    }
                });
            }
        }
        else{
            
            // combine progress block.
            JPVideoPlayerDownloaderProgressBlock handleProgressBlock = [self internalHandleProgressBlockWithUserProgressBlock:progressBlock options:options completed:completedBlock];
            
            id <JPVideoPlayerOperation> operation = [[JPVideoPlayerManager sharedManager] loadVideoWithURL:url options:options progress:handleProgressBlock completed:^(NSString * _Nullable fullVideoCachePath, NSError * _Nullable error, JPVideoPlayerCacheType cacheType, NSURL * _Nullable videoURL) {
                __strong __typeof (wself) sself = wself;
                if (!sself) return;
                
                dispatch_main_async_safe(^{
                    
                    // cache the video data from web finished.
                    if (fullVideoCachePath.length && cacheType==JPVideoPlayerCacheTypeNone) {
                        [[JPVideoPlayerPlayVideoTool sharedTool] didCachedVideoDataFinishedFromWebFullVideoCachePath:fullVideoCachePath];
                        
                        if (sself.progressView && (options&JPVideoPlayerShowProgressView)) {
                            [sself hideProgressView];
                        }
                    }
                    
                    // play video from disk.
                    if (cacheType==JPVideoPlayerCacheTypeDisk) {
                        [[JPVideoPlayerPlayVideoTool sharedTool] playExistedVideoWithURL:url fullVideoCachePath:fullVideoCachePath options:options showOnView:self error:^(NSError * _Nullable error) {
                            if (completedBlock) {
                                completedBlock(nil, error, JPVideoPlayerCacheTypeNone, url);
                            }
                        }];
                    }
                    
                    if (completedBlock) {
                        completedBlock(fullVideoCachePath, error, cacheType, url);
                    }
                });
            }];
            
            [self jp_setVideoLoadOperation:operation forKey:validOperationKey];
        }
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
    [self hideProgressView];
    [self hideActivityIndicatorView];
    [[JPVideoPlayerPlayVideoTool sharedTool] stopPlay];
    [[JPVideoPlayerManager sharedManager] cancelAllDownloads];
}

-(void)setPlayerMute:(BOOL)mute{
    if ([JPVideoPlayerPlayVideoTool sharedTool].currentPlayVideoItem) {
        [[JPVideoPlayerPlayVideoTool sharedTool] setMute:mute];
        self.mute = mute;
    }
}

-(BOOL)playerIsMute{
    return self.isMute;
}


#pragma mark -----------------------------------------
#pragma mark Private

-(nonnull JPVideoPlayerDownloaderProgressBlock)internalHandleProgressBlockWithUserProgressBlock:(nonnull JPVideoPlayerDownloaderProgressBlock)userProgressBlock options:(JPVideoPlayerOptions)options completed:(JPVideoPlayerCompletionBlock)completedBlock{
    
    __weak typeof(self) weakSelf = self;
    return ^(NSData * _Nullable data, NSInteger receivedSize, NSInteger expectedSize, NSString *_Nullable tempCachedVideoPath, NSURL * _Nullable targetURL){
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf) return;
        
        if (userProgressBlock) {
            userProgressBlock(data, receivedSize, expectedSize, tempCachedVideoPath, targetURL);
        }
        
        if (![JPVideoPlayerPlayVideoTool sharedTool].currentPlayVideoItem) {
            
            // start display loading status.
            if (options&JPVideoPlayerShowProgressView) {
                [strongSelf showProgressView];
                [strongSelf progressViewStatusChangedWithReceivedSize:receivedSize expectSize:expectedSize];
            }
            
            // start display buffer indicator view.
            if (options&JPVideoPlayerShowActivityIndicatorView) {
                [strongSelf showActivityIndicatorView];
            }
            
            [[JPVideoPlayerPlayVideoTool sharedTool] playVideoWithURL:targetURL tempVideoCachePath:tempCachedVideoPath options:options videoFileExceptSize:expectedSize videoFileReceivedSize:receivedSize showOnView:strongSelf error:^(NSError * _Nullable error) {
                if (error) {
                    if (completedBlock) {
                        completedBlock(tempCachedVideoPath, error, JPVideoPlayerCacheTypeNone, targetURL);
                    }
                }
            }];
        }
        else{
            
            // to ensure only refresh the progress view when the downloading's url is current view's video url.
            NSString *key = [[JPVideoPlayerManager sharedManager] cacheKeyForURL:targetURL];
            if ([JPVideoPlayerPlayVideoTool sharedTool].currentPlayVideoItem && [key isEqualToString:[JPVideoPlayerPlayVideoTool sharedTool].currentPlayVideoItem.playingKey]) {
                
                // refresh loading status.
                if (strongSelf.progressView && (options&JPVideoPlayerShowProgressView)) {
                    [strongSelf progressViewStatusChangedWithReceivedSize:receivedSize expectSize:expectedSize];
                }
                
                [[JPVideoPlayerPlayVideoTool sharedTool] didReceivedDataCacheInDiskByTempPath:tempCachedVideoPath videoFileExceptSize:expectedSize videoFileReceivedSize:receivedSize];
            }
        }
    };
}

-(void)setMute:(BOOL)mute{
    objc_setAssociatedObject(self, &mutedKey, @(mute), OBJC_ASSOCIATION_ASSIGN);
}

-(BOOL)isMute{
    return [objc_getAssociatedObject(self, &mutedKey) boolValue];
}

@end
