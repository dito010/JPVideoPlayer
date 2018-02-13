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

#import "JPWebServer.h"

NS_ASSUME_NONNULL_BEGIN

@class JPWebServerHandler;

/**
 *  The JPWebServerConnection class is instantiated by JPWebServer to handle
 *  each new HTTP connection. Each instance stays alive until the connection is
 *  closed.
 *
 *  You cannot use this class directly, but it is made public so you can
 *  subclass it to override some hooks. Use the JPWebServerOption_ConnectionClass
 *  option for JPWebServer to install your custom subclass.
 *
 *  @warning The JPWebServerConnection retains the JPWebServer until the
 *  connection is closed.
 */
@interface JPWebServerConnection : NSObject

/**
 *  Returns the JPWebServer that owns the connection.
 */
@property(nonatomic, readonly) JPWebServer* server;

/**
 *  Returns YES if the connection is using IPv6.
 */
@property(nonatomic, readonly, getter=isUsingIPv6) BOOL usingIPv6;

/**
 *  Returns the address of the local peer (i.e. server) of the connection
 *  as a raw "struct sockaddr".
 */
@property(nonatomic, readonly) NSData* localAddressData;

/**
 *  Returns the address of the local peer (i.e. server) of the connection
 *  as a string.
 */
@property(nonatomic, readonly) NSString* localAddressString;

/**
 *  Returns the address of the remote peer (i.e. client) of the connection
 *  as a raw "struct sockaddr".
 */
@property(nonatomic, readonly) NSData* remoteAddressData;

/**
 *  Returns the address of the remote peer (i.e. client) of the connection
 *  as a string.
 */
@property(nonatomic, readonly) NSString* remoteAddressString;

/**
 *  Returns the total number of bytes received from the remote peer (i.e. client)
 *  so far.
 */
@property(nonatomic, readonly) NSUInteger totalBytesRead;

/**
 *  Returns the total number of bytes sent to the remote peer (i.e. client) so far.
 */
@property(nonatomic, readonly) NSUInteger totalBytesWritten;

/**
 *  Returns the connection socket.
 */
@property(nonatomic, readonly) CFSocketNativeHandle socket;

@end

/**
 *  Hooks to customize the behavior of JPWebServer HTTP connections.
 *
 *  @warning These methods can be called on any JP thread.
 *  Be sure to also call "super" when overriding them.
 */
@interface JPWebServerConnection (Subclassing)

/**
 *  This method is called when the connection is opened.
 *
 *  Return NO to reject the connection e.g. after validating the local
 *  or remote address.
 */
- (BOOL)open;

/**
 *  This method is called whenever data has been received
 *  from the remote peer (i.e. client).
 *
 *  @warning Do not attempt to modify this data.
 */
- (void)didReadBytes:(const void*)bytes length:(NSUInteger)length;

/**
 *  This method is called whenever data has been sent
 *  to the remote peer (i.e. client).
 *
 *  @warning Do not attempt to modify this data.
 */
- (void)didWriteBytes:(const void*)bytes length:(NSUInteger)length;

/**
 *  This method is called after the HTTP headers have been received to
 *  allow replacing the request URL by another one.
 *
 *  The default implementation returns the original URL.
 */
- (NSURL*)rewriteRequestURL:(NSURL*)url withMethod:(NSString*)method headers:(NSDictionary*)headers;

/**
 *  Assuming a valid HTTP request was received, this method is called before
 *  the request is processed.
 *
 *  Return a non-nil JPWebServerResponse to bypass the request processing entirely.
 *
 *  The default implementation checks for HTTP authentication if applicable
 *  and returns a barebone 401 status code response if authentication failed.
 */
- (nullable JPWebServerResponse*)preflightRequest:(JPWebServerRequest*)request;

/**
 *  Assuming a valid HTTP request was received and -preflightRequest: returned nil,
 *  this method is called to process the request by executing the handler's
 *  process block.
 */
- (void)processRequest:(JPWebServerRequest*)request completion:(JPWebServerCompletionBlock)completion;

/**
 *  Assuming a valid HTTP request was received and either -preflightRequest:
 *  or -processRequest:completion: returned a non-nil JPWebServerResponse,
 *  this method is called to override the response.
 *
 *  You can either modify the current response and return it, or return a
 *  completely new one.
 *
 *  The default implementation replaces any response matching the "ETag" or
 *  "Last-Modified-Date" header of the request by a barebone "Not-Modified" (304)
 *  one.
 */
- (JPWebServerResponse*)overrideResponse:(JPWebServerResponse*)response forRequest:(JPWebServerRequest*)request;

/**
 *  This method is called if any error happens while validing or processing
 *  the request or if no JPWebServerResponse was generated during processing.
 *
 *  @warning If the request was invalid (e.g. the HTTP headers were malformed),
 *  the "request" argument will be nil.
 */
- (void)abortRequest:(nullable JPWebServerRequest*)request withStatusCode:(NSInteger)statusCode;

/**
 *  Called when the connection is closed.
 */
- (void)close;

@end

@interface JPWebServerConnection(AVPlayer)

/**
 * Start write video data to `AVPlayer` socket.
 */
- (void)startWriteBody;

/**
 * Stop write video data to `AVPlayer` socket.
 */
- (void)stopReadBody;

/**
 * Call this method to fetch is write response body to socket finished or not.
 */
- (BOOL)isFinishWriteResponseBody;

@end

NS_ASSUME_NONNULL_END
