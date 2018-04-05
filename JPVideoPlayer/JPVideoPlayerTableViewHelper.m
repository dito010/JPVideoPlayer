//
// Created by NewPan on 2018/3/30.
// Copyright (c) 2018 NewPan. All rights reserved.
//

#import "JPVideoPlayerTableViewHelper.h"
#import "UITableViewCell+VideoPlay.h"
#import "UIView+WebVideoCache.h"
#import "UITableView+VideoPlay.h"

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

@interface JPVideoPlayerTableViewHelper()

@property (nonatomic, weak) UITableViewCell *playingVideoCell;

@end

@implementation JPVideoPlayerTableViewHelper

- (instancetype)init {
    NSAssert(NO, @"Please use given initialize method.");
    return [self initWithScrollView:[UIScrollView new]];
};

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
    if(![self scrollViewIsTableView:self.scrollView]){
        return;
    }
    UITableView *tableView = (UITableView *)self.scrollView;
    NSParameterAssert(tableView.numberOfSections == 1);
    if(tableView.numberOfSections != 1){
        return;
    }

    NSArray<UITableViewCell *> *visibleCells = [tableView visibleCells];
    if(!visibleCells.count){
        return;
    }

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

    if(![self scrollViewIsTableView:self.scrollView]){
        return;
    }

    // handle the first cell cannot play video when initialized.
    UITableView *tableView = (UITableView *)self.scrollView;
    for(UITableViewCell *cell in tableView.visibleCells){
        [self handleCellUnreachableTypeForCell:cell atIndexPath:[tableView indexPathForCell:cell]];
    }
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
    if(![self scrollViewIsTableView:self.scrollView]){
        return;
    }
    [self.playingVideoCell.jp_videoPlayView jp_stopPlay];
    self.playingVideoCell = nil;
}

- (void)scrollViewDidScroll:(UIScrollView *)scrollView {
    if(![self scrollViewIsTableView:self.scrollView]){
        return;
    }

    [self handleQuickScrollIfNeed];
}

- (void)scrollViewDidEndDragging:(UIScrollView *)scrollView
                  willDecelerate:(BOOL)decelerate {
    if(![self scrollViewIsTableView:scrollView]){
        return;
    }

    if (decelerate == NO) {
        [self handleScrollStopIfNeed];
    }
}

- (void)scrollViewDidEndDecelerating:(UIScrollView *)scrollView {
    if(![self scrollViewIsTableView:scrollView]){
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
    if(![self.unreachableCellDictionary.allKeys containsObject:[NSString stringWithFormat:@"%ld", visibleCellsCount]]){
        return 0;
    }
    return [[self.unreachableCellDictionary valueForKey:[NSString stringWithFormat:@"%ld", visibleCellsCount]] intValue];
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

- (void)playVideoWithCell:(UITableViewCell *)cell {
    NSParameterAssert(cell);
    if(!cell){
        return;
    }

    self.playingVideoCell = cell;
    if (self.delegate && [self.delegate respondsToSelector:@selector(tableView:readyPlayVideoOnCell:)]) {
        [self.delegate tableView:self.scrollView readyPlayVideoOnCell:cell];
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
    UITableViewCell *bestCell = [self findTheBestPlayVideoCell];
    if(!bestCell){
        return;
    }

    // If the found cell is the cell playing video, this situation cannot play video again.
    if(bestCell == self.playingVideoCell){
        return;
    }

    [self.playingVideoCell.jp_videoPlayView jp_stopPlay];
    if (self.delegate && [self.delegate respondsToSelector:@selector(tableView:readyPlayVideoOnCell:)]) {
        [self.delegate tableView:self.scrollView readyPlayVideoOnCell:bestCell];
    }
    self.playingVideoCell = bestCell;
}

- (BOOL)scrollViewIsTableView:(UIScrollView *)scrollView {
    if([scrollView isKindOfClass:[UITableView class]]){
        return YES;
    }
    return NO;
}

@end