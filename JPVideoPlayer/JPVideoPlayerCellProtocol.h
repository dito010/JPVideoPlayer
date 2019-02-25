//
// Created by NewPan on 2019-02-24.
// Copyright (c) 2019 NewPan. All rights reserved.
//

#import <UIKit/UIKit.h>

typedef NS_ENUM(NSInteger , JPVideoPlayerUnreachableCellType) {
    JPVideoPlayerUnreachableCellTypeNone = 0,
    JPVideoPlayerUnreachableCellTypeTop,
    JPVideoPlayerUnreachableCellTypeDown
};

NS_ASSUME_NONNULL_BEGIN

@protocol JPVideoPlayerCellProtocol <NSObject>

@required
/**
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
- (BOOL)jp_isEqualToCell:(UIView<JPVideoPlayerCellProtocol> *)cell;

@end

NS_ASSUME_NONNULL_END