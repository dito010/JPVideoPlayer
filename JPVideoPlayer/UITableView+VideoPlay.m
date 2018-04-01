//
// Created by NewPan on 2018/3/30.
// Copyright (c) 2018 NewPan. All rights reserved.
//

#import "UITableView+VideoPlay.h"
#import "JPVideoPlayerCompat.h"
#import "JPVideoPlayerTableViewHelper.h"

@interface UITableView()

@property (nonatomic) JPVideoPlayerTableViewHelper *helper;

@end

static const NSString *kJPVideoPlayerScrollViewHelperKey = @"com.jpvideoplayer.scrollview.helper.www";
@implementation UITableView (VideoPlay)

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

- (void)setJp_unreachableCellDictionary:(NSDictionary<NSString *, NSString *> *)jp_unreachableCellDictionary {
    self.helper.unreachableCellDictionary = jp_unreachableCellDictionary;
}

- (NSDictionary<NSString *, NSString *> *)jp_unreachableCellDictionary {
    return self.helper.unreachableCellDictionary;
}

- (void)jp_handleCellUnreachableTypeForCell:(UITableViewCell *)cell
                                atIndexPath:(NSIndexPath *)indexPath {
    [self.helper handleCellUnreachableTypeForCell:cell
                                      atIndexPath:indexPath];
}

- (void)jp_scrollViewDidEndDragging:(UIScrollView *)scrollView
                     willDecelerate:(BOOL)decelerate {
    [self.helper scrollViewDidEndDragging:scrollView
                           willDecelerate:decelerate];
}

- (void)jp_scrollViewDidEndDecelerating:(UIScrollView *)scrollView {
    [self.helper scrollViewDidEndDecelerating:scrollView];
}

- (void)jp_scrollViewDidScroll:(UIScrollView *)scrollView {
    [self.helper scrollViewDidScroll:scrollView];
}

- (void)jp_playVideoInVisibleCellsIfNeed {
    [self.helper playVideoInVisibleCellsIfNeed];
}

- (void)jp_stopPlayIfNeed {
    [self.helper stopPlayIfNeed];
}


#pragma mark - Private

- (JPVideoPlayerTableViewHelper *)helper {
    JPVideoPlayerTableViewHelper *_helper = objc_getAssociatedObject(self, &kJPVideoPlayerScrollViewHelperKey);
    if(!_helper){
        _helper = [[JPVideoPlayerTableViewHelper alloc] initWithScrollView:self];
        objc_setAssociatedObject(self, &kJPVideoPlayerScrollViewHelperKey, _helper, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    return _helper;
}

@end