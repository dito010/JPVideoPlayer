//
//  UICollectionView+videoPlayer.m
//  ComponentDemo
//
//  Created by Xuzixiang on 2018/7/5.
//  Copyright © 2018年 frankxzx. All rights reserved.
//

#import "UICollectionView+videoPlayer.h"
#import "JPVideoPlayerCompat.h"
#import "JPVideoPlayerSupportUtils.h"
#import "JPVideoPlayerCollectionViewHelper.h"

@interface UICollectionView()

@property (nonatomic) JPVideoPlayerCollectionViewHelper *helper;

@end

static const NSString *kJPVideoPlayerHelperKey = @"com.jpvideoplayer.scrollview.helper.www";
@implementation UICollectionView (videoPlayer)

- (void)setJp_delegate:(id <JPCollectionViewPlayVideoDelegate>)jp_delegate {
    self.helper.delegate = jp_delegate;
}

- (id <JPCollectionViewPlayVideoDelegate>)jp_delegate {
    return self.helper.delegate;
}

- (UICollectionViewCell *)jp_playingVideoCell {
    return [self.helper playingVideoCell];
}

- (void)setJp_collectionViewVisibleFrame:(CGRect)jp_collectionViewVisibleFrame {
    self.helper.collectionViewVisibleFrame = jp_collectionViewVisibleFrame;
}

- (CGRect)jp_collectionViewVisibleFrame {
    return self.helper.collectionViewVisibleFrame;
}

- (void)setJp_scrollPlayStrategyType:(JPScrollPlayStrategyType)jp_scrollPlayStrategyType {
    self.helper.scrollPlayStrategyType = jp_scrollPlayStrategyType;
}

- (JPScrollPlayStrategyType)jp_scrollPlayStrategyType {
    return self.helper.scrollPlayStrategyType;
}

- (void)setJp_unreachableCellDictionary:(NSDictionary<NSString *, NSString *> *)jp_unreachableCellDictionary {
    self.helper.unreachableCellDictionary = jp_unreachableCellDictionary;
}

- (NSDictionary<NSString *, NSString *> *)jp_unreachableCellDictionary {
    return self.helper.unreachableCellDictionary;
}

- (void)setJp_playVideoInVisibleCellsBlock:(JPPlayVideoInVisibleCollectionCellsBlock)jp_playVideoInVisibleCellsBlock {
    self.helper.playVideoInVisibleCellsBlock = jp_playVideoInVisibleCellsBlock;
}

- (JPPlayVideoInVisibleCollectionCellsBlock)jp_playVideoInVisibleCellsBlock {
    return self.helper.playVideoInVisibleCellsBlock;
}

- (void)setJp_findBestCellInVisibleCellsBlock:(JPPlayVideoInVisibleCollectionCellsBlock)jp_findBestCellInVisibleCellsBlock {
    self.helper.findBestCellInVisibleCellsBlock = jp_findBestCellInVisibleCellsBlock;
}

- (JPPlayVideoInVisibleCollectionCellsBlock)jp_findBestCellInVisibleCellsBlock {
    return self.helper.findBestCellInVisibleCellsBlock;
}

- (void)jp_playVideoInVisibleCellsIfNeed {
    [self.helper playVideoInVisibleCellsIfNeed];
}

- (void)jp_stopPlayIfNeed {
    [self.helper stopPlayIfNeed];
}

- (void)jp_handleCellUnreachableTypeInVisibleCellsAfterReloadData {
    [self.helper handleCellUnreachableTypeInVisibleCellsAfterReloadData];
}

- (void)jp_handleCellUnreachableTypeForCell:(UICollectionViewCell *)cell
                                atIndexPath:(NSIndexPath *)indexPath {
    [self.helper handleCellUnreachableTypeForCell:cell
                                      atIndexPath:indexPath];
}

- (void)jp_scrollViewDidEndDraggingWillDecelerate:(BOOL)decelerate {
    [self.helper scrollViewDidEndDraggingWillDecelerate:decelerate];
}

- (void)jp_scrollViewDidEndDecelerating {
    [self.helper scrollViewDidEndDecelerating];
}

- (void)jp_scrollViewDidScroll {
    [self.helper scrollViewDidScroll];
}

- (BOOL)jp_viewIsVisibleInVisibleFrameAtScrollViewDidScroll:(UIView *)view {
    return [self.helper viewIsVisibleInVisibleFrameAtScrollViewDidScroll:view];
}


#pragma mark - Private

- (JPVideoPlayerCollectionViewHelper *)helper {
    JPVideoPlayerCollectionViewHelper *_helper = objc_getAssociatedObject(self, &kJPVideoPlayerHelperKey);
    if(!_helper){
        _helper = [[JPVideoPlayerCollectionViewHelper alloc] initWithCollectionView:self];
        objc_setAssociatedObject(self, &kJPVideoPlayerHelperKey, _helper, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    return _helper;
}

@end

