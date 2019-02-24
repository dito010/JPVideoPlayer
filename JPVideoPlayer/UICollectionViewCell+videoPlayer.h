//
//  UICollectionViewCell+videoPlayer.h
//  ComponentDemo
//
//  Created by Xuzixiang on 2018/7/5.
//  Copyright © 2018年 frankxzx. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "UITableViewCell+WebVideoCache.h"

@interface UICollectionViewCell (videoPlayer)/**
                                              * The video path url.
                                              *
                                              * @note The url may a web url or local file url.
                                              */
@property (nonatomic, nullable) NSURL *jp_videoURL;

/**
 * The view to display video layer.
 */
@property (nonatomic, nullable) UIView *jp_videoPlayView;

/**
 * The style of cell cannot stop in screen center.
 */
@property(nonatomic) JPVideoPlayerUnreachableCellType jp_unreachableCellType;

/**
 * Returns a Boolean value that indicates whether a given cell is equal to
 * the receiver using `jp_videoURL` comparison.
 *
 * @param cell The cell with which to compare the receiver.
 *
 * @return YES if cell is equivalent to the receiver (if they have the same `jp_videoURL` comparison), otherwise NO.
 */
- (BOOL)jp_isEqualToCell:(UICollectionViewCell *)cell;

@end
