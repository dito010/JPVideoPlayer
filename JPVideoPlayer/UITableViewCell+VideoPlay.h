//
// Created by NewPan on 2018/3/30.
// Copyright (c) 2018 NewPan. All rights reserved.
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface UITableViewCell (VideoPlay)

/**
 * The video path url.
 * @note The url may a web url or local file url.
 */
@property(nonatomic, nullable) NSURL *jp_videoURL;

/**
 * The view to display video layer.
 */
@property(nonatomic, nullable) UIView *jp_videoPlayView;

@end

NS_ASSUME_NONNULL_END