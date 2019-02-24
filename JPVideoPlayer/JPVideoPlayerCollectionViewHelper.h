//
//  JPVideoPlayerCollectionViewHelper.h
//  ComponentDemo
//
//  Created by Xuzixiang on 2018/7/5.
//  Copyright © 2018年 frankxzx. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "JPVideoPlayerSupportUtils.h"

@protocol JPCollectionViewPlayVideoDelegate<NSObject>

@optional

/**
 * This method will be call when call `jp_playVideoInVisibleCellsIfNeed` and the find the best cell to play video when
 * CollectionView scroll end.
 *
 * @param collectionView The collectionView.
 * @param cell      The cell ready to play video, you can call `[cell.jp_videoPlayView jp_playVideoMuteWithURL:cell.jp_videoURL progressView:nil]`
 *                  or other method given to play video.
 */
- (void)collectionView:(UICollectionView *)collectionView willPlayVideoOnCell:(UICollectionViewCell *)cell;

@end

typedef UICollectionViewCell *_Nullable (^JPPlayVideoInVisibleCollectionCellsBlock)(NSArray<UICollectionViewCell *> *_Nullable visibleCells);

@interface JPVideoPlayerCollectionViewHelper : NSObject

@property (nonatomic, weak, readonly, nullable) UICollectionView *collectionView;

@property (nonatomic, weak, readonly) UICollectionViewCell *playingVideoCell;

@property (nonatomic, assign) CGRect collectionViewVisibleFrame;

@property (nonatomic, assign) JPScrollPlayStrategyType scrollPlayStrategyType;

@property(nonatomic) JPPlayVideoInVisibleCollectionCellsBlock playVideoInVisibleCellsBlock;

@property(nonatomic) JPPlayVideoInVisibleCollectionCellsBlock findBestCellInVisibleCellsBlock;

@property (nonatomic, strong) NSDictionary<NSString *, NSString *> *unreachableCellDictionary;

@property (nonatomic, weak) id<JPCollectionViewPlayVideoDelegate> delegate;

@property (nonatomic, assign) NSUInteger playVideoSection;

- (instancetype)initWithCollectionView:(UICollectionView *)collectionView NS_DESIGNATED_INITIALIZER;

- (void)handleCellUnreachableTypeForCell:(UICollectionViewCell *)cell
                             atIndexPath:(NSIndexPath *)indexPath;

- (void)handleCellUnreachableTypeInVisibleCellsAfterReloadData;

- (void)playVideoInVisibleCellsIfNeed;

- (void)stopPlayIfNeed;

- (void)scrollViewDidScroll;

- (void)scrollViewDidEndDraggingWillDecelerate:(BOOL)decelerate;

- (void)scrollViewDidEndDecelerating;

- (BOOL)viewIsVisibleInVisibleFrameAtScrollViewDidScroll:(UIView *)view;

@end
