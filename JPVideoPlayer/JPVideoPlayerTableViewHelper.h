//
// Created by NewPan on 2018/3/30.
// Copyright (c) 2018 NewPan. All rights reserved.
//

#import "UITableView+WebVideoCache.h"

@protocol JPTableViewPlayVideoDelegate;

NS_ASSUME_NONNULL_BEGIN

@interface JPVideoPlayerTableViewHelper : NSObject

@property (nonatomic, weak, readonly, nullable) UIScrollView *scrollView;

@property (nonatomic, weak, readonly) UITableViewCell *playingVideoCell;

@property(nonatomic, assign) CGRect tableViewVisibleFrame;

@property(nonatomic, assign) JPScrollPlayStrategyType scrollPlayStrategyType;

@property (nonatomic, strong) NSDictionary<NSString *, NSString *> *unreachableCellDictionary;

@property (nonatomic, weak) id<JPTableViewPlayVideoDelegate> delegate;

- (instancetype)initWithScrollView:(UIScrollView *)scrollView NS_DESIGNATED_INITIALIZER;

- (void)handleCellUnreachableTypeForCell:(UITableViewCell *)cell
                             atIndexPath:(NSIndexPath *)indexPath;

- (void)handleCellUnreachableTypeInVisibleCellsAfterReloadData;

- (void)playVideoInVisibleCellsIfNeed;

- (void)stopPlayIfNeed;

- (void)scrollViewDidScroll:(UIScrollView *)scrollView;

- (void)scrollViewDidEndDragging:(UIScrollView *)scrollView
                     willDecelerate:(BOOL)decelerate;

- (void)scrollViewDidEndDecelerating:(UIScrollView *)scrollView;

@end

NS_ASSUME_NONNULL_END