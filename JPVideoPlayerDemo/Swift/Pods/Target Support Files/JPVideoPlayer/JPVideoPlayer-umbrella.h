#ifdef __OBJC__
#import <UIKit/UIKit.h>
#else
#ifndef FOUNDATION_EXPORT
#if defined(__cplusplus)
#define FOUNDATION_EXPORT extern "C"
#else
#define FOUNDATION_EXPORT extern
#endif
#endif
#endif

#import "JPVideoPlayerActivityIndicator.h"
#import "JPVideoPlayerCache.h"
#import "JPVideoPlayerCacheConfig.h"
#import "JPVideoPlayerCachePathTool.h"
#import "JPVideoPlayerCompat.h"
#import "JPVideoPlayerDownloader.h"
#import "JPVideoPlayerDownloaderOperation.h"
#import "JPVideoPlayerManager.h"
#import "JPVideoPlayerOperation.h"
#import "JPVideoPlayerPlayVideoTool.h"
#import "JPVideoPlayerProgressView.h"
#import "JPVideoPlayerResourceLoader.h"
#import "NSURL+QueryStrip.h"
#import "UIView+PlayerStatusAndDownloadIndicator.h"
#import "UIView+WebVideoCache.h"
#import "UIView+WebVideoCacheOperation.h"

FOUNDATION_EXPORT double JPVideoPlayerVersionNumber;
FOUNDATION_EXPORT const unsigned char JPVideoPlayerVersionString[];

