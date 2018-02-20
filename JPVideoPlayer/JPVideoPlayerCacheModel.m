//
//  JPVideoPlayerCacheModel.m
//  JPVideoPlayerDemo
//
//  Created by 尹久盼 on 2018/1/1.
//  Copyright © 2018年 NewPan. All rights reserved.
//

#import "JPVideoPlayerCacheModel.h"

@interface JPVideoPlayerCacheModel()

/**
 * key.
 */
@property(nonatomic, copy)NSString *key;

/**
 * expected size.
 */
@property(nonatomic, assign)NSUInteger expectedSize;

/*
 * the token to map video data.
 */
@property(nonatomic, copy) NSString *dataName;

/*
 * the first response data of request flag.
 */
@property(nonatomic, assign) BOOL isMetadata;

/*
 * the store index.
 */
@property(nonatomic, assign) NSUInteger index;

@end

@implementation JPVideoPlayerCacheModel

- (instancetype)initWithKey:(NSString *)key
               expectedSize:(NSUInteger)expectedSize
                   dataName:(NSString *)dataName
                      index:(NSUInteger)index
                 isMetadata:(BOOL)isMetadata {
    NSParameterAssert(key);
    NSParameterAssert(dataName);
    self = [super init];
    if (self) {
        _key = key;
        _expectedSize = expectedSize;
        _dataName = dataName;
        _index = index;
        _isMetadata = isMetadata;
    }
    return self;
}

- (void)encodeWithCoder:(NSCoder *)aCoder {
    [aCoder encodeObject:self.key forKey:@"key"];
    [aCoder encodeInteger:self.expectedSize forKey:@"expectedSize"];
    [aCoder encodeObject:self.dataName forKey:@"dataName"];
    [aCoder encodeInteger:self.index forKey:@"index"];
    [aCoder encodeBool:self.isMetadata forKey:@"isMetadata"];
}

- (id)copyWithZone:(NSZone *)zone {
    return [[[self class] allocWithZone:zone] initWithKey:self.key
                                             expectedSize:self.expectedSize
                                                 dataName:self.dataName
                                                    index:self.index
                                               isMetadata:self.isMetadata];
}

- (instancetype)initWithCoder:(NSCoder *)aDecoder {
    self = [super init];
    if (self) {
        self.key = [aDecoder decodeObjectForKey:@"key"];
        self.expectedSize = [aDecoder decodeIntegerForKey:@"expectedSize"];
        self.dataName = [aDecoder decodeObjectForKey:@"dataName"];
        self.index = [aDecoder decodeIntegerForKey:@"index"];
        self.isMetadata = [aDecoder decodeBoolForKey:@"isMetadata"];
    }
    return self;
}

- (BOOL)isEqual:(id)object {
    if (!object) {
        return NO;
    }
    
    if (self == object) {
        return YES;
    }
    
    if (![object isKindOfClass:[JPVideoPlayerCacheModel class]]) {
        return NO;
    }
    
    return [self isEqualToCacheModel:(JPVideoPlayerCacheModel *)object];
}

- (BOOL)isEqualToCacheModel:(JPVideoPlayerCacheModel *)cacheModel {
    NSParameterAssert(self.key);
    NSParameterAssert(self.dataName);
    NSParameterAssert(cacheModel.key);
    NSParameterAssert(cacheModel.dataName);
    BOOL keyMatch = [self.key isEqualToString:cacheModel.key];
    BOOL dataNameMatch = [self.dataName isEqualToString:cacheModel.dataName];
    return keyMatch && dataNameMatch;
}

@end
