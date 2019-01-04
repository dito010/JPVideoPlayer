//
//  UICollectionView+videoPlayer.h
//  ComponentDemo
//
//  Created by Xuzixiang on 2018/7/5.
//  Copyright © 2018年 frankxzx. All rights reserved.
//

#import "UITableView+WebVideoCache.h"
#import "JPVideoPlayerCollectionViewHelper.h"

@protocol JPCollectionViewPlayVideoDelegate;

@interface UICollectionView (videoPlayer)

@property (nonatomic) id<JPCollectionViewPlayVideoDelegate> jp_delegate;

/**
 * The cell is playing video.
 */
@property(nonatomic, readonly, nullable) UICollectionViewCell *jp_playingVideoCell;

/**
 * The visible frame of tableView. `visible` mean when the tableView frame is {0, 0, screenWidth, screenHeight},
 * but tableView is wrapped by `UITabBarController` and `UINavigationController`, `UINavigationBar` and `UITabBar`
 * is visible, so the visible frame of tableView is {0, navigationBarHeight, screenWidth, screenHeight - navigationBarHeight - tabBarHeight}.
 * {0, navigationBarHeight, screenWidth, screenHeight - navigationBarHeight} if `UITabBar` is hidden.
 *
 * @warning This value must be not empty.
 */
@property (nonatomic) CGRect jp_collectionViewVisibleFrame;

/**
 * The play cell strategy when tableView stop scroll, `JPScrollFindStrategyBestCell` by default.
 *
 * @see `JPScrollFindStrategy`.
 *
 *
 *    ****************************** center of `jp_tableViewVisibleFrame`
 *              |h2   |h1
 *    ----------|-----|-------------
 *    |         |     |            |
 *    |  cell   |     |            |
 *    |         |     |            |
 *    | --------|-----|---         |
 *    | |videoView    |  |         |
 *    | |       |     * <- cell center
 *    | |       * <- videoView center
 *    | |                |         |
 *    | |                |         |
 *    | ------------------         |
 *    |                            |
 *    ------------------------------
 */
@property (nonatomic) JPScrollPlayStrategyType jp_scrollPlayStrategyType;

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
@property (nonatomic) NSDictionary<NSString *, NSString *> *jp_unreachableCellDictionary;

/**
 * Use this block to custom choosing cell process when call `jp_playVideoInVisibleCellsIfNeed`.
 */
@property(nonatomic) JPPlayVideoInVisibleCollectionCellsBlock jp_playVideoInVisibleCellsBlock;

/**
 * Use this block to custom finding the best cell process when scrollView did stop scroll.
 */
@property(nonatomic) JPPlayVideoInVisibleCollectionCellsBlock jp_findBestCellInVisibleCellsBlock;

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
 * This method must be call after called `reloadData` for tableView.
 */
- (void)jp_handleCellUnreachableTypeInVisibleCellsAfterReloadData;

/**
 * This method must be called in `-tableView:cellForRowAtIndexPath:`, and pass cell and indexPath in.
 *
 * @param cell      A `UICollectionViewCell`.
 * @param indexPath The indexPath of cell.
 *
 * @warning This method must be call in given method.
 */
- (void)jp_handleCellUnreachableTypeForCell:(UICollectionViewCell *)cell
                                atIndexPath:(NSIndexPath *)indexPath;

/**
 * This method must be call in `-scrollViewDidScroll:` method.
 *
 * * @warning This method must be call in given method.
 */
- (void)jp_scrollViewDidScroll;

/**
 * This method must be call in `scrollViewDidEndDragging:willDecelerate:`.
 *
 * @param decelerate The tableView will decelerate or not.
 *
 * @warning This method must be call in given method.
 */
- (void)jp_scrollViewDidEndDraggingWillDecelerate:(BOOL)decelerate;

/**
 * This method must be call in `scrollViewDidEndDecelerating:`.
 *
 * @warning This method must be call in given method.
 */
- (void)jp_scrollViewDidEndDecelerating;

/**
 * You can use this method to judge a view is visible or not when scrollView did scroll.
 *
 * @param view The target view, the view must be a subview on this tableView.
 *
 * @return The result.
 */
- (BOOL)jp_viewIsVisibleInVisibleFrameAtScrollViewDidScroll:(UIView *)view;

@end
