//
// Created by NewPan on 2018/3/30.
// Copyright (c) 2018 NewPan. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "UITableViewCell+VideoPlay.h"

NS_ASSUME_NONNULL_BEGIN

@protocol JPTableViewPlayVideoDelegate<NSObject>

@optional

/**
 * This method will be call when call `jp_playVideoInVisibleCellsIfNeed` and the find the best cell to play video when tableView scroll end.
 *
 * @param tableView The tableView.
 * @param cell      The cell ready to play video, you can call `[cell.jp_videoPlayView jp_playVideoMuteWithURL:cell.jp_videoURL progressView:nil]` or other method given to play video.
 */
- (void)tableView:(UITableView *)tableView readyPlayVideoOnCell:(UITableViewCell *)cell;

@end

@interface UITableView (VideoPlay)

@property (nonatomic) id<JPTableViewPlayVideoDelegate> jp_delegate;

/**
 * The cell is playing video.
 */
@property(nonatomic, readonly, nullable) UITableViewCell *jp_playingVideoCell;

/**
 * The visible frame of tableView. `visible` mean when the tableView frame is {0, 0, screenWidth, screenHeight},
 * but tableView is wrapped by `UITabBarController` and `UINavigationController`, `UINavigationBar` and `UITabBar`
 * is visible, so the visible frame of tableView is {0, navigationBarHeight, screenWidth, screenHeight - navigationBarHeight - tabBarHeight}.
 * {0, navigationBarHeight, screenWidth, screenHeight - navigationBarHeight} if `UITabBar` is hidden.
 *
 * @warning This value must be not empty.
 */
@property(nonatomic) CGRect jp_tableViewVisibleFrame;

/**
 * Because we play video on cell that stopped on screen center when the tableView was stopped scrolling,
 * so some cell may can not stop in screen center, this type cell always is on top or bottom in tableView, we call this type cell `unreachableCell`.
 * so we need handle this especially. but first we need do is to check the situation of this type cell appear.
 *
 * Here is the result of my measure on iPhone 6s(CH).
 * The number of visible cells in screen:              4  3  2
 * The number of cells cannot stop in screen center:   1  1  0
 *
 * The default dictionary content is: @{
 *                                      @"4" : @"1",
 *                                      @"3" : @"1",
 *                                      @"2" : @"0"
 *                                     };
 *
 * @warning you need to know that the mean of result, For example, when we got 4 cells in screen,
 * this time we find 1 cell that can not stop in screen center on top, and we got the same cell that cannot stop in screen center on bottom at the same time.
 * The cell of cannot stop in screen center only appear when the count of visible cells is greater than 3.
 *
 * @note You can custom this dictionary.
 */
@property (nonatomic, strong) NSDictionary<NSString *, NSString *> *jp_unreachableCellDictionary;

/**
 * This method be used to find the first cell need to play video in visible cells.
 * This method should be call after tableView is finished `-reloadData`.
 * Suggest call this method in `-viewDidAppear:` method.
 */
- (void)jp_playVideoInVisibleCellsIfNeed;

/**
 * Call this method to stop video play.
 */
- (void)jp_stopPlayIfNeed;

/**
 * This method must be call in `-tableView:cellForRowAtIndexPath:`, and pass cell and indexPath in.
 *
 * @param cell      A `UITableViewCell`.
 * @param indexPath The indexPath of cell.
 *
 * @warning This method must be call in given method.
 */
- (void)jp_handleCellUnreachableTypeForCell:(UITableViewCell *)cell
                                atIndexPath:(NSIndexPath *)indexPath;

/**
 * This method must be call in `-scrollViewDidScroll:` method.
 *
 * @param scrollView The tableView.
 *
 * * @warning This method must be call in given method.
 */
- (void)jp_scrollViewDidScroll:(UIScrollView *)scrollView;

/**
 * This method must be call in `scrollViewDidEndDragging:willDecelerate:`.
 *
 * @param scrollView The tableView.
 * @param decelerate The tableView will decelerate or not.
 *
 * @warning This method must be call in given method.
 */
- (void)jp_scrollViewDidEndDragging:(UIScrollView *)scrollView
                     willDecelerate:(BOOL)decelerate;

/**
 * This method must be call in `scrollViewDidEndDecelerating:`.
 *
 * @param scrollView The tableView.
 *
 * @warning This method must be call in given method.
 */
- (void)jp_scrollViewDidEndDecelerating:(UIScrollView *)scrollView;

@end

NS_ASSUME_NONNULL_END