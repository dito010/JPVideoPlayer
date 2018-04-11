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

#import "JPVideoPlayerWeiBoListViewController.h"
#import "UIView+WebVideoCache.h"
#import "JPVideoPlayerWeiBoEqualHeightCell.h"
#import "JPVideoPlayerDetailViewController.h"
#import "UITableView+WebVideoCache.h"
#import "UITableViewCell+WebVideoCache.h"
#import "JPVideoPlayerWeiBoUnequalHeightCell.h"

@interface JPVideoPlayerWeiBoListViewController ()<JPTableViewPlayVideoDelegate>

/**
 * Arrary of video paths.
 * 播放路径数组集合.
 */
@property(nonatomic, strong, nonnull)NSArray *pathStrings;

@end

#define JPVideoPlayerDemoRowHei ([UIScreen mainScreen].bounds.size.width*9.0/16.0)
@implementation JPVideoPlayerWeiBoListViewController

- (void)dealloc {
    if (self.tableView.jp_playingVideoCell) {
        [self.tableView.jp_playingVideoCell.jp_videoPlayView jp_stopPlay];
    }
}

- (instancetype)initWithPlayStrategyType:(JPScrollPlayStrategyType)playStrategyType {
    self = [super init];
    if(self){
       _scrollPlayStrategyType = playStrategyType;
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];

    [self setup];
}

- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];

    CGRect tableViewFrame = self.tableView.frame;
    tableViewFrame.size.height -= self.tabBarController.tabBar.bounds.size.height;
    self.tableView.jp_tableViewVisibleFrame = tableViewFrame;
}

- (void)viewDidAppear:(BOOL)animated{
    [super viewDidAppear:animated];

    [self.tableView jp_handleCellUnreachableTypeInVisibleCellsAfterReloadData];
    [self.tableView jp_playVideoInVisibleCellsIfNeed];

    // 用来防止选中 cell push 到下个控制器时, tableView 再次调用 scrollViewDidScroll 方法, 造成 playingVideoCell 被置空.
    self.tableView.delegate = self;
}

- (void)viewWillDisappear:(BOOL)animated{
    [super viewWillDisappear:animated];

    // 用来防止选中 cell push 到下个控制器时, tableView 再次调用 scrollViewDidScroll 方法, 造成 playingVideoCell 被置空.
    self.tableView.delegate = nil;
}


#pragma mark - Data Srouce

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section{
    tableView.separatorStyle = UITableViewCellSeparatorStyleNone;
    return self.pathStrings.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath{
    NSString *reuseIdentifier = indexPath.row % 2 == 0 ? NSStringFromClass([JPVideoPlayerWeiBoEqualHeightCell class]) :
            NSStringFromClass([JPVideoPlayerWeiBoUnequalHeightCell class]);
    if(self.scrollPlayStrategyType == JPScrollPlayStrategyTypeBestCell){
       reuseIdentifier = NSStringFromClass([JPVideoPlayerWeiBoEqualHeightCell class]);
    }
    JPVideoPlayerWeiBoEqualHeightCell *cell = [tableView dequeueReusableCellWithIdentifier:reuseIdentifier forIndexPath:indexPath];
    cell.indexPath = indexPath;
    cell.selectionStyle = UITableViewCellSelectionStyleNone;
    cell.jp_videoURL = [NSURL URLWithString:self.pathStrings[indexPath.row]];
    cell.jp_videoPlayView = cell.videoPlayView;
    [tableView jp_handleCellUnreachableTypeForCell:cell
                                       atIndexPath:indexPath];
    return cell;
}


#pragma mark - TableView Delegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath{
    JPVideoPlayerDetailViewController *single = [JPVideoPlayerDetailViewController new];
    single.hidesBottomBarWhenPushed = YES;
    [self.navigationController pushViewController:single animated:YES];
    JPVideoPlayerWeiBoEqualHeightCell *cell = [tableView cellForRowAtIndexPath:indexPath];
    single.videoPath = cell.jp_videoURL.absoluteString;
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath{
    if(self.scrollPlayStrategyType == JPScrollPlayStrategyTypeBestCell){
        return JPVideoPlayerDemoRowHei;
    }
    return indexPath.row % 2 == 0 ? JPVideoPlayerDemoRowHei : (JPVideoPlayerDemoRowHei + 160);
}

/**
 * Called on finger up if the user dragged. decelerate is true if it will continue moving afterwards
 * 松手时已经静止, 只会调用scrollViewDidEndDragging
 */
- (void)scrollViewDidEndDragging:(UIScrollView *)scrollView willDecelerate:(BOOL)decelerate {
    [self.tableView jp_scrollViewDidEndDraggingWillDecelerate:decelerate];
}

/**
 * Called on tableView is static after finger up if the user dragged and tableView is scrolling.
 * 松手时还在运动, 先调用scrollViewDidEndDragging, 再调用scrollViewDidEndDecelerating
 */
- (void)scrollViewDidEndDecelerating:(UIScrollView *)scrollView{
    [self.tableView jp_scrollViewDidEndDecelerating];
}

- (void)scrollViewDidScroll:(UIScrollView *)scrollView{
    [self.tableView jp_scrollViewDidScroll];
}


#pragma mark - JPTableViewPlayVideoDelegate

- (void)tableView:(UITableView *)tableView willPlayVideoOnCell:(UITableViewCell *)cell {
    [cell.jp_videoPlayView jp_resumeMutePlayWithURL:cell.jp_videoURL
                                 bufferingIndicator:nil
                                       progressView:nil
                            configurationCompletion:nil];
}


#pragma mark - Setup

- (void)setup{
    self.title = @"微博";
    [self.tableView registerNib:[UINib nibWithNibName:NSStringFromClass([JPVideoPlayerWeiBoEqualHeightCell class]) bundle:nil]
         forCellReuseIdentifier:NSStringFromClass([JPVideoPlayerWeiBoEqualHeightCell class])];
    [self.tableView registerNib:[UINib nibWithNibName:NSStringFromClass([JPVideoPlayerWeiBoUnequalHeightCell class]) bundle:nil]
         forCellReuseIdentifier:NSStringFromClass([JPVideoPlayerWeiBoUnequalHeightCell class])];

    self.tableView.jp_delegate = self;
    self.tableView.jp_scrollPlayStrategyType = self.scrollPlayStrategyType;

    // location file in disk.
    // 本地视频播放.
    NSString *locVideoPath = [[NSBundle mainBundle]pathForResource:@"designedByAppleInCalifornia" ofType:@"mp4"];
    NSURL *url = [NSURL fileURLWithPath:locVideoPath];
    self.pathStrings = @[
            url.absoluteString,
            @"http://p11s9kqxf.bkt.clouddn.com/iPhone.mp4",
            @"http://p11s9kqxf.bkt.clouddn.com/faceid.mp4",
            @"http://p11s9kqxf.bkt.clouddn.com/lavameface.mp4",
            @"http://p11s9kqxf.bkt.clouddn.com/screen.mp4",
            @"http://p11s9kqxf.bkt.clouddn.com/lavame.mp4",
            @"http://p11s9kqxf.bkt.clouddn.com/iPhoneX.mp4",
            @"http://p11s9kqxf.bkt.clouddn.com/kingOfGlory.mp4",
            @"http://p11s9kqxf.bkt.clouddn.com/worldStart.mp4",
            @"http://p11s9kqxf.bkt.clouddn.com/wechat.mp4",
            @"http://p11s9kqxf.bkt.clouddn.com/threeminutes.mp4",
            @"http://p11s9kqxf.bkt.clouddn.com/designedByAppleInCalifornia.mp4",
            @"http://p11s9kqxf.bkt.clouddn.com/thinkDifferent.mp4",
            @"http://p11s9kqxf.bkt.clouddn.com/steveInStanford.mp4",
            @"http://p11s9kqxf.bkt.clouddn.com/Bitcoin.mp4",
            @"http://p11s9kqxf.bkt.clouddn.com/chunjie.mp4",
            @"http://p11s9kqxf.bkt.clouddn.com/liangliang.mp4",
            @"http://p11s9kqxf.bkt.clouddn.com/nanianhuakai.mp4",
            @"http://p11s9kqxf.bkt.clouddn.com/wanghanxu.mp4",
            @"http://p11s9kqxf.bkt.clouddn.com/xiaochou.mp4",
            @"http://p11s9kqxf.bkt.clouddn.com/fukua.mp4",
            @"http://static.smartisanos.cn/common/video/smartisanT2.mp4",
            @"http://static.smartisanos.cn/common/video/m1-white.mp4",
            @"http://static.smartisanos.cn/common/video/video-jgpro.mp4",
            @"http://static.smartisanos.cn/common/video/ammounition-video.mp4",
            @"http://static.smartisanos.cn/common/video/t1-ui.mp4",
            @"http://static.smartisanos.cn/common/video/smartisant1.mp4",
            @"http://static.smartisanos.cn/common/video/ammounition-video.mp4",
            @"http://static.smartisanos.cn/common/video/proud-driver.mp4",
            @"http://static.smartisanos.cn/common/video/proud-farmer.mp4"
    ];
}

@end
