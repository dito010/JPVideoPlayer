//
//  QSFeedVideoSectionController.m
//  QS
//
//  Created by Xuzixiang on 2018/6/29.
//  Copyright © 2018年 frankxzx. All rights reserved.
//

#import "QSFullScreenVideoController.h"
#import <SDWebImage/UIImageView+WebCache.h>

#import "QSFeedVideoCell.h"
#import "QSFeedVideoSectionController.h"

#import "JPVideoPlayerKit.h"

#import "QSFeedListController.h"

@implementation FeedModel

- (BOOL)isEqualToDiffableObject:(nullable id)object
{
    return [self isEqual:object];
}

- (id<NSObject>)diffIdentifier
{
    return self.videoURL;
}

- (nonnull id)copyWithZone:(nullable NSZone *)zone {
    return self;
}

@end

@class AppDelegate;


@interface QSFeedVideoSectionController() <IGListScrollDelegate, JPCollectionViewPlayVideoDelegate>

@property(nonatomic, copy) NSString *videoURL;
@property(nonatomic, copy) NSString *videoThumbnail;;

@end

@implementation QSFeedVideoSectionController

- (instancetype)init
{
    self = [super init];
    if (self) {
        [self setUpVideoPlayer];
    }
    return self;
}

//配置 JPVideoPlayer
-(void)setUpVideoPlayer {
    self.scrollDelegate = self;
    UICollectionView *collectionView = [self collectionView];
    collectionView.jp_delegate = self;
}


- (CGSize)sizeForItemAtIndex:(NSInteger)index {
    CGFloat width = self.collectionContext.containerSize.width;
    CGFloat height = width * (9.0f / 16.0f);
    return CGSizeMake(width, height);
}

-(UICollectionViewCell *)cellForItemAtIndex:(NSInteger)index {
    QSFeedVideoCell *cell = [self.collectionContext dequeueReusableCellOfClass:[QSFeedVideoCell class] forSectionController:self atIndex:index];
    [cell.videoPlayerView sd_setImageWithURL:[NSURL URLWithString:self.videoThumbnail]];
    cell.jp_videoURL = [NSURL URLWithString:self.videoURL];
    cell.jp_videoPlayView = cell.videoPlayerView;
    UICollectionView *collectionView = [self collectionView];
    NSIndexPath *cellInexPath = [collectionView indexPathForCell:cell];
    [collectionView jp_handleCellUnreachableTypeForCell:cell atIndexPath:cellInexPath];
    return cell;
}

-(void)didUpdateToObject:(FeedModel *)object {
    self.videoURL = object.videoURL;
    self.videoThumbnail = object.videoThumbnail;
}

-(void)didSelectItemAtIndex:(NSInteger)index {
    QSFeedVideoCell *cell = [self.collectionContext cellForItemAtIndex:index sectionController:self];
    QSFullScreenVideoController *player = [QSFullScreenVideoController new];
    player.videoURL = cell.jp_videoURL;
    [player display];
}

#pragma mark - private methods

-(UICollectionView *)collectionView {
    UICollectionView *collectionView = ((QSFeedListController *)self.viewController).listView;
    return collectionView;
}

#pragma mark - IGListScrollDelegate

- (void)listAdapter:(nonnull IGListAdapter *)listAdapter didEndDraggingSectionController:(nonnull IGListSectionController *)sectionController willDecelerate:(BOOL)decelerate {
    UICollectionView *collectionView = [self collectionView];
    [collectionView jp_scrollViewDidEndDraggingWillDecelerate:decelerate];
}

- (void)listAdapter:(nonnull IGListAdapter *)listAdapter didScrollSectionController:(nonnull IGListSectionController *)sectionController {
    UICollectionView *collectionView = [self collectionView];
    [collectionView jp_scrollViewDidScroll];
}

- (void)listAdapter:(nonnull IGListAdapter *)listAdapter willBeginDraggingSectionController:(nonnull IGListSectionController *)sectionController {
    
}

#pragma mark - JPCollectionViewPlayVideoDelegate
- (void)collectionView:(UICollectionView *)collectionView willPlayVideoOnCell:(UICollectionViewCell *)cell {
    [cell.jp_videoPlayView jp_resumeMutePlayWithURL:cell.jp_videoURL
                                 bufferingIndicator:nil
                                       progressView:nil
                                      configuration:nil];
}

@end
