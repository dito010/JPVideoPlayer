//
//  JPVideoPlayer.m
//  JPVideoPlayer
//
//  Created by lava on 16/9/13.
//  Hello! I am NewPan from Guangzhou of China, Glad you could use my framework, If you have any question or wanna to contact me, please open https://github.com/Chris-Pan or http://www.jianshu.com/users/e2f2d779c022/latest_articles
//

#import "JPVideoPlayer.h"
#import "JPVideoURLAssetResourceLoader.h"
#import "JPDownloadManager.h"

@interface JPVideoPlayer()<JPVideoURLAssetResourceLoaderDelegate>

/**
 * Video data provider
 * 数据源
 */
@property(nonatomic, strong)JPVideoURLAssetResourceLoader *resourceLoader;

/** asset */
@property(nonatomic, strong)AVURLAsset *videoURLAsset;

/**
 * The Item of playing video
 * 当前正在播放视频的Item
 */
@property (nonatomic, strong) AVPlayerItem *currentPlayerItem;

/**
 * The current picture player
 * 当前图像层
 */
@property (nonatomic, strong) AVPlayerLayer *currentPlayerLayer;

/** 
 * The view of video will play on
 * 视频图像载体View
 */
@property (nonatomic, weak)   UIView *showView;

/** 
 * video url
 * 播放视频url
 */
@property(nonatomic, strong)NSURL *playPathURL;

/** 
 * player
 */
@property(nonatomic, strong)AVPlayer *player;

@end


@implementation JPVideoPlayer

#pragma mark --------------------------------------------------
#pragma mark INITIALIZER

+(instancetype)sharedInstance{
    return [[self alloc]init];
}

+(instancetype)allocWithZone:(struct _NSZone *)zone{
    static id _shareInstance;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _shareInstance = [super allocWithZone:zone];
    });
    return _shareInstance;
}

- (instancetype)init{
    self = [super init];
    if (self) {
        _stopWhenAppDidEnterBackground = YES;
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(appDidEnterBackground) name:UIApplicationWillResignActiveNotification object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(appDidEnterPlayGround) name:UIApplicationDidBecomeActiveNotification object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(playerItemDidPlayToEnd:) name:AVPlayerItemDidPlayToEndTimeNotification object:nil];
        [[NSNotificationCenter defaultCenter]addObserver:self selector:@selector(receiveMemoryWarning) name:UIApplicationDidReceiveMemoryWarningNotification object:nil];
    }
    return self;
}

-(void)dealloc{
    [[NSNotificationCenter defaultCenter]removeObserver:self];
}


#pragma mark --------------------------------------------------
#pragma mark Public

- (void)playWithUrl:(NSURL *)url showView:(UIView *)showView{
    self.playPathURL = url;
    _showView = showView;
    
    // Release all configuration before
    // 释放之前的配置
    [self stop];
    
    // Re-create all all configuration agian.
    // Make the "resourceLoader" become the delegate of "videoURLAsset", and provide data to the player.
    // 将播放器请求数据的代理设为缓存中间区
    JPVideoURLAssetResourceLoader *resourceLoader = [JPVideoURLAssetResourceLoader new];
    self.resourceLoader = resourceLoader;
    resourceLoader.delegate = self;
    NSURL *playUrl = [resourceLoader getSchemeVideoURL:url];
    AVURLAsset *videoURLAsset = [AVURLAsset URLAssetWithURL:playUrl options:nil];
    self.videoURLAsset = videoURLAsset;
    [self.videoURLAsset.resourceLoader setDelegate:resourceLoader queue:dispatch_get_main_queue()];
    AVPlayerItem *playerItem = [AVPlayerItem playerItemWithAsset:videoURLAsset];
    self.currentPlayerItem = playerItem;
    
    self.player = [AVPlayer playerWithPlayerItem:playerItem];
    self.currentPlayerLayer = [AVPlayerLayer playerLayerWithPlayer:self.player];
    self.currentPlayerLayer.frame = CGRectMake(0, 0, showView.bounds.size.width, showView.bounds.size.height);
}

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
        self.currentPlayerLayer = nil;
    }
    self.currentPlayerItem = nil;
    self.player = nil;
    self.playPathURL = nil;
}

-(void)setMute:(BOOL)mute{
    _mute = mute;
    self.player.muted = mute;
}


#pragma mark -----------------------------------------
#pragma mark Observer

-(void)receiveMemoryWarning{
    NSLog(@"receiveMemoryWarning, 内存警告");
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
    // Seek the start point of file data and repeat play, this handle have no Memory surge
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
                
                // When get ready to play note, we can go to play, and can add the video picture on show view.
                // 显示图像逻辑
                [self.player play];
                self.player.muted = self.mute;
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
    
    // Here have a fade in animation
    [UIView animateWithDuration:0.4 animations:^{
        _showView.alpha = 0;
    } completion:^(BOOL finished) {
        for (CALayer *layer in _showView.subviews) {
            [layer removeFromSuperlayer];
        }
        [_showView.layer addSublayer:self.currentPlayerLayer];
        
        [UIView animateWithDuration:0.5 animations:^{
            _showView.alpha = 1;
            
        } completion:nil];
    }];
}

-(void)setCurrentPlayerItem:(AVPlayerItem *)currentPlayerItem{
    
    if (_currentPlayerItem) {
        [_currentPlayerItem removeObserver:self forKeyPath:@"status"];
    }
    
    _currentPlayerItem = currentPlayerItem;
    
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
    
    NSLog(@"File already existed, we play video from disk, 文件已存在, 从本地读取播放");
    
    // Release all configuration before.
    // 释放之前的配置
    [self stop];
    
    // Play video from disk.
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
    NSLog(@"Download finished, 下载完成");
}


@end
