//
//  UITableView+VideoPlay.m
//  JPVideoPlayerDemo
//
//  Created by lava on 2017/3/20.
//  Copyright © 2017年 NewPan. All rights reserved.
//

#import "UITableView+VideoPlay.h"
#import "JPVideoPlayerDemoCell.h"
#import <objc/runtime.h>
#import "UIView+WebVideoCache.h"


CGFloat const JPVideoPlayerDemoNavAndStatusTotalHei = 64;
CGFloat const JPVideoPlayerDemoTabbarHei = 49;
@implementation UITableView (VideoPlay)

-(void)playVideoInVisiableCells{
    
    NSArray *visiableCells = [self visibleCells];
    
    // Find first cell need play video in visiable cells.
    // 在可见cell中找到第一个有视频的cell
    JPVideoPlayerDemoCell *videoCell = nil;
    
    for (JPVideoPlayerDemoCell *cell in visiableCells) {
        if (cell.videoPath.length > 0) {
            videoCell = cell;
            break;
        }
    }
    
    // If found, play.
    // 如果找到了, 就开始播放视频
    if (videoCell) {
        self.playingCell = videoCell;
        
        // display status view.
        [videoCell.videoImv jp_playVideoWithURL:[NSURL URLWithString:videoCell.videoPath]];
        
        // hide status view.
        // [videoCell.videoImv jp_playVideoMutedWithURL:[NSURL URLWithString:videoCell.videoPath]];
    }
}


#pragma mark --------------------------------------------------
#pragma mark Video Play Events

-(void)handleScrollStop{
    JPVideoPlayerDemoCell *bestCell = [self findTheBestToPlayVideoCell];
    
    // If the found cell is the cell playing video, this situation cannot play video again.
    // 注意, 如果正在播放的 cell 和 finnalCell 是同一个 cell, 不应该在播放.
    if (self.playingCell.hash != bestCell.hash && bestCell.hash != 0) {
        
        [self.playingCell.videoImv jp_stopPlay];
        
        NSURL *url = [NSURL URLWithString:bestCell.videoPath];
        
        // display status view.
        // [bestCell.videoImv jp_playVideoDisplayStatusViewWithURL:url];
        
        // hide status view.
         [bestCell.videoImv jp_playVideoWithURL:url];
        
        self.playingCell = bestCell;
    }
}

-(void)handleQuickScroll{
    
    if (!self.playingCell) return;
    
    // Stop play when the cell playing video is unvisiable.
    // 当前播放视频的cell移出视线，要移除播放器.
    if (![self playingCellIsVisiable]) {
        [self stopPlay];
    }
}

-(void)stopPlay{
    [self.playingCell.videoImv jp_stopPlay];
    self.playingCell = nil;
}


#pragma mark --------------------------------------------------
#pragma mark Private

-(JPVideoPlayerDemoCell *)findTheBestToPlayVideoCell{
    
    // To find next cell need play video.
    // 找到下一个要播放的cell(最在屏幕中心的).
    
    JPVideoPlayerDemoCell *finnalCell = nil;
    NSArray *visiableCells = [self visibleCells];
    CGFloat gap = MAXFLOAT;
    
    CGRect windowRect = [UIScreen mainScreen].bounds;
    windowRect.origin.y = JPVideoPlayerDemoNavAndStatusTotalHei;
    windowRect.size.height -= (JPVideoPlayerDemoNavAndStatusTotalHei + JPVideoPlayerDemoTabbarHei);
    
    for (JPVideoPlayerDemoCell *cell in visiableCells) {
        
        @autoreleasepool {
            
            if (cell.videoPath.length > 0) { // If need to play video, 如果这个cell有视频
                
                // Find the cell cannot stop in screen center first.
                // 优先查找滑动不可及cell.
                if (cell.cellStyle != JPPlayUnreachCellStyleNone) {
                    
                    // Must the all area of the cell is visiable.
                    // 并且不可及cell要全部露出.
                    if (cell.cellStyle == JPPlayUnreachCellStyleUp) {
                        CGPoint cellLeftUpPoint = cell.frame.origin;
                        
                        // 不要在边界上.
                        cellLeftUpPoint.y += 2;
                        CGPoint coorPoint = [cell.superview convertPoint:cellLeftUpPoint toView:nil];
                        BOOL isContain = CGRectContainsPoint(windowRect, coorPoint);
                        if (isContain){
                            finnalCell = cell;
                            break;
                        }
                    }
                    else if (cell.cellStyle == JPPlayUnreachCellStyleDown){
                        CGPoint cellLeftUpPoint = cell.frame.origin;
                        CGFloat cellDownY = cellLeftUpPoint.y + cell.bounds.size.height;
                        CGPoint cellLeftDownPoint = CGPointMake(cellLeftUpPoint.x, cellDownY);
                        
                        // 不要在边界上.
                        cellLeftDownPoint.y -= 1;
                        CGPoint coorPoint = [cell.superview convertPoint:cellLeftDownPoint toView:nil];
                        BOOL isContain = CGRectContainsPoint(windowRect, coorPoint);
                        if (isContain){
                            finnalCell = cell;
                            break;
                        }
                    }
                    
                }
                else{
                    CGPoint coorCentre = [cell.superview convertPoint:cell.center toView:nil];
                    CGFloat delta = fabs(coorCentre.y-JPVideoPlayerDemoNavAndStatusTotalHei-windowRect.size.height*0.5);
                    if (delta < gap) {
                        gap = delta;
                        finnalCell = cell;
                    }
                }
            }
        }
    }
    
    return finnalCell;
}

-(BOOL)playingCellIsVisiable{
    CGRect windowRect = [UIScreen mainScreen].bounds;
    // because have UINavigationBar here.
    windowRect.origin.y = JPVideoPlayerDemoNavAndStatusTotalHei;
    windowRect.size.height -= JPVideoPlayerDemoNavAndStatusTotalHei;
    
    if (self.currentDerection==JPVideoPlayerDemoScrollDerectionUp) { // 向上滚动
        CGPoint cellLeftUpPoint = self.playingCell.frame.origin;
        CGFloat cellDownY = cellLeftUpPoint.y + self.playingCell.bounds.size.height;
        CGPoint cellLeftDownPoint = CGPointMake(cellLeftUpPoint.x, cellDownY);
        
        // 不要在边界上.
        cellLeftUpPoint.y -= 1;
        CGPoint coorPoint = [self.playingCell.superview convertPoint:cellLeftDownPoint toView:nil];
        BOOL isContain = CGRectContainsPoint(windowRect, coorPoint);
        return isContain;
    }
    else if(self.currentDerection==JPVideoPlayerDemoScrollDerectionDown){ // 向下滚动
        CGPoint cellLeftUpPoint = self.playingCell.frame.origin;
        
        // 不要在边界上.
        cellLeftUpPoint.y += 1;
        CGPoint coorPoint = [self.playingCell.superview convertPoint:cellLeftUpPoint toView:nil];
        
        BOOL isContain = CGRectContainsPoint(windowRect, coorPoint);
        return isContain;
    }
    return YES;
}

-(void)setCurrentDerection:(JPVideoPlayerDemoScrollDerection)currentDerection{
    objc_setAssociatedObject(self, @selector(currentDerection), @(currentDerection), OBJC_ASSOCIATION_ASSIGN);
}

-(JPVideoPlayerDemoScrollDerection)currentDerection{
    return [objc_getAssociatedObject(self, _cmd) integerValue];
}

-(void)setMaxNumCannotPlayVideoCells:(NSUInteger)maxNumCannotPlayVideoCells{
    
}

-(NSUInteger)maxNumCannotPlayVideoCells{
    NSUInteger num = [objc_getAssociatedObject(self, _cmd) integerValue];
    if (num==0) {
        CGFloat radius = [UIScreen mainScreen].bounds.size.height / JPVideoPlayerDemoRowHei;
        NSUInteger maxNumOfVisiableCells = ceil(radius);
        if (maxNumOfVisiableCells >= 3) {
            num =  [[self.dictOfVisiableAndNotPlayCells valueForKey:[NSString stringWithFormat:@"%ld", (unsigned long)maxNumOfVisiableCells]] integerValue];
            objc_setAssociatedObject(self, @selector(maxNumCannotPlayVideoCells), @(num), OBJC_ASSOCIATION_ASSIGN);
        }
    }
    return num;
}

-(void)setPlayingCell:(JPVideoPlayerDemoCell *)playingCell{
    objc_setAssociatedObject(self, @selector(playingCell), playingCell, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

-(JPVideoPlayerDemoCell *)playingCell{
    return objc_getAssociatedObject(self, _cmd);
}

-(void)setDictOfVisiableAndNotPlayCells:(NSDictionary *)dictOfVisiableAndNotPlayCells{
    
}

/**
 * Because we start to play video on cell only when the tableview was stoped scrolling and the cell stoped on screen center, so always some cells cannot stop in screen center maybe, the cells always is those on top or bottom in tableview.
 * So we need handle this especially. But first we need do is that to check the situation of this type cell appear.
 * Here is the result of my measure on iPhone 6s(CH).
 * The number of visiable cells in screen:              4  3  2
 * The number of cells cannot stop in screen center:    1  1  0
 * Tip : you need to know that the mean of result, For example, when we got 4 cells in screen, this time mean that we find 1 cell of cannot stop in screen center on top, and we got the cell of cannot stop in screen center on bottom at the same time.
 * Watch out : the cell of cannot stop in screen center only appear when the number of visiable cell is greater than 3.
 *
 * 由于我们是在tableView静止的时候播放停在屏幕中心的cell, 所以可能出现总有一些cell无法满足我们的播放条件.
 * 所以我们必须特别处理这种情况, 我们首先要做的就是检查什么样的情况下才会出现这种类型的cell.
 * 下面是我的测量结果(iPhone 6s, iPhone 6 plus).
 * 每屏可见cell个数           4  3  2
 * 滑动不可及的cell个数        1  1  0
 * 注意 : 你需要仔细思考一下我的测量结果, 举个例子, 如果屏幕上有4个cell, 那么这个时候, 我们能够在顶部发现一个滑动不可及cell, 同时, 我们在底部也会发现一个这样的cell.
 * 注意 : 只有每屏可见cell数在3以上时,才会出现滑动不可及cell.
 */
-(NSDictionary *)dictOfVisiableAndNotPlayCells{
    
    // The key is the number of visiable cells in screen, the value is the number of cells cannot stop in screen center.
    // 以每屏可见cell的最大个数为key, 对应的滑动不可及cell数为value
    
    NSDictionary *dict = objc_getAssociatedObject(self, _cmd);
    if (!dict) {
        dict = @{
                 @"4" : @"1",
                 @"3" : @"1",
                 @"2" : @"0"
                 };
        objc_setAssociatedObject(self, @selector(setDictOfVisiableAndNotPlayCells:), dict, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    return dict;
}

@end
