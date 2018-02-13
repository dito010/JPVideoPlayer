//
//  JPVideoPlayerCacheModel.h
//  JPVideoPlayerDemo
//
//  Created by 尹久盼 on 2018/1/1.
//  Copyright © 2018年 NewPan. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface JPVideoPlayerCacheModel : NSObject<NSCoding, NSCopying>

/**
 * key.
 */
@property(nonatomic, copy, readonly)NSString *key;

/**
 * expected size.
 */
@property(nonatomic, assign, readonly)NSUInteger expectedSize;

/*
 * the token to map video data.
 */
@property(nonatomic, copy, readonly) NSString *dataName;

/*
 * the store index.
 */
@property(nonatomic, assign, readonly) NSUInteger index;

/*
 * the first response data of request flag.
 */
@property(nonatomic, assign, readonly) BOOL isMetadata;

/**
 *  Initialize method.
 */
- (instancetype)initWithKey:(NSString *)key
               expectedSize:(NSUInteger)expectedSize
                   dataName:(NSString *)dataName
                      index:(NSUInteger)index
                 isMetadata:(BOOL)isMetadata;

@end

NS_ASSUME_NONNULL_END
