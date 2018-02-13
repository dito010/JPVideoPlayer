//
// Created by NewPan on 2018/2/6.
// Copyright (c) 2018 NewPan. All rights reserved.
//

#import <GCDWebServer.h>

NS_ASSUME_NONNULL_BEGIN

@interface JPVideoPlayerProxy : NSObject

/**
 * The port to moniter, default is 8080.
 */
@property (nonatomic, assign) NSUInteger proxyPort;

/**
 * The local host name and port for the player proxy.
 */
@property (nonatomic, strong, readonly) NSString *proxyLocalHost;

/**
 * Starts the AVPlayer proxy server listening to localhost.
 * Any requests sent to "http://localhost:8080" will be passed to "http://<proxyHost>:80"
 */
- (void)startPlayerProxy;

/**
 Stops the AVPlayer proxy
 */
- (void)stopPlayerProxy;

/**
 * Fetch the local proxy url for given url.
 *
 * @param url a url.
 *
 * @return the local proxy url.
 */
- (NSURL *)fetchLocalProxyURLForURL:(NSURL *)url;

@end

NS_ASSUME_NONNULL_END