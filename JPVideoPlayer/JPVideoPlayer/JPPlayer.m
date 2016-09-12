//
//  JPPlayer.m
//  JPVideoPlayer
//
//  Created by Chris on 16/8/21.
//  Copyright © 2016年 lavaMusic. All rights reserved.
//

#import "JPPlayer.h"
#import "JPLoaderURLConnection.h"
#import "JPDownloadManager.h"

@interface JPPlayer()<JPLoaderURLConnectionDelegate>

@property(nonatomic, strong)JPLoaderURLConnection *resourceLoader;
@property(nonatomic, strong)AVURLAsset *videoURLAsset;
@property (nonatomic, strong) JPLoaderURLConnection *resouerLoader;
@property (nonatomic, strong) AVPlayerItem   *currentPlayerItem;
@property (nonatomic, strong) AVPlayerLayer  *currentPlayerLayer;

/** 视频显示的View */
@property (nonatomic, weak)   UIView *showView;

/** 播放视频源 */
@property(nonatomic, strong)NSURL *playPathURL;

/** player */
@property(nonatomic, strong)AVPlayer *player;

@end


@implementation JPPlayer

#pragma mark --------------------------------------------------
#pragma mark INITIALIZER

+(instancetype)sharedInstance{
    static id _shareInstance;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _shareInstance = [[self alloc]init];
    });
    return _shareInstance;
}

- (instancetype)init{
    self = [super init];
    if (self) {
        _stopWhenAppDidEnterBackground = YES;
    }
    return self;
}

-(void)dealloc{
    [[NSNotificationCenter defaultCenter]removeObserver:self];
}


#pragma mark --------------------------------------------------
#pragma mark Public

- (void)resume{
    if (!self.currentPlayerItem) return;
    [self.player play];
}

- (void)pause{
    if (!self.currentPlayerItem) return;
    [self.player pause];
}

- (void)stop{
    if (!self.currentPlayerItem) return;
    [self.player pause];
    [self.player cancelPendingPrerolls];
    if (self.currentPlayerLayer) {
        [self.currentPlayerLayer removeFromSuperlayer];
    }
}

-(void)setMute:(BOOL)mute{
    _mute = mute;
    self.player.muted = mute;
}

- (void)playWithUrl:(NSURL *)url showView:(UIView *)showView{
    self.playPathURL = url;
    _showView = showView;
    [self.player pause];
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(appDidEnterBackground) name:UIApplicationWillResignActiveNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(appDidEnterPlayGround) name:UIApplicationDidBecomeActiveNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(playerItemDidPlayToEnd:) name:AVPlayerItemDidPlayToEndTimeNotification object:nil];
    [[NSNotificationCenter defaultCenter]addObserver:self selector:@selector(receiveMemoryWarning) name:UIApplicationDidReceiveMemoryWarningNotification object:nil];
        
    // 将播放器请求数据的代理设为缓存中间区
    JPLoaderURLConnection *resourceLoader = [JPLoaderURLConnection new];
    self.resourceLoader = resourceLoader;
    resourceLoader.delegate = self;
    NSURL *playUrl = [resourceLoader getSchemeVideoURL:url];
    AVURLAsset *videoURLAsset = [AVURLAsset URLAssetWithURL:playUrl options:nil];
    self.videoURLAsset = videoURLAsset;
    [self.videoURLAsset.resourceLoader setDelegate:resourceLoader queue:dispatch_get_main_queue()];
    AVPlayerItem *playerItem = [AVPlayerItem playerItemWithAsset:videoURLAsset];
    self.currentPlayerItem = playerItem;
    
    // 每次都重新创建播放器
    self.player = [AVPlayer playerWithPlayerItem:playerItem];
    self.currentPlayerLayer = [AVPlayerLayer playerLayerWithPlayer:self.player];
    self.currentPlayerLayer.frame = CGRectMake(0, 0, showView.bounds.size.width, showView.bounds.size.height);
}



#pragma mark -----------------------------------------
#pragma mark Observer

-(void)receiveMemoryWarning{
    NSLog(@"内存警告");
    [self stop];
}

- (void)appDidEnterBackground{
    if (self.stopWhenAppDidEnterBackground) {
        [self pause];
    }
}

- (void)appDidEnterPlayGround{
    [self resume];
}

- (void)playerItemDidPlayToEnd:(NSNotification *)notification{
    // 重复播放, 从起点开始重播, 没有内存暴涨
    __weak typeof(self) weak_self = self;
    [self.player seekToTime:CMTimeMake(0, 1) completionHandler:^(BOOL finished) {
        __strong typeof(weak_self) strong_self = weak_self;
        if (!strong_self) return;
        [strong_self.player play];
    }];
}

-(void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary<NSString *,id> *)change context:(void *)context{
    if ([keyPath isEqualToString:@"status"]) {
        AVPlayerItem *playerItem = (AVPlayerItem *)object;
        AVPlayerItemStatus status = playerItem.status;
        switch (status) {
            case AVPlayerItemStatusUnknown:{
                
            }
                break;
                
            case AVPlayerItemStatusReadyToPlay:{
                [self.player play];
                self.player.muted = self.mute;
                // 显示图像逻辑
                [self handleShowViewSublayers];
                
            }
                break;
                
            case AVPlayerItemStatusFailed:{
                
            }
                break;
            default:
                break;
        }
    }
}


#pragma mark -----------------------------------------
#pragma mark Private

-(void)handleShowViewSublayers{
    [UIView animateWithDuration:0.4 animations:^{
        _showView.alpha = 0;
    } completion:^(BOOL finished) {
        for (CALayer *layer in _showView.subviews) {
            [layer removeFromSuperlayer];
        }
        // 添加视图
        [_showView.layer addSublayer:self.currentPlayerLayer];
        
        [UIView animateWithDuration:0.5 animations:^{
            _showView.alpha = 1;
            
        } completion:nil];
    }];
    
}

-(void)setCurrentPlayerItem:(AVPlayerItem *)currentPlayerItem{
    // 先移除监听者
    if (_currentPlayerItem) {
        [_currentPlayerItem removeObserver:self forKeyPath:@"status"];
    }
    _currentPlayerItem = currentPlayerItem;
    // 添加监听
    [_currentPlayerItem addObserver:self forKeyPath:@"status" options:NSKeyValueObservingOptionNew context:nil];
}

-(void)setCurrentPlayerLayer:(AVPlayerLayer *)currentPlayerLayer{
    if (_currentPlayerLayer) {
        [_currentPlayerLayer removeFromSuperlayer];
    }
    _currentPlayerLayer = currentPlayerLayer;
}


#pragma mark -----------------------------------------
#pragma mark JPLoaderURLConnectionDelegate

-(void)manager:(JPDownloadManager *)manager fileExistedWithPath:(NSString *)filePath{
    NSLog(@"文件已存在, 从本地读取播放");
    // 直接从本地读取数据进行播放
    NSURL *playPathURL = [NSURL fileURLWithPath:filePath];
    AVURLAsset *videoURLAsset = [AVURLAsset URLAssetWithURL:playPathURL options:nil];
    AVPlayerItem *playerItem = [AVPlayerItem playerItemWithAsset:videoURLAsset];
    self.currentPlayerItem = playerItem;
    self.player = [AVPlayer playerWithPlayerItem:playerItem];
    self.currentPlayerLayer = [AVPlayerLayer playerLayerWithPlayer:self.player];
    self.currentPlayerLayer.frame = CGRectMake(0, 0, _showView.bounds.size.width, _showView.bounds.size.height);
}

-(void)didFailLoadingWithManager:(JPDownloadManager *)manager WithError:(NSError *)errorCode{
    
}

-(void)didFinishLoadingWithManager:(JPDownloadManager *)manager fileSavePath:(NSString *)filePath{
    NSLog(@"下载完成");
}
@end
