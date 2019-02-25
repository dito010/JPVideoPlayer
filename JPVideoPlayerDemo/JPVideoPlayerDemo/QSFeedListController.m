//
//  QSFeedListController.m
//  ComponentDemo
//
//  Created by Xuzixiang on 2018/6/4.
//  Copyright © 2018年 frankxzx. All rights reserved.
//

#import "QSFeedListController.h"
#import "JPVideoPlayerKit.h"
#import "QSFeedVideoSectionController.h"

@interface QSFeedListController () <UICollectionViewDelegate, IGListAdapterDataSource>

@property(nonatomic, strong) IGListCollectionViewLayout *listLayout;
@property(nonatomic, strong) IGListAdapter *adapter;
@property(nonatomic, assign) NSInteger workingRangeSize;
@property(nonatomic, strong) NSMutableArray *feedModels;

@end

@implementation QSFeedListController

- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
    self.listView.frame = self.view.bounds;
    CGRect listViewFrame = self.listView.frame;
    self.listView.jp_scrollViewVisibleFrame = listViewFrame;
}
    
- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    [self.listView jp_handleCellUnreachableTypeInVisibleCellsAfterReloadData];
    [self.listView jp_playVideoInVisibleCellsIfNeed];
}

- (NSArray<id<IGListDiffable>> *)objectsForListAdapter:(IGListAdapter *)listAdapter {
    return self.feedModels;
}
    
-(IGListSectionController *)listAdapter:(IGListAdapter *)listAdapter sectionControllerForObject:(id)object {
    return [[QSFeedVideoSectionController alloc]init];
}

- (nullable UIView *)emptyViewForListAdapter:(nonnull IGListAdapter *)listAdapter {
    return nil;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    [self.view addSubview:self.listView];
    [self.adapter setCollectionView:self.listView];
    self.workingRangeSize = 4;
    self.adapter.scrollViewDelegate = self;
    self.title = @"IGListKit";
    
    NSArray *videoURLs = @[
      @"http://www.w3school.com.cn/example/html5/mov_bbb.mp4",
      @"https://www.w3schools.com/html/movie.mp4",
      @"http://clips.vorwaerts-gmbh.de/big_buck_bunny.mp4",
      @"https://media.w3.org/2010/05/sintel/trailer.mp4",
      @"http://mvvideo2.meitudata.com/576bc2fc91ef22121.mp4",
      @"http://mvvideo10.meitudata.com/5a92ee2fa975d9739_H264_3.mp4",
      @"http://mvvideo11.meitudata.com/5a44d13c362a23002_H264_11_5.mp4",
      @"http://mvvideo10.meitudata.com/572ff691113842657.mp4",
      @"https://api.tuwan.com/apps/Video/play?key=aHR0cHM6Ly92LnFxLmNvbS9pZnJhbWUvcGxheWVyLmh0bWw%2FdmlkPXUwNjk3MmtqNWV6JnRpbnk9MCZhdXRvPTA%3D&aid=381374",
      @"https://api.tuwan.com/apps/Video/play?key=aHR0cHM6Ly92LnFxLmNvbS9pZnJhbWUvcGxheWVyLmh0bWw%2FdmlkPWswNjk2enBud2xvJnRpbnk9MCZhdXRvPTA%3D&aid=381395",
      ];
    
    NSMutableArray *feeds = @[].mutableCopy;
    
    for (NSString *url in videoURLs) {
        FeedModel *mockFeed = [[FeedModel alloc]init];
        mockFeed.videoURL = url;
        mockFeed.videoThumbnail = @"https://raw.githubusercontent.com/newyjp/JPVideoPlayer/master/Images/logo.png";
        mockFeed.photoThumbnail = @"https://raw.githubusercontent.com/newyjp/JPVideoPlayer/master/Images/logo.png";
        [feeds addObject:mockFeed];
    }
    
    self.feedModels = feeds;
    [self.adapter reloadDataWithCompletion:nil];
}

-(IGListCollectionView *)listView {
    if (!_listView) {
        _listView = [[IGListCollectionView alloc]initWithFrame:self.view.bounds
                                      listCollectionViewLayout:self.listLayout];
        _listView.backgroundColor = [UIColor whiteColor];
        _listView.alwaysBounceVertical = YES;
    }
    return _listView;
}

-(IGListCollectionViewLayout *)listLayout {
    if (!_listLayout) {
        _listLayout = [[IGListCollectionViewLayout alloc]initWithStickyHeaders:NO
                                                               scrollDirection:UICollectionViewScrollDirectionVertical
                                                               topContentInset:0
                                                                 stretchToEdge:YES];
    }
    return _listLayout;
}

-(IGListAdapter *)adapter {
    if (!_adapter) {
        _adapter = [[IGListAdapter alloc]initWithUpdater:[self updater]
                                          viewController:self workingRangeSize:self.workingRangeSize];
        _adapter.dataSource = self;
    }
    return _adapter;
}

-(id <IGListUpdatingDelegate>)updater {
    return [[IGListAdapterUpdater alloc]init];
}

@end
