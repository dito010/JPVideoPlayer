//
// Created by NewPan on 2018/3/30.
// Copyright (c) 2018 NewPan. All rights reserved.
//

#import "JPVideoPlayerScrollViewHelper.h"
#import "UITableViewCell+VideoPlay.h"
#import "UIView+WebVideoCache.h"

/**
 * The style of cell cannot stop in screen center.
 */
typedef NS_OPTIONS(NSUInteger , JPVideoPlayerUnreachableCellType) {
    JPVideoPlayerUnreachableCellTypeNone = 0,
    JPVideoPlayerUnreachableCellTypeTop = 1,
    JPVideoPlayerUnreachableCellTypeDown = 2
};

@interface UITableViewCell (UnreachableCellType)

@property(nonatomic) JPVideoPlayerUnreachableCellType unreachableCellType;

@end

@implementation UITableViewCell (UnreachableCellType)

- (void)setUnreachableCellType:(JPVideoPlayerUnreachableCellType)unreachableCellType {
    objc_setAssociatedObject(self, @selector(unreachableCellType), @(unreachableCellType), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (JPVideoPlayerUnreachableCellType)unreachableCellType {
    return [objc_getAssociatedObject(self, _cmd) unsignedIntValue];
}

@end

@interface JPVideoPlayerScrollViewHelper()

@property (nonatomic, weak) UITableViewCell *playingVideoCell;

@property (nonatomic, strong) NSDictionary<NSNumber *, NSNumber *> *unreachableCellDict;

@end

@implementation JPVideoPlayerScrollViewHelper

- (instancetype)initWithScrollView:(UIScrollView *)scrollView {
    NSParameterAssert(scrollView);
    if(!scrollView){
        return nil;
    }

    self = [super init];
    if(self){
        _scrollView = scrollView;
        _tableViewVisibleFrame = CGRectZero;
    }
    return self;
}

- (void)handleCellUnreachableTypeForCell:(UITableViewCell *)cell
                             atIndexPath:(NSIndexPath *)indexPath {
    if(![self scrollViewIsTableViewOrCollectionView:self.scrollView]){
        return;
    }
    UITableView *tableView = (UITableView *)self.scrollView;
    NSParameterAssert(tableView.numberOfSections == 1);
    if(tableView.numberOfSections != 1){
        return;
    }

    NSArray<UITableViewCell *> *visibleCells = [tableView visibleCells];
    NSUInteger unreachableCellCount = [self fetchUnreachableCellCountWithVisibleCellsCount:visibleCells.count];
    NSUInteger rows = [tableView numberOfRowsInSection:0];
    if (unreachableCellCount > 0) {
        if (indexPath.row <= (unreachableCellCount - 1)) {
            cell.unreachableCellType = JPVideoPlayerUnreachableCellTypeTop;
        }
        else if (indexPath.row >= (rows - unreachableCellCount)){
            cell.unreachableCellType = JPVideoPlayerUnreachableCellTypeDown;
        }
        else{
            cell.unreachableCellType = JPVideoPlayerUnreachableCellTypeNone;
        }
    }
    else{
        cell.unreachableCellType = JPVideoPlayerUnreachableCellTypeNone;
    }
}

- (void)playVideoInVisibleCellsIfNeed {
    if(self.playingVideoCell){
        [self playVideoWithCell:self.playingVideoCell];
        return;
    }

    if(![self scrollViewIsTableViewOrCollectionView:self.scrollView]){
        return;
    }

    UITableView *tableView = (UITableView *)self.scrollView;
    NSArray<UITableViewCell *> *visibleCells = [tableView visibleCells];
    // Find first cell need play video in visible cells.
    UITableViewCell *targetCell = nil;
    for (UITableViewCell *cell in visibleCells) {
        if (cell.jp_videoURL.absoluteString.length > 0) {
            targetCell = cell;
            break;
        }
    }

    // Play if found.
    if (targetCell) {
        [self playVideoWithCell:targetCell];
    }
}

- (void)stopPlayIfNeed {
    if(![self scrollViewIsTableViewOrCollectionView:self.scrollView]){
        return;
    }
    [self.playingVideoCell.jp_videoPlayView jp_stopPlay];
    self.playingVideoCell = nil;
}

- (void)scrollViewDidScroll:(UIScrollView *)scrollView {
    if(![self scrollViewIsTableViewOrCollectionView:self.scrollView]){
        return;
    }

    [self handleQuickScrollIfNeed];
}

- (void)scrollViewDidEndDragging:(UIScrollView *)scrollView
                  willDecelerate:(BOOL)decelerate {
    if(![self scrollViewIsTableViewOrCollectionView:scrollView]){
        return;
    }

    if (decelerate == NO) {
        [self handleScrollStopIfNeed];
    }
}

- (void)scrollViewDidEndDecelerating:(UIScrollView *)scrollView {
    if(![self scrollViewIsTableViewOrCollectionView:scrollView]){
        return;
    }
    [self handleScrollStopIfNeed];
}


#pragma mark - Private

- (BOOL)playingCellIsVisible {
    if(CGRectIsEmpty(self.tableViewVisibleFrame)){
        return NO;
    }
    if(!self.playingVideoCell){
        return NO;
    }

    CGRect referenceRect = [self.scrollView.superview convertRect:self.tableViewVisibleFrame toView:nil];
    CGPoint cellLeftTopPoint = self.playingVideoCell.frame.origin;
    cellLeftTopPoint.y += 1;
    CGPoint topCoordinatePoint = [self.playingVideoCell.superview convertPoint:cellLeftTopPoint toView:nil];
    BOOL isTopContain = CGRectContainsPoint(referenceRect, topCoordinatePoint);

    CGFloat cellDownY = cellLeftTopPoint.y + self.playingVideoCell.bounds.size.height;
    cellDownY -= 2;
    CGPoint cellLeftBottomPoint = CGPointMake(cellLeftTopPoint.x, cellDownY);
    CGPoint bottomCoordinatePoint = [self.playingVideoCell.superview convertPoint:cellLeftBottomPoint toView:nil];
    BOOL isBottomContain = CGRectContainsPoint(referenceRect, bottomCoordinatePoint);
    if(!isTopContain && !isBottomContain){
        return NO;
    }
    return YES;
}

- (UITableViewCell *)findTheBestPlayVideoCell {
    if(CGRectIsEmpty(self.tableViewVisibleFrame)){
        return nil;
    }

    // To find next cell need play video.
    UITableViewCell *targetCell = nil;
    UITableView *tableView = (UITableView *)self.scrollView;
    NSArray<UITableViewCell *> *visibleCells = [tableView visibleCells];
    CGFloat gap = MAXFLOAT;
    CGRect referenceRect = [tableView.superview convertRect:self.tableViewVisibleFrame toView:nil];

    for (UITableViewCell *cell in visibleCells) {
        @autoreleasepool {
            if (cell.jp_videoURL.absoluteString.length > 0) { // If need to play video.
                // Find the cell cannot stop in screen center first.
                if (cell.unreachableCellType != JPVideoPlayerUnreachableCellTypeNone) {
                    // Must the all area of the cell is visible.
                    if (cell.unreachableCellType == JPVideoPlayerUnreachableCellTypeTop) {
                        CGPoint cellLeftUpPoint = cell.frame.origin;
                        cellLeftUpPoint.y += 2;
                        CGPoint coordinatePoint = [cell.superview convertPoint:cellLeftUpPoint toView:nil];
                        if (CGRectContainsPoint(referenceRect, coordinatePoint)){
                            targetCell = cell;
                            break;
                        }
                    }
                    else if (cell.unreachableCellType == JPVideoPlayerUnreachableCellTypeDown){
                        CGPoint cellLeftUpPoint = cell.frame.origin;
                        CGFloat cellDownY = cellLeftUpPoint.y + cell.bounds.size.height;
                        CGPoint cellLeftDownPoint = CGPointMake(cellLeftUpPoint.x, cellDownY);
                        cellLeftDownPoint.y -= 1;
                        CGPoint coordinatePoint = [cell.superview convertPoint:cellLeftDownPoint toView:nil];
                        if (CGRectContainsPoint(referenceRect, coordinatePoint)){
                            targetCell = cell;
                            break;
                        }
                    }
                }
                else{
                    CGPoint coordinateCenterPoint = [cell.superview convertPoint:cell.center toView:nil];
                    CGFloat delta = fabs(coordinateCenterPoint.y - referenceRect.size.height * 0.5 - referenceRect.origin.y);
                    if (delta < gap) {
                        gap = delta;
                        targetCell = cell;
                    }
                }
            }
        }
    }

    return targetCell;
}

- (NSUInteger)fetchUnreachableCellCountWithVisibleCellsCount:(NSUInteger)visibleCellsCount {
    if(![self.unreachableCellDict.allKeys containsObject:[NSString stringWithFormat:@"%ld", visibleCellsCount]]){
        return 0;
    }
    return [[self.unreachableCellDict valueForKey:[NSString stringWithFormat:@"%ld", visibleCellsCount]] intValue];
}

/**
 * Because we start to play video on cell only when the tableview was stoped scrolling and the cell stoped on screen center, so always some cells cannot stop in screen center maybe, the cells always is those on top or bottom in tableview.
 * So we need handle this especially. But first we need do is that to check the situation of this type cell appear.
 * Here is the result of my measure on iPhone 6s(CH).
 * The number of visible cells in screen:              4  3  2
 * The number of cells cannot stop in screen center:    1  1  0
 * Tip : you need to know that the mean of result, For example, when we got 4 cells in screen, this time mean that we find 1 cell of cannot stop in screen center on top, and we got the cell of cannot stop in screen center on bottom at the same time.
 * Watch out : the cell of cannot stop in screen center only appear when the number of visiable cell is greater than 3.
 */
- (NSDictionary<NSNumber *, NSNumber *> *)unreachableCellDict {
    if(!_unreachableCellDict){
        // The key is the number of visible cells in screen,
        // the value is the number of cells cannot stop in screen center.
        _unreachableCellDict = @{
                @"4" : @"1",
                @"3" : @"1",
                @"2" : @"0"
        };
    }
    return _unreachableCellDict;
}

- (void)playVideoWithCell:(UITableViewCell *)cell {
    self.playingVideoCell = cell;
    [cell.jp_videoPlayView jp_playVideoWithURL:cell.jp_videoURL controlView:nil];
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
    UITableViewCell *bestCell = [self findTheBestPlayVideoCell];
    if(!bestCell){
        return;
    }

    // If the found cell is the cell playing video, this situation cannot play video again.
    if(bestCell == self.playingVideoCell){
        return;
    }

    [self.playingVideoCell.jp_videoPlayView jp_stopPlay];
    [bestCell.jp_videoPlayView jp_playVideoWithURL:bestCell.jp_videoURL controlView:nil];
    self.playingVideoCell = bestCell;
}

- (BOOL)scrollViewIsCollectionView:(UIScrollView *)scrollView {
    if(![self scrollViewIsTableViewOrCollectionView:scrollView]){
        return NO;
    }
    if([scrollView isKindOfClass:[UICollectionView class]]){
        return YES;
    }
    return NO;
}

- (BOOL)scrollViewIsTableView:(UIScrollView *)scrollView {
    if(![self scrollViewIsTableViewOrCollectionView:scrollView]){
        return NO;
    }
    if([scrollView isKindOfClass:[UITableView class]]){
        return YES;
    }
    return NO;
}

- (BOOL)scrollViewIsTableViewOrCollectionView:(UIScrollView *)scrollView {
    if([scrollView isKindOfClass:[UITableView class]]){
        return YES;
    }
    if([scrollView isKindOfClass:[UICollectionView class]]){
        return YES;
    }
    return NO;
}

@end