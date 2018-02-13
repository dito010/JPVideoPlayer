//
//  JPWebServerAVPlayerResponse.h
//  Test
//
//  Created by NewPan on 2018/2/10.
//  Copyright © 2018年 NewPan. All rights reserved.
//

#import "JPWebServer.h"

NS_ASSUME_NONNULL_BEGIN

@interface JPWebServerAVPlayerResponse : JPWebServerResponse

/**
 * The file Path.
 */
@property (nonatomic, copy, readonly) NSString *path;

/**
 * The location of range passed in.
 */
@property(nonatomic, assign, readonly) NSUInteger offset;

/**
 * The length of range passed in.
 */
@property(nonatomic, assign, readonly) NSUInteger size;

/**
 * Create a new instance of current class.
 *
 * @see `initWithFile:byteRange:mimeTypeOverrides:`.
 */
+ (nullable instancetype)responseWithFile:(NSString*)path
                                byteRange:(NSRange)range
                        mimeTypeOverrides:(nullable NSDictionary*)overrides;

/**
 *  This method is the designated initializer for the class.
 *
 *  If MIME type overrides are specified, they allow to customize the built-in
 *  mapping from extensions to MIME types. Keys of the dictionary must be lowercased
 *  file extensions without the period, and the values must be the corresponding
 *  MIME types.
 *
 *  @param path      The file path of video data.
 *  @param range     The size of video data.
 *  @param overrides Customize the built-in mapping from extensions to MIME types.
 *
 *  @return The instance of current class.
 */
- (nullable instancetype)initWithFile:(NSString*)path
                            byteRange:(NSRange)range
                    mimeTypeOverrides:(nullable NSDictionary*)overrides;
/**
 * This method is used to update the reading range of video data.
 *
 * The video data is stored in the same file, so when fetch new video data from web and
 * then store the data in the same video file, we need to update the range for the new
 * video data.
 *
 * @param range The range of new video data in video data file.
 */
- (void)updateResponseByteRange:(NSRange)range;

@end

NS_ASSUME_NONNULL_END
