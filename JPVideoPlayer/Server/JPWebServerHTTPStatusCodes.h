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

// http://www.w3.org/Protocols/rfc2616/rfc2616-sec10.html
// http://www.iana.org/assignments/http-status-codes/http-status-codes.xhtml

#import <Foundation/Foundation.h>

/**
 *  Convenience constants for "informational" HTTP status codes.
 */
typedef NS_ENUM(NSInteger, JPWebServerInformationalHTTPStatusCode) {
  kJPWebServerHTTPStatusCode_Continue = 100,
  kJPWebServerHTTPStatusCode_SwitchingProtocols = 101,
  kJPWebServerHTTPStatusCode_Processing = 102
};

/**
 *  Convenience constants for "successful" HTTP status codes.
 */
typedef NS_ENUM(NSInteger, JPWebServerSuccessfulHTTPStatusCode) {
  kJPWebServerHTTPStatusCode_OK = 200,
  kJPWebServerHTTPStatusCode_Created = 201,
  kJPWebServerHTTPStatusCode_Accepted = 202,
  kJPWebServerHTTPStatusCode_NonAuthoritativeInformation = 203,
  kJPWebServerHTTPStatusCode_NoContent = 204,
  kJPWebServerHTTPStatusCode_ResetContent = 205,
  kJPWebServerHTTPStatusCode_PartialContent = 206,
  kJPWebServerHTTPStatusCode_MultiStatus = 207,
  kJPWebServerHTTPStatusCode_AlreadyReported = 208
};

/**
 *  Convenience constants for "redirection" HTTP status codes.
 */
typedef NS_ENUM(NSInteger, JPWebServerRedirectionHTTPStatusCode) {
  kJPWebServerHTTPStatusCode_MultipleChoices = 300,
  kJPWebServerHTTPStatusCode_MovedPermanently = 301,
  kJPWebServerHTTPStatusCode_Found = 302,
  kJPWebServerHTTPStatusCode_SeeOther = 303,
  kJPWebServerHTTPStatusCode_NotModified = 304,
  kJPWebServerHTTPStatusCode_UseProxy = 305,
  kJPWebServerHTTPStatusCode_TemporaryRedirect = 307,
  kJPWebServerHTTPStatusCode_PermanentRedirect = 308
};

/**
 *  Convenience constants for "client error" HTTP status codes.
 */
typedef NS_ENUM(NSInteger, JPWebServerClientErrorHTTPStatusCode) {
  kJPWebServerHTTPStatusCode_BadRequest = 400,
  kJPWebServerHTTPStatusCode_Unauthorized = 401,
  kJPWebServerHTTPStatusCode_PaymentRequired = 402,
  kJPWebServerHTTPStatusCode_Forbidden = 403,
  kJPWebServerHTTPStatusCode_NotFound = 404,
  kJPWebServerHTTPStatusCode_MethodNotAllowed = 405,
  kJPWebServerHTTPStatusCode_NotAcceptable = 406,
  kJPWebServerHTTPStatusCode_ProxyAuthenticationRequired = 407,
  kJPWebServerHTTPStatusCode_RequestTimeout = 408,
  kJPWebServerHTTPStatusCode_Conflict = 409,
  kJPWebServerHTTPStatusCode_Gone = 410,
  kJPWebServerHTTPStatusCode_LengthRequired = 411,
  kJPWebServerHTTPStatusCode_PreconditionFailed = 412,
  kJPWebServerHTTPStatusCode_RequestEntityTooLarge = 413,
  kJPWebServerHTTPStatusCode_RequestURITooLong = 414,
  kJPWebServerHTTPStatusCode_UnsupportedMediaType = 415,
  kJPWebServerHTTPStatusCode_RequestedRangeNotSatisfiable = 416,
  kJPWebServerHTTPStatusCode_ExpectationFailed = 417,
  kJPWebServerHTTPStatusCode_UnprocessableEntity = 422,
  kJPWebServerHTTPStatusCode_Locked = 423,
  kJPWebServerHTTPStatusCode_FailedDependency = 424,
  kJPWebServerHTTPStatusCode_UpgradeRequired = 426,
  kJPWebServerHTTPStatusCode_PreconditionRequired = 428,
  kJPWebServerHTTPStatusCode_TooManyRequests = 429,
  kJPWebServerHTTPStatusCode_RequestHeaderFieldsTooLarge = 431
};

/**
 *  Convenience constants for "server error" HTTP status codes.
 */
typedef NS_ENUM(NSInteger, JPWebServerServerErrorHTTPStatusCode) {
  kJPWebServerHTTPStatusCode_InternalServerError = 500,
  kJPWebServerHTTPStatusCode_NotImplemented = 501,
  kJPWebServerHTTPStatusCode_BadGateway = 502,
  kJPWebServerHTTPStatusCode_ServiceUnavailable = 503,
  kJPWebServerHTTPStatusCode_GatewayTimeout = 504,
  kJPWebServerHTTPStatusCode_HTTPVersionNotSupported = 505,
  kJPWebServerHTTPStatusCode_InsufficientStorage = 507,
  kJPWebServerHTTPStatusCode_LoopDetected = 508,
  kJPWebServerHTTPStatusCode_NotExtended = 510,
  kJPWebServerHTTPStatusCode_NetworkAuthenticationRequired = 511
};
