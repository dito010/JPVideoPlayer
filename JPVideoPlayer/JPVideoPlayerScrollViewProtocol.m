//
// Created by NewPan on 2019-02-25.
// Copyright (c) 2019 NewPan. All rights reserved.
//

#import "JPVideoPlayerScrollViewProtocol.h"
#import "JPMethodInjecting.h"
#import "JPVideoPlayerSupportUtils.h"

@jp_concreteprotocol(JPVideoPlayerScrollViewProtocol)

- (void)setJp_delegate:(id <JPScrollViewPlayVideoDelegate>)jp_delegate {
    self.helper.delegate = jp_delegate;
}

- (id <JPScrollViewPlayVideoDelegate>)jp_delegate {
    return self.helper.delegate;
}

- (UITableViewCell *)jp_playingVideoCell {
    return [self.helper playingVideoCell];
}

- (void)setJp_scrollViewVisibleFrame:(CGRect)jp_scrollViewVisibleFrame {
    self.helper.scrollViewVisibleFrame = jp_scrollViewVisibleFrame;
}

- (CGRect)jp_scrollViewVisibleFrame {
    return self.helper.scrollViewVisibleFrame;
}

- (void)setJp_debugScrollViewVisibleFrame:(BOOL)jp_debugScrollViewVisibleFrame {
    self.helper.debugScrollViewVisibleFrame = jp_debugScrollViewVisibleFrame;
}

- (BOOL)jp_debugScrollViewVisibleFrame {
    return self.helper.debugScrollViewVisibleFrame;
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

- (NSDictionary<NSString *, NSNumber *> *)jp_unreachableCellDictionary {
    return self.helper.unreachableCellDictionary;
}

- (void)setJp_playVideoInVisibleCellsBlock:(JPPlayVideoInVisibleCellsBlock)jp_playVideoInVisibleCellsBlock {
    self.helper.playVideoInVisibleCellsBlock = jp_playVideoInVisibleCellsBlock;
}

- (JPPlayVideoInVisibleCellsBlock)jp_playVideoInVisibleCellsBlock {
    return self.helper.playVideoInVisibleCellsBlock;
}

- (void)setJp_findBestCellInVisibleCellsBlock:(JPPlayVideoInVisibleCellsBlock)jp_findBestCellInVisibleCellsBlock {
    self.helper.findBestCellInVisibleCellsBlock = jp_findBestCellInVisibleCellsBlock;
}

- (JPPlayVideoInVisibleCellsBlock)jp_findBestCellInVisibleCellsBlock {
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

- (void)jp_handleCellUnreachableTypeForCell:(UIView<JPVideoPlayerCellProtocol> *)cell
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

- (JPVideoPlayerScrollViewInternalObject *)helper {
    JPVideoPlayerScrollViewInternalObject *_helper = objc_getAssociatedObject(self, _cmd);
    if(!_helper){
        _helper = [[JPVideoPlayerScrollViewInternalObject alloc] initWithScrollView:self];
        objc_setAssociatedObject(self, _cmd, _helper, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    return _helper;
}

@end

