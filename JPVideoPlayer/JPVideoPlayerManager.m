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

#import "JPVideoPlayerManager.h"
#import "JPVideoPlayerCompat.h"
#import "JPVideoPlayerCachePath.h"
#import "JPVideoPlayer.h"
#import "UIView+WebVideoCache.h"
#import <pthread.h>
#import "JPVideoPlayerSupportUtils.h"
#import "JPVideoPlayerCacheFile.h"
#import "JPVideoPlayerResourceLoader.h"

@interface JPVideoPlayerManagerModel()

@property (nonatomic, strong, nullable) NSArray<NSValue *> *fragmentRanges;

@property (nonatomic, strong) NSURL *videoURL;

@end

@implementation JPVideoPlayerManagerModel

@end

@interface JPVideoPlayerManager()<JPVideoPlayerInternalDelegate,
        JPVideoPlayerDownloaderDelegate,
        JPApplicationStateMonitorDelegate,
        JPDeviceInterfaceOrientationMonitorObserver>

@property (strong, nonatomic, readwrite, nonnull) JPVideoPlayerCache *videoCache;

@property (strong, nonatomic) JPVideoPlayerDownloader *videoDownloader;

@property (strong, nonatomic, nonnull) NSMutableSet<NSURL *> *failedURLs;

@property(nonatomic, assign) BOOL isReturnWhenApplicationDidEnterBackground;

@property(nonatomic, assign) BOOL isReturnWhenApplicationWillResignActive;

@property (nonatomic, strong) JPApplicationStateMonitor *applicationStateMonitor;

@property (nonatomic, strong) JPVideoPlayerManagerModel *managerModel;

@property (nonatomic, strong) JPVideoPlayer *videoPlayer;

@property(nonatomic, strong) dispatch_queue_t syncQueue;

@end

static NSString * const JPVideoPlayerSDKVersionKey = @"com.jpvideoplayer.sdk.version.www";
@implementation JPVideoPlayerManager
@synthesize volume;
@synthesize muted;
@synthesize rate;

+ (nonnull instancetype)sharedManager {
    static dispatch_once_t once;
    static JPVideoPlayerManager *jpVideoPlayerManagerInstance;
    dispatch_once(&once, ^{
        jpVideoPlayerManagerInstance = [self new];
        [[NSUserDefaults standardUserDefaults] setObject:@"3.1.1" forKey:JPVideoPlayerSDKVersionKey];
        [[NSUserDefaults standardUserDefaults] synchronize];
        [[JPDeviceInterfaceOrientationMonitor shared] addObserver:jpVideoPlayerManagerInstance];
        [JPMigration migrateToSDKVersion:@"3.1.1" block:^{

            [jpVideoPlayerManagerInstance.videoCache clearDiskOnCompletion:nil];

        }];
    });
    return jpVideoPlayerManagerInstance;
}

- (nonnull instancetype)init {
    JPVideoPlayerCache *cache = [JPVideoPlayerCache sharedCache];
    JPVideoPlayerDownloader *downloader = [JPVideoPlayerDownloader sharedDownloader];
    downloader.delegate = self;
    return [self initWithCache:cache downloader:downloader];
}

- (nonnull instancetype)initWithCache:(nonnull JPVideoPlayerCache *)cache
                           downloader:(nonnull JPVideoPlayerDownloader *)downloader {
    if ((self = [super init])) {
        _videoCache = cache;
        _videoDownloader = downloader;
        _failedURLs = [NSMutableSet new];
        _videoPlayer = [JPVideoPlayer new];
        _videoPlayer.delegate = self;
        _isReturnWhenApplicationDidEnterBackground = NO;
        _isReturnWhenApplicationWillResignActive = NO;
        _applicationStateMonitor = [JPApplicationStateMonitor new];
        _applicationStateMonitor.delegate = self;
        _syncQueue = dispatch_queue_create("com.jpvideoplayer.manager.sync.queue.www", DISPATCH_QUEUE_SERIAL);
        [NSNotificationCenter.defaultCenter addObserver:self
                                               selector:@selector(audioSessionInterruptionNotification:)
                                                   name:AVAudioSessionInterruptionNotification
                                                 object:nil];
    }
    return self;
}


#pragma mark - Public

+ (void)preferLogLevel:(JPLogLevel)logLevel {
    _logLevel = logLevel;
}

- (void)playVideoWithURL:(NSURL *)url
             showOnLayer:(CALayer *)showLayer
                 options:(JPVideoPlayerOptions)options
           configuration:(JPVideoPlayerConfiguration)configuration {
    JPAssertMainThread;
    if (self.managerModel && [self.managerModel.videoURL.absoluteString isEqualToString:url.absoluteString]) {

    }

    if(!url || !showLayer){
        JPErrorLog(@"url and showLayer can not be nil.");
        return;
    }

    [self reset];
    [self activeAudioSessionIfNeed];

    // Very common mistake is to send the URL using NSString object instead of NSURL. For some strange reason, XCode won't
    // throw any warning for this type mismatch. Here we failsafe this error by allowing URLs to be passed as NSString.
    if ([url isKindOfClass:NSString.class]) {
        url = [NSURL URLWithString:(NSString *)url];
    }

    // Prevents app crashing on argument type error like sending NSNull instead of NSURL
    if (![url isKindOfClass:NSURL.class]) {
        url = nil;
    }

    self.managerModel = [JPVideoPlayerManagerModel new];
    self.managerModel.videoURL = url;
    BOOL isFailedUrl = NO;
    if (url) {
        isFailedUrl = [self.failedURLs containsObject:url];
    }

    if (url.absoluteString.length == 0 || (!(options & JPVideoPlayerRetryFailed) && isFailedUrl)) {
        NSError *error = [NSError errorWithDomain:JPVideoPlayerErrorDomain
                                             code:NSURLErrorFileDoesNotExist
                                         userInfo:@{NSLocalizedDescriptionKey : @"The file of given URL not exists"}];
        [self callDownloadDelegateMethodWithFragmentRanges:nil
                                              expectedSize:1
                                                 cacheType:JPVideoPlayerCacheTypeNone
                                                     error:error];
        return;
    }

    BOOL isFileURL = [url isFileURL];
    if (isFileURL) {
        // play file URL.
        JPDispatchAsyncOnQueue(self.syncQueue, ^{

            [self playLocalVideoWithShowLayer:showLayer
                                          url:url
                                      options:options
                                configuration:configuration];

        });
        return;
    }

    NSString *key = [self cacheKeyForURL:url];
    [self.videoCache queryCacheOperationForKey:key completion:^(NSString *_Nullable videoPath, JPVideoPlayerCacheType cacheType) {

        if (!showLayer) {
            [self reset];
            return;
        }

        if (!videoPath && (![self.delegate respondsToSelector:@selector(videoPlayerManager:shouldDownloadVideoForURL:)] || [self.delegate videoPlayerManager:self shouldDownloadVideoForURL:url])) {
            // play web video.
            JPDispatchAsyncOnQueue(self.syncQueue, ^{

                JPDebugLog(@"Start play a web video: %@", url);
                self.managerModel.cacheType = JPVideoPlayerCacheTypeNone;
                [self.videoPlayer playVideoWithURL:url
                                           options:options
                                         showLayer:showLayer
                                     configuration:configuration];

            });
        }
        else if (videoPath) {
            self.managerModel.cacheType = JPVideoPlayerCacheTypeExisted;
            JPDebugLog(@"Start play a existed video: %@", url);
            JPDispatchAsyncOnQueue(self.syncQueue, ^{

                [self playFragmentVideoWithURL:url
                                       options:options
                                     showLayer:showLayer
                                 configuration:configuration];

            });
        }
        else {
            // video not in cache and download disallowed by delegate.
            NSError *error = [NSError errorWithDomain:JPVideoPlayerErrorDomain
                                                 code:NSURLErrorFileDoesNotExist
                                             userInfo:@{NSLocalizedDescriptionKey: @"Video not in cache and download disallowed by delegate"}];
            [self callDownloadDelegateMethodWithFragmentRanges:nil
                                                  expectedSize:1
                                                     cacheType:JPVideoPlayerCacheTypeNone
                                                         error:error];
            [self reset];
        }
    }];
}

- (void)resumePlayWithURL:(NSURL *)url
              showOnLayer:(CALayer *)showLayer
                  options:(JPVideoPlayerOptions)options
            configuration:(JPVideoPlayerConfiguration)configuration {
    JPAssertMainThread;
    if(!url){
        JPErrorLog(@"url can not be nil");
        return;
    }
    [self activeAudioSessionIfNeed];

    BOOL canResumePlaying = self.managerModel &&
            [self.managerModel.videoURL.absoluteString isEqualToString:url.absoluteString] &&
            self.videoPlayer;
    if(!canResumePlaying){
        JPDebugLog(@"Called resume play, but can not resume play, translate to normal play if need.");
        if (self.delegate && [self.delegate respondsToSelector:@selector(videoPlayerManager:shouldTranslateIntoPlayVideoFromResumePlayForURL:)]) {
            BOOL preferSwitch = [self.delegate videoPlayerManager:self
                 shouldTranslateIntoPlayVideoFromResumePlayForURL:url];
            if(preferSwitch){
                [self playVideoWithURL:url
                           showOnLayer:showLayer
                               options:options
                         configuration:configuration];
            }
        }
        return;
    }

    [self callVideoLengthDelegateMethodWithVideoLength:self.managerModel.fileLength];
    [self callDownloadDelegateMethodWithFragmentRanges:self.managerModel.fragmentRanges
                                          expectedSize:self.managerModel.fileLength
                                             cacheType:self.managerModel.cacheType
                                                 error:nil];
    JPDebugLog(@"Resume play now.");
    [self.videoPlayer resumePlayWithShowLayer:showLayer
                                      options:options
                                configuration:configuration];

}

- (NSString *_Nullable)cacheKeyForURL:(NSURL *)url {
    if (!url) {
        return nil;
    }
    return [url absoluteString];
}

- (NSString *)SDKVersion {
    NSString *res = [[NSUserDefaults standardUserDefaults] valueForKey:JPVideoPlayerSDKVersionKey];
    return (res ? res : @"");
}


#pragma mark - JPVideoPlayerPlaybackProtocol

- (void)setRate:(float)rate {
    [self.videoPlayer setRate:rate];
}

- (float)rate {
    return self.videoPlayer.rate;
}

- (void)setMuted:(BOOL)muted {
    [self.videoPlayer setMuted:muted];
}

- (BOOL)muted {
    return self.videoPlayer.muted;
}

- (void)setVolume:(float)volume {
    [self.videoPlayer setVolume:volume];
}

- (float)volume {
    return self.videoPlayer.volume;
}

- (BOOL)seekToTime:(CMTime)time {
    return [self.videoPlayer seekToTime:time];
}

- (NSTimeInterval)elapsedSeconds {
    return [self.videoPlayer elapsedSeconds];
}

- (NSTimeInterval)totalSeconds {
    return [self.videoPlayer totalSeconds];
}

- (void)pause {
    [self.videoPlayer pause];
}

- (void)resume {
    [self.videoPlayer resume];
}

- (CMTime)currentTime {
    return self.videoPlayer.currentTime;
}

- (void)stopPlay {
    JPDispatchSyncOnMainQueue(^{
        [self.videoDownloader cancel];
        [self.videoPlayer stopPlay];
        [self reset];
    });
}


#pragma mark - JPVideoPlayerInternalDelegate

- (void)videoPlayer:(nonnull JPVideoPlayer *)videoPlayer
didReceiveLoadingRequestTask:(JPResourceLoadingRequestWebTask *)requestTask {
    JPVideoPlayerDownloaderOptions downloaderOptions = [self fetchDownloadOptionsWithOptions:videoPlayer.playerModel.playerOptions];
    [self.videoDownloader downloadVideoWithRequestTask:requestTask
                                       downloadOptions:downloaderOptions];
}

- (BOOL)videoPlayer:(JPVideoPlayer *)videoPlayer
shouldAutoReplayVideoForURL:(NSURL *)videoURL {
    [self savePlaybackElapsedSeconds:0 forVideoURL:videoURL];
    if (self.delegate && [self.delegate respondsToSelector:@selector(videoPlayerManager:shouldAutoReplayForURL:)]) {
        return [self.delegate videoPlayerManager:self shouldAutoReplayForURL:videoURL];
    }
    return YES;
}

- (void)videoPlayer:(nonnull JPVideoPlayer *)videoPlayer
playerStatusDidChange:(JPVideoPlayerStatus)playerStatus {
    if(playerStatus == JPVideoPlayerStatusReadyToPlay){
        if([self fetchPlaybackRecordForVideoURL:self.managerModel.videoURL] > 0){
            BOOL shouldSeek = YES;
            if (self.delegate && [self.delegate respondsToSelector:@selector(videoPlayerManager:shouldResumePlaybackFromPlaybackRecordForURL:elapsedSeconds:)]) {
                shouldSeek = [self.delegate videoPlayerManager:self
                  shouldResumePlaybackFromPlaybackRecordForURL:self.managerModel.videoURL
                                                elapsedSeconds:[self fetchPlaybackRecordForVideoURL:self.managerModel.videoURL]];
            }
            if(shouldSeek){
                [self.videoPlayer seekToTimeWhenRecordPlayback:CMTimeMakeWithSeconds([self fetchPlaybackRecordForVideoURL:self.managerModel.videoURL], 1000)];
            }
        }
    }
    if (self.delegate && [self.delegate respondsToSelector:@selector(videoPlayerManager:playerStatusDidChanged:)]) {
        [self.delegate videoPlayerManager:self playerStatusDidChanged:playerStatus];
    }
}

- (void)videoPlayerPlayProgressDidChange:(nonnull JPVideoPlayer *)videoPlayer
                          elapsedSeconds:(double)elapsedSeconds
                            totalSeconds:(double)totalSeconds {
    if(elapsedSeconds > 0){
        [self savePlaybackElapsedSeconds:self.elapsedSeconds forVideoURL:self.managerModel.videoURL];
    }
    if (self.delegate && [self.delegate respondsToSelector:@selector(videoPlayerManagerPlayProgressDidChange:elapsedSeconds:totalSeconds:error:)]) {
        [self.delegate videoPlayerManagerPlayProgressDidChange:self
                                                elapsedSeconds:elapsedSeconds
                                                  totalSeconds:totalSeconds
                                                         error:nil];
    }
}

- (void)videoPlayer:(nonnull JPVideoPlayer *)videoPlayer
playFailedWithError:(NSError *)error {
    [self stopPlay];
    [self callPlayDelegateMethodWithElapsedSeconds:0
                                      totalSeconds:0
                                             error:error];
}


#pragma mark - JPVideoPlayerDownloaderDelegate

- (void)downloader:(JPVideoPlayerDownloader *)downloader
didReceiveResponse:(NSURLResponse *)response {
    NSUInteger fileLength = self.videoPlayer.playerModel.resourceLoader.cacheFile.fileLength;
    self.managerModel.fileLength = fileLength;
    [self callVideoLengthDelegateMethodWithVideoLength:fileLength];
}

- (void)downloader:(JPVideoPlayerDownloader *)downloader
    didReceiveData:(NSData *)data
      receivedSize:(NSUInteger)receivedSize
      expectedSize:(NSUInteger)expectedSize {
    NSUInteger fileLength = self.videoPlayer.playerModel.resourceLoader.cacheFile.fileLength;
    NSArray<NSValue *> *fragmentRanges = self.videoPlayer.playerModel.resourceLoader.cacheFile.fragmentRanges;
    self.managerModel.cacheType = JPVideoPlayerCacheTypeExisted;
    self.managerModel.fragmentRanges = fragmentRanges;
    [self callDownloadDelegateMethodWithFragmentRanges:fragmentRanges
                                          expectedSize:fileLength
                                             cacheType:self.managerModel.cacheType
                                                 error:nil];
}

- (void)downloader:(JPVideoPlayerDownloader *)downloader
didCompleteWithError:(NSError *)error {
    if (error){
        [self callDownloadDelegateMethodWithFragmentRanges:nil
                                              expectedSize:1
                                                 cacheType:JPVideoPlayerCacheTypeNone
                                                     error:error];

        if (error.code != NSURLErrorNotConnectedToInternet
                && error.code != NSURLErrorCancelled
                && error.code != NSURLErrorTimedOut
                && error.code != NSURLErrorInternationalRoamingOff
                && error.code != NSURLErrorDataNotAllowed
                && error.code != NSURLErrorCannotFindHost
                && error.code != NSURLErrorCannotConnectToHost) {
            if(self.managerModel.videoURL){
                [self.failedURLs addObject:self.managerModel.videoURL];
            }
        }
        [self stopPlay];
    }
    else {
        if ((self.videoPlayer.playerModel.playerOptions & JPVideoPlayerRetryFailed)) {
            if ([self.failedURLs containsObject:self.managerModel.videoURL]) {
                [self.failedURLs removeObject:self.managerModel.videoURL];
            }
        }
    }
}


#pragma mark - JPApplicationStateMonitorDelegate

- (void)applicationStateMonitor:(JPApplicationStateMonitor *)monitor
      applicationStateDidChange:(JPApplicationState)applicationState {
    BOOL needReturn = !self.managerModel.videoURL ||
            self.videoPlayer.playerStatus == JPVideoPlayerStatusStop ||
            self.videoPlayer.playerStatus == JPVideoPlayerStatusPause ||
            self.videoPlayer.playerStatus == JPVideoPlayerStatusFailed;
    if(applicationState == JPApplicationStateWillResignActive){
        BOOL needPause = YES;
        if (self.delegate && [self.delegate respondsToSelector:@selector(videoPlayerManager:shouldPausePlaybackWhenApplicationWillResignActiveForURL:)]) {
            needPause = [self.delegate videoPlayerManager:self
 shouldPausePlaybackWhenApplicationWillResignActiveForURL:self.managerModel.videoURL];
        }
        if(!needPause){
            self.isReturnWhenApplicationWillResignActive = YES;
            return;
        }
        self.isReturnWhenApplicationWillResignActive = needReturn;
        if(needReturn){
            return;
        }
        [self.videoPlayer pause];
    }
    else if(applicationState == JPApplicationStateDidEnterBackground){
        if(!self.isReturnWhenApplicationWillResignActive){
            self.isReturnWhenApplicationDidEnterBackground = self.isReturnWhenApplicationWillResignActive;
            return;
        }
        BOOL needPause = YES;
        if (self.delegate && [self.delegate respondsToSelector:@selector(videoPlayerManager:shouldPausePlaybackWhenApplicationDidEnterBackgroundForURL:)]) {
            needPause = [self.delegate videoPlayerManager:self
shouldPausePlaybackWhenApplicationDidEnterBackgroundForURL:self.managerModel.videoURL];
        }
        if(!needPause){
            return;
        }
        self.isReturnWhenApplicationDidEnterBackground = needReturn;
        if(needReturn){
            return;
        }
        [self.videoPlayer pause];
    }
}

- (void)applicationDidBecomeActiveFromBackground:(JPApplicationStateMonitor *)monitor {
    if(self.isReturnWhenApplicationDidEnterBackground){
        return;
    }

    if (self.delegate && [self.delegate respondsToSelector:@selector(videoPlayerManager:shouldResumePlaybackWhenApplicationDidBecomeActiveFromBackgroundForURL:)]) {
        BOOL needResume = [self.delegate videoPlayerManager:self
shouldResumePlaybackWhenApplicationDidBecomeActiveFromBackgroundForURL:self.managerModel.videoURL];
        if(needResume){
            [self.videoPlayer resume];
            [self activeAudioSessionIfNeed];
        }
    }
}

- (void)applicationDidBecomeActiveFromResignActive:(JPApplicationStateMonitor *)monitor {
    if(self.isReturnWhenApplicationWillResignActive){
        return;
    }

    if (self.delegate && [self.delegate respondsToSelector:@selector(videoPlayerManager:shouldResumePlaybackWhenApplicationDidBecomeActiveFromResignActiveForURL:)]) {
        BOOL needResume = [self.delegate videoPlayerManager:self
shouldResumePlaybackWhenApplicationDidBecomeActiveFromResignActiveForURL:self.managerModel.videoURL];
        if(needResume){
            [self.videoPlayer resume];
            [self activeAudioSessionIfNeed];
        }
    }
}


#pragma mark - Private

- (long long)fetchFileSizeAtPath:(NSString *)filePath{
    NSFileManager* manager = [NSFileManager defaultManager];
    if ([manager fileExistsAtPath:filePath]){
        return [[manager attributesOfItemAtPath:filePath error:nil] fileSize];
    }
    return 0;
}

- (void)reset {
    self.managerModel = nil;
    self.isReturnWhenApplicationDidEnterBackground = NO;
    self.isReturnWhenApplicationWillResignActive = NO;
}

- (JPVideoPlayerDownloaderOptions)fetchDownloadOptionsWithOptions:(JPVideoPlayerOptions)options {
    // download if no cache, and download allowed by delegate.
    JPVideoPlayerDownloaderOptions downloadOptions = 0;
    if (options & JPVideoPlayerContinueInBackground)
        downloadOptions |= JPVideoPlayerDownloaderContinueInBackground;
    if (options & JPVideoPlayerHandleCookies)
        downloadOptions |= JPVideoPlayerDownloaderHandleCookies;
    if (options & JPVideoPlayerAllowInvalidSSLCertificates)
        downloadOptions |= JPVideoPlayerDownloaderAllowInvalidSSLCertificates;
    return downloadOptions;
}

- (void)callVideoLengthDelegateMethodWithVideoLength:(NSUInteger)videoLength {
    JPDispatchAsyncOnMainQueue(^{
        if([self.delegate respondsToSelector:@selector(videoPlayerManager:didFetchVideoFileLength:)]){
            [self.delegate videoPlayerManager:self
                      didFetchVideoFileLength:videoLength];
        }
    });
}

- (void)callDownloadDelegateMethodWithFragmentRanges:(NSArray<NSValue *> *)fragmentRanges
                                        expectedSize:(NSUInteger)expectedSize
                                           cacheType:(JPVideoPlayerCacheType)cacheType
                                               error:(nullable NSError *)error {
    JPDispatchAsyncOnMainQueue(^{
        if (self.delegate && [self.delegate respondsToSelector:@selector(videoPlayerManagerDownloadProgressDidChange:cacheType:fragmentRanges:expectedSize:error:)]) {
            [self.delegate videoPlayerManagerDownloadProgressDidChange:self
                                                             cacheType:cacheType
                                                        fragmentRanges:fragmentRanges
                                                          expectedSize:expectedSize
                                                                 error:error];
        }
    });
}

- (void)callPlayDelegateMethodWithElapsedSeconds:(double)elapsedSeconds
                                    totalSeconds:(double)totalSeconds
                                           error:(nullable NSError *)error {
    JPDispatchAsyncOnMainQueue(^{
        if (self.delegate && [self.delegate respondsToSelector:@selector(videoPlayerManagerPlayProgressDidChange:elapsedSeconds:totalSeconds:error:)]) {
            [self.delegate videoPlayerManagerPlayProgressDidChange:self
                                                    elapsedSeconds:elapsedSeconds
                                                      totalSeconds:totalSeconds
                                                             error:error];
        }
    });
}


#pragma mark - Play Video

- (void)playFragmentVideoWithURL:(NSURL *)url
                         options:(JPVideoPlayerOptions)options
                       showLayer:(CALayer *)showLayer
                   configuration:(JPVideoPlayerConfiguration)configuration {
    JPVideoPlayerModel *model = [self.videoPlayer playVideoWithURL:url
                                                           options:options
                                                         showLayer:showLayer
                                                     configuration:configuration];
    self.managerModel.fileLength = model.resourceLoader.cacheFile.fileLength;
    self.managerModel.fragmentRanges = model.resourceLoader.cacheFile.fragmentRanges;
    [self callVideoLengthDelegateMethodWithVideoLength:model.resourceLoader.cacheFile.fileLength];
    [self callDownloadDelegateMethodWithFragmentRanges:model.resourceLoader.cacheFile.fragmentRanges
                                          expectedSize:model.resourceLoader.cacheFile.fileLength
                                             cacheType:self.managerModel.cacheType
                                                 error:nil];
}


- (void)playLocalVideoWithShowLayer:(CALayer *)showLayer
                                url:(NSURL *)url
                            options:(JPVideoPlayerOptions)options
                      configuration:(JPVideoPlayerConfiguration)configuration {
    // local file.
    JPDebugLog(@"Start play a local video: %@", url);
    NSString *path = [url.absoluteString stringByReplacingOccurrencesOfString:@"file://" withString:@""];
    path = [path stringByRemovingPercentEncoding];
    if ([[NSFileManager defaultManager] fileExistsAtPath:path]) {
        self.managerModel.cacheType = JPVideoPlayerCacheTypeLocation;
        self.managerModel.fileLength = (NSUInteger)[self fetchFileSizeAtPath:path];;
        self.managerModel.fragmentRanges = @[[NSValue valueWithRange:NSMakeRange(0, self.managerModel.fileLength)]];
        [self callVideoLengthDelegateMethodWithVideoLength:self.managerModel.fileLength];
        [self callDownloadDelegateMethodWithFragmentRanges:self.managerModel.fragmentRanges
                                              expectedSize:self.managerModel.fileLength
                                                 cacheType:self.managerModel.cacheType
                                                     error:nil];
        [self.videoPlayer playExistedVideoWithURL:url
                               fullVideoCachePath:path
                                          options:options
                                      showOnLayer:showLayer
                                    configuration:configuration];
    }
    else{
        NSError *error = [NSError errorWithDomain:JPVideoPlayerErrorDomain
                                             code:NSURLErrorFileDoesNotExist
                                         userInfo:@{NSLocalizedDescriptionKey : @"The file of given URL not exists"}];
        [self callDownloadDelegateMethodWithFragmentRanges:nil
                                              expectedSize:1
                                                 cacheType:JPVideoPlayerCacheTypeNone
                                                     error:error];
    }
}


#pragma mark - AudioSession

- (void)activeAudioSessionIfNeed {
    AVAudioSessionCategory audioSessionCategory = AVAudioSessionCategoryPlayback;
    if (self.delegate && [self.delegate respondsToSelector:@selector(videoPlayerManagerPreferAudioSessionCategory:)]) {
        audioSessionCategory = [self.delegate videoPlayerManagerPreferAudioSessionCategory:self];
    }
    [AVAudioSession.sharedInstance setActive:YES error:nil];
    [AVAudioSession.sharedInstance setCategory:audioSessionCategory error:nil];
}


#pragma mark - AVAudioSessionInterruptionNotification

- (void)audioSessionInterruptionNotification:(NSNotification *)note {
    AVPlayer *player = note.object;
    // the player is self player, return.
    if(player == self.videoPlayer.playerModel.player){
        return;
    }
    // self not playing.
    if(!self.videoPlayer.playerModel){
        return;
    }

    if (self.delegate && [self.delegate respondsToSelector:@selector(videoPlayerManager:shouldPausePlaybackWhenReceiveAudioSessionInterruptionNotificationForURL:)]) {
        BOOL shouldPause = [self.delegate videoPlayerManager:self
shouldPausePlaybackWhenReceiveAudioSessionInterruptionNotificationForURL:self.managerModel.videoURL];
        if(shouldPause){
            [self pause];
        }
        return;
    }
    [self pause];
}


#pragma mark - Playback Record

- (double)fetchPlaybackRecordForVideoURL:(NSURL *)videoURL {
    if(!videoURL){
        JPErrorLog(@"videoURL can not be nil.");
        return 0;
    }
    NSDictionary *dictionary = [NSDictionary dictionaryWithContentsOfFile:[JPVideoPlayerCachePath videoPlaybackRecordFilePath]];
    if(!dictionary){
        return 0;
    }
    NSNumber *number = [dictionary valueForKey:[self cacheKeyForURL:videoURL]];
    if(number){
        return [number doubleValue];
    }
    return 0;
}

- (void)savePlaybackElapsedSeconds:(double)elapsedSeconds
                       forVideoURL:(NSURL *)videoURL {
    if(!videoURL){
        return;
    }

    JPDispatchSyncOnMainQueue(^{
        NSMutableDictionary *dictionary = [NSDictionary dictionaryWithContentsOfFile:[JPVideoPlayerCachePath videoPlaybackRecordFilePath]].mutableCopy;
        if(!dictionary){
            dictionary = [@{} mutableCopy];
        }
        elapsedSeconds == 0 ? [dictionary removeObjectForKey:[self cacheKeyForURL:videoURL]] : [dictionary setObject:@(elapsedSeconds) forKey:[self cacheKeyForURL:videoURL]];
        [dictionary writeToFile:[JPVideoPlayerCachePath videoPlaybackRecordFilePath] atomically:YES];
    });
}


#pragma mark - JPDeviceInterfaceOrientationMoniterObserver

- (void)interfaceOrientationMonitor:(JPDeviceInterfaceOrientationMonitor *)monitor
      interfaceOrientationDidChange:(UIDeviceOrientation)interfaceOrientation {
    if (self.delegate && [self.delegate respondsToSelector:@selector(videoPlayerManager:interfaceOrientationDidChange:)]) {
        [self.delegate videoPlayerManager:self
            interfaceOrientationDidChange:interfaceOrientation];
    }
}

@end
