//
// Created by NewPan on 2018/2/22.
// Copyright (c) 2018 NewPan. All rights reserved.
//

#import "JPResourceLoadingRequestTask.h"
#import "JPVideoPlayerCompat.h"
#import <AVFoundation/AVFoundation.h>
#import "JPVideoPlayerCacheFile.h"

@implementation JPResourceLoadingRequestTask

- (instancetype)init {
    NSAssert(NO, @"Please use given initialize method.");
    return [self initWithLoadingRequest:[AVAssetResourceLoadingRequest new]
                           requestRange:JPInvalidRange
                              cacheFile:[JPVideoPlayerCacheFile new]
                              customURL:[NSURL new]];
}

- (instancetype)initWithLoadingRequest:(AVAssetResourceLoadingRequest *)loadingRequest
                          requestRange:(NSRange)requestRange
                             cacheFile:(JPVideoPlayerCacheFile *)cacheFile
                             customURL:(NSURL *)customURL {
    NSParameterAssert(loadingRequest);
    NSParameterAssert(JPValidByteRange(requestRange));
    if(!loadingRequest || !JPValidByteRange(requestRange)){
        return nil;
    }

    self = [super init];
    if(self){
        _loadingRequest = loadingRequest;
        _requestRange = requestRange;
        _cacheFile = cacheFile;
        _customURL = customURL;
    }
    return self;
}

+ (instancetype)requestTaskWithLoadingRequest:(AVAssetResourceLoadingRequest *)loadingRequest
                                 requestRange:(NSRange)requestRange
                                    cacheFile:(JPVideoPlayerCacheFile *)cacheFile
                                    customURL:(NSURL *)customURL {
    return [[JPResourceLoadingRequestTask alloc] initWithLoadingRequest:loadingRequest
                                                           requestRange:requestRange
                                                              cacheFile:cacheFile
                                                              customURL:customURL];
}

@end