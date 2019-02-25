//
//  JPVideoPlayerCollectionViewHelper.m
//  ComponentDemo
//
//  Created by Xuzixiang on 2018/7/5.
//  Copyright © 2018年 frankxzx. All rights reserved.
//

#import "JPVideoPlayerCollectionViewHelper.h"
#import "UICollectionViewCell+WebVideoCache.h"
#import "UIView+WebVideoCache.h"

@interface JPVideoPlayerCollectionViewHelper()

@property (nonatomic, weak) UICollectionViewCell *playingVideoCell;

@end

@implementation JPVideoPlayerCollectionViewHelper

- (instancetype)init {
    NSAssert(NO, @"Please use given initialize method.");
    return [self initWithCollectionView:[UICollectionView new]];
};

- (instancetype)initWithCollectionView:(UICollectionView *)collectionView {
    NSParameterAssert(collectionView);
    if(!collectionView){
        return nil;
    }
    
    self = [super init];
    if(self){
        _collectionView = collectionView;
        _collectionViewVisibleFrame = CGRectZero;
    }
    return self;
}

- (void)handleCellUnreachableTypeInVisibleCellsAfterReloadData {
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.3 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        UICollectionView *collectionView = self.collectionView;
        for(UICollectionViewCell *cell in collectionView.visibleCells){
            [self handleCellUnreachableTypeForCell:cell atIndexPath:[collectionView indexPathForCell:cell]];
        }
    });
}

- (void)handleCellUnreachableTypeForCell:(UICollectionViewCell *)cell
                             atIndexPath:(NSIndexPath *)indexPath {
    UICollectionView *collectionView = self.collectionView;
    NSArray<UICollectionViewCell *> *visibleCells = [collectionView visibleCells];
    if(!visibleCells.count){
        return;
    }
    
    NSUInteger unreachableCellCount = [self fetchUnreachableCellCountWithVisibleCellsCount:visibleCells.count];
    NSInteger sectionsCount = 1;
    if(collectionView.dataSource && [collectionView.dataSource respondsToSelector:@selector(numberOfSectionsInTableView:)]){
        sectionsCount = [collectionView.dataSource numberOfSectionsInCollectionView:collectionView];
    }
    BOOL isFirstSectionInSections = YES;
    BOOL isLastSectionInSections = YES;
    if(sectionsCount > 1){
        if(indexPath.section != 0){
            isFirstSectionInSections = NO;
        }
        if(indexPath.section != (sectionsCount - 1)){
            isLastSectionInSections = NO;
        }
    }
    NSUInteger rows = [collectionView numberOfItemsInSection:indexPath.section];
    if (unreachableCellCount > 0) {
        if (indexPath.row <= (unreachableCellCount - 1)) {
            if(isFirstSectionInSections){
                cell.jp_unreachableCellType = JPVideoPlayerUnreachableCellTypeTop;
            }
        }
        else if (indexPath.row >= (rows - unreachableCellCount)){
            if(isLastSectionInSections){
                cell.jp_unreachableCellType = JPVideoPlayerUnreachableCellTypeDown;
            }
        }
        else{
            cell.jp_unreachableCellType = JPVideoPlayerUnreachableCellTypeNone;
        }
    }
    else{
        cell.jp_unreachableCellType = JPVideoPlayerUnreachableCellTypeNone;
    }
}

- (void)playVideoInVisibleCellsIfNeed {
    if(self.playingVideoCell){
        [self playVideoWithCell:self.playingVideoCell];
        return;
    }
    
    // handle the first cell cannot play video when initialized.
    [self handleCellUnreachableTypeInVisibleCellsAfterReloadData];
    
    NSArray<UICollectionViewCell *> *visibleCells = [self.collectionView visibleCells];
    // Find first cell need play video in visible cells.
    UICollectionViewCell *targetCell = nil;
    if(self.playVideoInVisibleCellsBlock){
        targetCell = self.playVideoInVisibleCellsBlock(visibleCells);
    }
    else {
        for (UICollectionViewCell *cell in visibleCells) {
            if (cell.jp_videoURL.absoluteString.length > 0) {
                targetCell = cell;
                break;
            }
        }
    }
    
    // Play if found.
    if (targetCell) {
        [self playVideoWithCell:targetCell];
    }
}

- (void)stopPlayIfNeed {
    [self.playingVideoCell.jp_videoPlayView jp_stopPlay];
    self.playingVideoCell = nil;
}

- (void)scrollViewDidScroll {
    [self handleQuickScrollIfNeed];
}

- (void)scrollViewDidEndDraggingWillDecelerate:(BOOL)decelerate {
    if (decelerate == NO) {
        [self handleScrollStopIfNeed];
    }
}

- (void)scrollViewDidEndDecelerating {
    [self handleScrollStopIfNeed];
}

- (BOOL)viewIsVisibleInVisibleFrameAtScrollViewDidScroll:(UIView *)view {
    return [self viewIsVisibleInCollectionViewVisibleFrame:view];
}


#pragma mark - Private

- (BOOL)playingCellIsVisible {
    if(CGRectIsEmpty(self.collectionViewVisibleFrame)){
        return NO;
    }
    if(!self.playingVideoCell){
        return NO;
    }
    
    UIView *strategyView = self.scrollPlayStrategyType == JPScrollPlayStrategyTypeBestCell ? self.playingVideoCell : self.playingVideoCell.jp_videoPlayView;
    if(!strategyView){
        return NO;
    }
    return [self viewIsVisibleInCollectionViewVisibleFrame:strategyView];
}

- (BOOL)viewIsVisibleInCollectionViewVisibleFrame:(UIView *)view {
    CGRect referenceRect = [self.collectionView.superview convertRect:self.collectionViewVisibleFrame toView:nil];
    CGPoint viewLeftTopPoint = view.frame.origin;
    viewLeftTopPoint.y += 1;
    CGPoint topCoordinatePoint = [view.superview convertPoint:viewLeftTopPoint toView:nil];
    BOOL isTopContain = CGRectContainsPoint(referenceRect, topCoordinatePoint);
    
    CGFloat viewBottomY = viewLeftTopPoint.y + view.bounds.size.height;
    viewBottomY -= 2;
    CGPoint viewLeftBottomPoint = CGPointMake(viewLeftTopPoint.x, viewBottomY);
    CGPoint bottomCoordinatePoint = [view.superview convertPoint:viewLeftBottomPoint toView:nil];
    BOOL isBottomContain = CGRectContainsPoint(referenceRect, bottomCoordinatePoint);
    if(!isTopContain && !isBottomContain){
        return NO;
    }
    return YES;
}

- (UICollectionViewCell *)findTheBestPlayVideoCell {
    if(CGRectIsEmpty(self.collectionViewVisibleFrame)){
        return nil;
    }
    
    // To find next cell need play video.
    UICollectionViewCell *targetCell = nil;
    UICollectionView *collectionView = self.collectionView;
    NSArray<UICollectionViewCell *> *visibleCells = [collectionView visibleCells];
    if(self.findBestCellInVisibleCellsBlock){
        return self.findBestCellInVisibleCellsBlock(visibleCells);
    }
    
    CGFloat gap = MAXFLOAT;
    CGRect referenceRect = [collectionView.superview convertRect:self.collectionViewVisibleFrame toView:nil];
    
    for (UICollectionViewCell *cell in visibleCells) {
        if (!(cell.jp_videoURL.absoluteString.length > 0)) {
            continue;
        }
        
        // If need to play video.
        // Find the cell cannot stop in screen center first.
        UIView *strategyView = self.scrollPlayStrategyType == JPScrollPlayStrategyTypeBestCell ? cell : cell.jp_videoPlayView;
        if(!strategyView){
            continue;
        }
        if (cell.jp_unreachableCellType != JPVideoPlayerUnreachableCellTypeNone) {
            // Must the all area of the cell is visible.
            if (cell.jp_unreachableCellType == JPVideoPlayerUnreachableCellTypeTop) {
                CGPoint strategyViewLeftUpPoint = strategyView.frame.origin;
                strategyViewLeftUpPoint.y += 2;
                CGPoint coordinatePoint = [strategyView.superview convertPoint:strategyViewLeftUpPoint toView:nil];
                if (CGRectContainsPoint(referenceRect, coordinatePoint)){
                    targetCell = cell;
                    break;
                }
            }
            else if (cell.jp_unreachableCellType == JPVideoPlayerUnreachableCellTypeDown){
                CGPoint strategyViewLeftUpPoint = cell.frame.origin;
                CGFloat strategyViewDownY = strategyViewLeftUpPoint.y + cell.bounds.size.height;
                CGPoint strategyViewLeftDownPoint = CGPointMake(strategyViewLeftUpPoint.x, strategyViewDownY);
                strategyViewLeftDownPoint.y -= 1;
                CGPoint coordinatePoint = [strategyView.superview convertPoint:strategyViewLeftDownPoint toView:nil];
                if (CGRectContainsPoint(referenceRect, coordinatePoint)){
                    targetCell = cell;
                    break;
                }
            }
        }
        else{
            CGPoint coordinateCenterPoint = [strategyView.superview convertPoint:strategyView.center toView:nil];
            CGFloat delta = fabs(coordinateCenterPoint.y - referenceRect.size.height * 0.5 - referenceRect.origin.y);
            if (delta < gap) {
                gap = delta;
                targetCell = cell;
            }
        }
    }
    
    return targetCell;
}

- (NSUInteger)fetchUnreachableCellCountWithVisibleCellsCount:(NSUInteger)visibleCellsCount {
    if(![self.unreachableCellDictionary.allKeys containsObject:[NSString stringWithFormat:@"%d", (int)visibleCellsCount]]){
        return 0;
    }
    return [[self.unreachableCellDictionary valueForKey:[NSString stringWithFormat:@"%d", (int)visibleCellsCount]] intValue];
}

- (NSDictionary<NSString *, NSString *> *)unreachableCellDictionary {
    if(!_unreachableCellDictionary){
        // The key is the number of visible cells in screen,
        // the value is the number of cells cannot stop in screen center.
        _unreachableCellDictionary = @{
                                       @"4" : @"1",
                                       @"3" : @"1",
                                       @"2" : @"0"
                                       };
    }
    return _unreachableCellDictionary;
}

- (void)playVideoWithCell:(UICollectionViewCell *)cell {
    NSParameterAssert(cell);
    if(!cell){
        return;
    }
    
    self.playingVideoCell = cell;
    if (self.delegate && [self.delegate respondsToSelector:@selector(collectionView:willPlayVideoOnCell:)]) {
        [self.delegate collectionView:self.collectionView willPlayVideoOnCell:cell];
    }
}

- (void)handleQuickScrollIfNeed {
    if (!self.playingVideoCell) {
        return;
    }
    
    // Stop play when the cell playing video is un-visible.
    if (![self playingCellIsVisible]) {
        [self stopPlayIfNeed];
    }
}

- (void)handleScrollStopIfNeed {
    UICollectionViewCell *bestCell = [self findTheBestPlayVideoCell];
    if(!bestCell){
        return;
    }
    
    // If the found cell is the cell playing video, this situation cannot play video again.
    if(bestCell == self.playingVideoCell){
        return;
    }
    
    [self.playingVideoCell.jp_videoPlayView jp_stopPlay];
    [self playVideoWithCell:bestCell];
}

@end
