/*
 Copyright (c) 2012-2015, Pierre-Olivier Latour
 All rights reserved.
 
 Redistribution and use in source and binary forms, with or without
 modification, are permitted provided that the following conditions are met:
 * Redistributions of source code must retain the above copyright
 notice, this list of conditions and the following disclaimer.
 * Redistributions in binary form must reproduce the above copyright
 notice, this list of conditions and the following disclaimer in the
 documentation and/or other materials provided with the distribution.
 * The name of Pierre-Olivier Latour may not be used to endorse
 or promote products derived from this software without specific
 prior written permission.
 
 THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND
 ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
 WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
 DISCLAIMED. IN NO EVENT SHALL PIERRE-OLIVIER LATOUR BE LIABLE FOR ANY
 DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
 (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
 LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
 ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
 (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
 SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

#import <os/object.h>
#import <sys/socket.h>

/**
 *  All JPWebServer headers.
 */

#import "JPWebServerHTTPStatusCodes.h"
#import "JPWebServerFunctions.h"

#import "JPWebServer.h"
#import "JPWebServerConnection.h"

#import "JPWebServerDataResponse.h"
#import "JPWebServerErrorResponse.h"

/**
 *  Check if a custom logging facility should be used instead.
 */

#if defined(__JPWEBSERVER_LOGGING_HEADER__)

#define __JPWEBSERVER_LOGGING_FACILITY_CUSTOM__

#import __JPWEBSERVER_LOGGING_HEADER__

/**
 *  Automatically detect if XLFacility is available and if so use it as a
 *  logging facility.
 */

#elif defined(__has_include) && __has_include("XLFacilityMacros.h")

#define __JPWEBSERVER_LOGGING_FACILITY_XLFACILITY__

#undef XLOG_TAG
#define XLOG_TAG @"JPwebserver.internal"

#import "XLFacilityMacros.h"

#define GWS_LOG_DEBUG(...) XLOG_DEBUG(__VA_ARGS__)
#define GWS_LOG_VERBOSE(...) XLOG_VERBOSE(__VA_ARGS__)
#define GWS_LOG_INFO(...) XLOG_INFO(__VA_ARGS__)
#define GWS_LOG_WARNING(...) XLOG_WARNING(__VA_ARGS__)
#define GWS_LOG_ERROR(...) XLOG_ERROR(__VA_ARGS__)

#define GWS_DCHECK(__CONDITION__) XLOG_DEBUG_CHECK(__CONDITION__)
#define GWS_DNOT_REACHED() XLOG_DEBUG_UNREACHABLE()

/**
 *  If all of the above fail, then use JPWebServer built-in
 *  logging facility.
 */

#else

#define __JPWEBSERVER_LOGGING_FACILITY_BUILTIN__

typedef NS_ENUM(int, JPWebServerLoggingLevel) {
  kJPWebServerLoggingLevel_Debug = 0,
  kJPWebServerLoggingLevel_Verbose,
  kJPWebServerLoggingLevel_Info,
  kJPWebServerLoggingLevel_Warning,
  kJPWebServerLoggingLevel_Error
};

extern JPWebServerLoggingLevel JPWebServerLogLevel;
extern void JPWebServerLogMessage(JPWebServerLoggingLevel level, NSString* _Nonnull format, ...) NS_FORMAT_FUNCTION(2, 3);

#if DEBUG
#define GWS_LOG_DEBUG(...)                                                                                                             \
  do {                                                                                                                                 \
    if (JPWebServerLogLevel <= kJPWebServerLoggingLevel_Debug) JPWebServerLogMessage(kJPWebServerLoggingLevel_Debug, __VA_ARGS__); \
  } while (0)
#else
#define GWS_LOG_DEBUG(...)
#endif
#define GWS_LOG_VERBOSE(...)                                                                                                               \
  do {                                                                                                                                     \
    if (JPWebServerLogLevel <= kJPWebServerLoggingLevel_Verbose) JPWebServerLogMessage(kJPWebServerLoggingLevel_Verbose, __VA_ARGS__); \
  } while (0)
#define GWS_LOG_INFO(...)                                                                                                            \
  do {                                                                                                                               \
    if (JPWebServerLogLevel <= kJPWebServerLoggingLevel_Info) JPWebServerLogMessage(kJPWebServerLoggingLevel_Info, __VA_ARGS__); \
  } while (0)
#define GWS_LOG_WARNING(...)                                                                                                               \
  do {                                                                                                                                     \
    if (JPWebServerLogLevel <= kJPWebServerLoggingLevel_Warning) JPWebServerLogMessage(kJPWebServerLoggingLevel_Warning, __VA_ARGS__); \
  } while (0)
#define GWS_LOG_ERROR(...)                                                                                                             \
  do {                                                                                                                                 \
    if (JPWebServerLogLevel <= kJPWebServerLoggingLevel_Error) JPWebServerLogMessage(kJPWebServerLoggingLevel_Error, __VA_ARGS__); \
  } while (0)

#endif

/**
 *  Consistency check macros used when building Debug only.
 */

#if !defined(GWS_DCHECK) || !defined(GWS_DNOT_REACHED)

#if DEBUG

#define GWS_DCHECK(__CONDITION__) \
  do {                            \
    if (!(__CONDITION__)) {       \
      abort();                    \
    }                             \
  } while (0)
#define GWS_DNOT_REACHED() abort()

#else

#define GWS_DCHECK(__CONDITION__)
#define GWS_DNOT_REACHED()

#endif

#endif

NS_ASSUME_NONNULL_BEGIN

/**
 *  JPWebServer internal constants and APIs.
 */

#define kJPWebServerDefaultMimeType @"application/octet-stream"
#define kJPWebServerErrorDomain @"JPWebServerErrorDomain"

static inline BOOL JPWebServerIsValidByteRange(NSRange range) {
  return ((range.location != NSUIntegerMax) || (range.length > 0));
}

static inline NSError* JPWebServerMakePosixError(int code) {
  return [NSError errorWithDomain:NSPOSIXErrorDomain code:code userInfo:@{NSLocalizedDescriptionKey : (NSString*)[NSString stringWithUTF8String:strerror(code)]}];
}

extern void JPWebServerInitializeFunctions();
extern NSString* _Nullable JPWebServerNormalizeHeaderValue(NSString* _Nullable value);
extern NSString* _Nullable JPWebServerTruncateHeaderValue(NSString* _Nullable value);
extern NSString* _Nullable JPWebServerExtractHeaderValueParameter(NSString* _Nullable value, NSString* attribute);
extern NSStringEncoding JPWebServerStringEncodingFromCharset(NSString* charset);
extern BOOL JPWebServerIsTextContentType(NSString* type);
extern NSString* JPWebServerDescribeData(NSData* data, NSString* contentType);
extern NSString* JPWebServerComputeMD5Digest(NSString* format, ...) NS_FORMAT_FUNCTION(1, 2);
extern NSString* JPWebServerStringFromSockAddr(const struct sockaddr* addr, BOOL includeService);

@interface JPWebServerConnection ()
- (instancetype)initWithServer:(JPWebServer*)server localAddress:(NSData*)localAddress remoteAddress:(NSData*)remoteAddress socket:(CFSocketNativeHandle)socket;
@end

@interface JPWebServer ()
@property(nonatomic, readonly) NSMutableArray* handlers;
@property(nonatomic, readonly, nullable) NSString* serverName;
@property(nonatomic, readonly, nullable) NSString* authenticationRealm;
@property(nonatomic, readonly, nullable) NSMutableDictionary* authenticationBasicAccounts;
@property(nonatomic, readonly, nullable) NSMutableDictionary* authenticationDigestAccounts;
@property(nonatomic, readonly) BOOL shouldAutomaticallyMapHEADToGET;
@property(nonatomic, readonly) dispatch_queue_priority_t dispatchQueuePriority;
- (void)willStartConnection:(JPWebServerConnection*)connection;
- (void)didEndConnection:(JPWebServerConnection*)connection;
@end

@interface JPWebServerHandler : NSObject
@property(nonatomic, readonly) JPWebServerMatchBlock matchBlock;
@property(nonatomic, readonly) JPWebServerAsyncProcessBlock asyncProcessBlock;
@end

@interface JPWebServerRequest ()
@property(nonatomic, readonly) BOOL usesChunkedTransferEncoding;
@property(nonatomic) NSData* localAddressData;
@property(nonatomic) NSData* remoteAddressData;
- (void)prepareForWriting;
- (BOOL)performOpen:(NSError**)error;
- (BOOL)performWriteData:(NSData*)data error:(NSError**)error;
- (BOOL)performClose:(NSError**)error;
- (void)setAttribute:(nullable id)attribute forKey:(NSString*)key;
@end

@interface JPWebServerResponse ()
@property(nonatomic, readonly) NSDictionary* additionalHeaders;
@property(nonatomic, readonly) BOOL usesChunkedTransferEncoding;
- (void)prepareForReading;
- (BOOL)performOpen:(NSError**)error;
- (void)performReadDataWithCompletion:(JPWebServerBodyReaderCompletionBlock)block;
- (void)performClose;
@end

NS_ASSUME_NONNULL_END
