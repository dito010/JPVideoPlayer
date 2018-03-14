//
// Created by NewPan on 2018/2/20.
// Copyright (c) 2018 NewPan. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "JPResourceLoadingRequestTask.h"

NS_ASSUME_NONNULL_BEGIN

@interface NSURL (StripQuery)

/*
 * Returns absolute string of URL with the query stripped out.
 * If there is no query, returns a copy of absolute string.
 */

- (NSString *)absoluteStringByStrippingQuery;

@end

@interface NSHTTPURLResponse (JPVideoPlayer)

/**
 * Fetch the file length of response.
 *
 * @return The file length of response.
 */
- (long long)jp_fileLength;

/**
 * Check the response support streaming or not.
 *
 * @return The response support streaming or not.
 */
- (BOOL)jp_supportRange;

@end

@interface AVAssetResourceLoadingRequest (JPVideoPlayer)

/**
 * Fill content information for current request use response conent.
 *
 * @param response A response.
 */
- (void)jp_fillContentInformationWithResponse:(NSHTTPURLResponse *)response;

@end

@interface NSFileHandle (JPVideoPlayer)

- (BOOL)jp_safeWriteData:(NSData *)data;

@end

@interface NSURLSessionTask(JPVideoPlayer)

@property(nonatomic) JPResourceLoadingRequestWebTask * webTask;

@end

NS_ASSUME_NONNULL_END
