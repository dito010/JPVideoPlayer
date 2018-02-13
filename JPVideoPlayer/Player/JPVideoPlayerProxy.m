//
// Created by NewPan on 2018/2/6.
// Copyright (c) 2018 NewPan. All rights reserved.
//

#import "JPVideoPlayerProxy.h"
#import "JPVideoPlayerCompat.h"
#import "JPVideoPlayerDownloader.h"
#import <GCDWebServerDataResponse.h>
#import "JPVideoPlayerCache.h"
#import "GCDWebServerFileResponse.h"

@interface JPVideoPlayerProxy()

@property (nonatomic, strong) GCDWebServer *webServer;

@end

NSString * __nonnull const AVPlayerProxyLocalHost = @"localhost:8080";
@implementation JPVideoPlayerProxy

- (instancetype)init {
    self = [super init];
    if(self){
        _proxyPort = 8080;
        _proxyLocalHost = [NSString stringWithFormat:@"localhost:%ld", self.proxyPort];
    }
    return self;
}

- (void)setProxyPort:(NSUInteger)proxyPort {
    _proxyPort = proxyPort;
    _proxyLocalHost = [NSString stringWithFormat:@"localhost:%ld", proxyPort];
}

- (void)startPlayerProxy {
    __weak typeof(self) wself = self;
    //    dispatch_main_async_safe (^{
    self.webServer = [[GCDWebServer alloc] init];
    [self.webServer addDefaultHandlerForMethod:@"GET"
                                  requestClass:[GCDWebServerRequest class]
                             asyncProcessBlock:^(__kindof GCDWebServerRequest *request, GCDWebServerCompletionBlock completionBlock) {
                                 
                                 __weak typeof(wself) sself = wself;
                                 [sself didFetchAVPlayerRequest:request completionBlock:completionBlock];
                                 
                             }];
    
    // Start server on port 8080.
    [_webServer startWithPort:self.proxyPort bonjourName:nil];
    //    });
}

- (void)stopPlayerProxy {
    dispatch_main_async_safe (^{
        [_webServer stop];
    });
}

- (NSURL *)fetchLocalProxyURLForURL:(NSURL *)url {
    NSParameterAssert(url);
    if(!url){
        return nil;
    }
    
    NSString *externalDomain = [url host];
    NSString *customUrlString = [url.absoluteString stringByReplacingOccurrencesOfString:externalDomain
                                                                              withString:self.proxyLocalHost];
    return [NSURL URLWithString:customUrlString];
}


#pragma mark - Private

- (void)didFetchAVPlayerRequest:(GCDWebServerRequest *)request
                completionBlock:(GCDWebServerCompletionBlock)completionBlock {
    NSURL *url = [NSURL URLWithString:@"http://static.smartisanos.cn/common/video/smartisanT2.mp4"];
    [[JPVideoPlayerDownloader sharedDownloader] setValue:[request attributeForKey:@"Range"] forHTTPHeaderField:@"Range"];
    [[JPVideoPlayerDownloader sharedDownloader] downloadVideoWithURL:url
                                                             options:nil
                                                            progress:^(NSData *data,
                                                                       NSUInteger receivedSize,
                                                                       NSUInteger expectedSize,
                                                                       NSURLResponse *response,
                                                                       NSURL *url) {
                                                                if(!data){
                                                                    return;
                                                                }

                                                                [[JPVideoPlayerCache sharedCache] storeVideoData:data expectedSize:expectedSize forKey:url.absoluteString completion:^(NSString *key, NSUInteger storedSize, NSString *tempVideoCachePath, NSString *fullVideoCachePath, NSError *error) {

                                                                    GCDWebServerFileResponse *fileResponse = [GCDWebServerFileResponse responseWithFile:tempVideoCachePath];
                                                                    if(completionBlock){
                                                                        completionBlock(fileResponse);
                                                                    }

                                                                }];
                                                                
                                                            } completion:^(NSError *error) {
                                                                
                                                            }];
}

@end
