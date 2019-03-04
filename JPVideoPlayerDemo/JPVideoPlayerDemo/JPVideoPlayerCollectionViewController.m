//
//  JPVideoPlayerCollectionViewController.m
//  ComponentDemo
//
//  Created by Xuzixiang on 2018/6/4.
//  Copyright © 2018年 frankxzx. All rights reserved.
//

#import "JPVideoPlayerCollectionViewController.h"
#import "JPVideoPlayerKit.h"
#import "JPVideoPlayerCollectionViewCell.h"
#import "JPVideoPlayerDetailViewController.h"

@interface JPVideoPlayerCollectionViewController () <UICollectionViewDelegate, UICollectionViewDataSource, JPScrollViewPlayVideoDelegate>

@property(nonatomic, strong, nonnull)NSArray *pathStrings;

@property(nonatomic, strong) UICollectionView *collectionView;

@end

@implementation JPVideoPlayerCollectionViewController

- (void)dealloc {
    if (self.collectionView.jp_playingVideoCell) {
        [self.collectionView.jp_playingVideoCell.jp_videoPlayView jp_stopPlay];
    }
}

- (void)viewDidLoad {
    [super viewDidLoad];

    [self setup];
}

- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];

    self.collectionView.frame = self.view.bounds;

    CGRect scrollViewVisibleFrame = self.collectionView.frame;
    scrollViewVisibleFrame.origin.x = 0.f;
    scrollViewVisibleFrame.origin.y = 0.f;
    scrollViewVisibleFrame.size.height -= self.tabBarController.tabBar.bounds.size.height;
    self.collectionView.jp_scrollViewVisibleFrame = scrollViewVisibleFrame;
}

- (void)viewDidAppear:(BOOL)animated{
    [super viewDidAppear:animated];

    [self.collectionView jp_handleCellUnreachableTypeInVisibleCellsAfterReloadData];
    [self.collectionView jp_playVideoInVisibleCellsIfNeed];

    // 用来防止选中 cell push 到下个控制器时, scrollView 再次调用 scrollViewDidScroll 方法, 造成 playingVideoCell 被置空.
    self.collectionView.delegate = self;
}

- (void)viewWillDisappear:(BOOL)animated{
    [super viewWillDisappear:animated];

    // 用来防止选中 cell push 到下个控制器时, scrollView 再次调用 scrollViewDidScroll 方法, 造成 playingVideoCell 被置空.
    self.collectionView.delegate = nil;
}


#pragma mark - UICollectionViewDataSource

- (NSInteger)collectionView:(UICollectionView *)collectionView
     numberOfItemsInSection:(NSInteger)section {
    return self.pathStrings.count;
}

- (__kindof UICollectionViewCell *)collectionView:(UICollectionView *)collectionView
                           cellForItemAtIndexPath:(NSIndexPath *)indexPath {
    NSString *reuseIdentifier = NSStringFromClass([JPVideoPlayerCollectionViewCell class]);
    JPVideoPlayerCollectionViewCell *cell = [collectionView dequeueReusableCellWithReuseIdentifier:reuseIdentifier
            forIndexPath:indexPath];
    cell.indexPath = indexPath;
    cell.jp_videoURL = [NSURL URLWithString:self.pathStrings[indexPath.row]];
    cell.jp_videoPlayView = cell.videoPlayerView;
    [collectionView jp_handleCellUnreachableTypeForCell:cell
                                       atIndexPath:indexPath];
    return cell;
}

- (void)collectionView:(UICollectionView *)collectionView didSelectItemAtIndexPath:(NSIndexPath *)indexPath {
    JPVideoPlayerDetailViewController *single = [JPVideoPlayerDetailViewController new];
    single.hidesBottomBarWhenPushed = YES;
    [self.navigationController pushViewController:single animated:YES];
    JPVideoPlayerCollectionViewCell *cell = (JPVideoPlayerCollectionViewCell *)[collectionView cellForItemAtIndexPath:indexPath];
    single.videoPath = cell.jp_videoURL.absoluteString;
}

/**
 * Called on finger up if the user dragged. decelerate is true if it will continue moving afterwards
 * 松手时已经静止, 只会调用scrollViewDidEndDragging
 */
- (void)scrollViewDidEndDragging:(UIScrollView *)scrollView willDecelerate:(BOOL)decelerate {
    [self.collectionView jp_scrollViewDidEndDraggingWillDecelerate:decelerate];
}

/**
 * Called on collectionView is static after finger up if the user dragged and collectionView is scrolling.
 * 松手时还在运动, 先调用scrollViewDidEndDragging, 再调用scrollViewDidEndDecelerating
 */
- (void)scrollViewDidEndDecelerating:(UIScrollView *)scrollView{
    [self.collectionView jp_scrollViewDidEndDecelerating];
}

- (void)scrollViewDidScroll:(UIScrollView *)scrollView{
    [self.collectionView jp_scrollViewDidScroll];
}


#pragma mark - JPScrollViewPlayVideoDelegate

- (void)scrollView:(UIScrollView<JPVideoPlayerScrollViewProtocol> *)scrollView
willPlayVideoOnCell:(UIView<JPVideoPlayerCellProtocol>  *)cell {
    [cell.jp_videoPlayView jp_resumeMutePlayWithURL:cell.jp_videoURL
                                 bufferingIndicator:nil
                                       progressView:nil
                                      configuration:nil];
}


#pragma mark - Setup

- (void)setup{
    self.title = @"CollectionView";
    self.collectionView = ({
        UICollectionViewFlowLayout *layout = [UICollectionViewFlowLayout new];
        CGSize screenSize = [UIScreen mainScreen].bounds.size;
        layout.itemSize = CGSizeMake(screenSize.width, screenSize.width * 9.f / 16.f);
        UICollectionView *collectionView = [[UICollectionView alloc] initWithFrame:CGRectZero collectionViewLayout:layout];
        collectionView.backgroundColor = [UIColor whiteColor];
        [self.view addSubview:collectionView];
        collectionView.dataSource = self;
        collectionView.delegate = self;
        [collectionView registerClass:[JPVideoPlayerCollectionViewCell class] forCellWithReuseIdentifier:NSStringFromClass([JPVideoPlayerCollectionViewCell class])];
        collectionView.jp_delegate = self;
        collectionView.jp_scrollPlayStrategyType = JPScrollPlayStrategyTypeBestVideoView;
        collectionView.jp_debugScrollViewVisibleFrame = YES;

        collectionView;
    });


    // location file in disk.
    // 本地视频播放.
    NSString *locVideoPath = [[NSBundle mainBundle]pathForResource:@"designedByAppleInCalifornia" ofType:@"mp4"];
    NSURL *url = [NSURL fileURLWithPath:locVideoPath];
    self.pathStrings = @[
            url.absoluteString,
            @"http://www.w3school.com.cn/example/html5/mov_bbb.mp4",
            @"http://clips.vorwaerts-gmbh.de/big_buck_bunny.mp4",
            @"https://media.w3.org/2010/05/sintel/trailer.mp4",
            @"http://mvvideo2.meitudata.com/576bc2fc91ef22121.mp4",
            @"http://mvvideo10.meitudata.com/5a92ee2fa975d9739_H264_3.mp4",
            @"http://mvvideo11.meitudata.com/5a44d13c362a23002_H264_11_5.mp4",
            @"http://mvvideo10.meitudata.com/572ff691113842657.mp4",
            @"https://api.tuwan.com/apps/Video/play?key=aHR0cHM6Ly92LnFxLmNvbS9pZnJhbWUvcGxheWVyLmh0bWw%2FdmlkPXUwNjk3MmtqNWV6JnRpbnk9MCZhdXRvPTA%3D&aid=381374",
            @"https://api.tuwan.com/apps/Video/play?key=aHR0cHM6Ly92LnFxLmNvbS9pZnJhbWUvcGxheWVyLmh0bWw%2FdmlkPWswNjk2enBud2xvJnRpbnk9MCZhdXRvPTA%3D&aid=381395",
    ];
}


@end
