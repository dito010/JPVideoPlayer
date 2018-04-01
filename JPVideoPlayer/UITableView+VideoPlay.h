//
// Created by NewPan on 2018/3/30.
// Copyright (c) 2018 NewPan. All rights reserved.
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface UITableView (VideoPlay)

@property(nonatomic, readonly, nullable) UITableViewCell *jp_playingVideoCell;

@property(nonatomic) CGRect jp_tableViewVisibleFrame;

- (void)jp_handleCellUnreachableTypeForCell:(UITableViewCell *)cell
                                atIndexPath:(NSIndexPath *)indexPath;

- (void)jp_playVideoInVisibleCellsIfNeed;

- (void)jp_scrollViewDidScroll:(UIScrollView *)scrollView;

- (void)jp_scrollViewDidEndDragging:(UIScrollView *)scrollView
                     willDecelerate:(BOOL)decelerate;

- (void)jp_scrollViewDidEndDecelerating:(UIScrollView *)scrollView;

- (void)jp_stopPlayIfNeed;

@end

NS_ASSUME_NONNULL_END