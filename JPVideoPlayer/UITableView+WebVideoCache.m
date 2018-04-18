/*
 * This file is part of the JPVideoPlayer package.
 * (c) NewPan <13246884282@163.com>
 *
 * For the full copyright and license information, please view the LICENSE
 * file that was distributed with this source code.
 *
 * Click https://github.com/newyjp
 * or http://www.jianshu.com/users/e2f2d779c022/latest_articles to contact me.
 */

#import "UITableView+WebVideoCache.h"
#import "JPVideoPlayerCompat.h"
#import "JPVideoPlayerSupportUtils.h"

@interface UITableView()

@property (nonatomic) JPVideoPlayerTableViewHelper *helper;

@end

static const NSString *kJPVideoPlayerScrollViewHelperKey = @"com.jpvideoplayer.scrollview.helper.www";
@implementation UITableView (WebVideoCache)

- (void)setJp_delegate:(id <JPTableViewPlayVideoDelegate>)jp_delegate {
    self.helper.delegate = jp_delegate;
}

- (id <JPTableViewPlayVideoDelegate>)jp_delegate {
    return self.helper.delegate;
}

- (UITableViewCell *)jp_playingVideoCell {
    return [self.helper playingVideoCell];
}

- (void)setJp_tableViewVisibleFrame:(CGRect)jp_tableViewVisibleFrame {
    self.helper.tableViewVisibleFrame = jp_tableViewVisibleFrame;
}

- (CGRect)jp_tableViewVisibleFrame {
    return self.helper.tableViewVisibleFrame;
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

- (void)jp_handleCellUnreachableTypeForCell:(UITableViewCell *)cell
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

- (JPVideoPlayerTableViewHelper *)helper {
    JPVideoPlayerTableViewHelper *_helper = objc_getAssociatedObject(self, &kJPVideoPlayerScrollViewHelperKey);
    if(!_helper){
        _helper = [[JPVideoPlayerTableViewHelper alloc] initWithTableView:self];
        objc_setAssociatedObject(self, &kJPVideoPlayerScrollViewHelperKey, _helper, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    return _helper;
}

@end