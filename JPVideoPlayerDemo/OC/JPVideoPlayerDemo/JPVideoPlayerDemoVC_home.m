/*
 * This file is part of the JPVideoPlayer package.
 * (c) NewPan <13246884282@163.com>
 *
 * For the full copyright and license information, please view the LICENSE
 * file that was distributed with this source code.
 *
 * Click https://github.com/Chris-Pan
 * or http://www.jianshu.com/users/e2f2d779c022/latest_articles to contact me.
 */

#import "JPVideoPlayerDemoVC_home.h"
#import "UIView+WebVideoCache.h"
#import "JPVideoPlayerDemoCell.h"
#import "JPVideoPlayerDemoVC_push.h"
#import "UITableView+VideoPlay.h"
#import "UITableViewCell+VideoPlay.h"

@interface JPVideoPlayerDemoVC_home ()<UITableViewDelegate, UITableViewDataSource, JPTableViewPlayVideoDelegate>

/**
 * Arrary of video paths.
 * 播放路径数组集合.
 */
@property(nonatomic, strong, nonnull)NSArray *pathStrings;

/**
 * Center indicator line.
 * 中心指示线.
 */
@property(nonatomic, strong, nonnull)UIView *tableViewRange;

/*
 * videoPlayer.
 */
@property(nonatomic, strong, nonnull) AVPlayer *videoPlayer;

@end

#warning 注意: 播放视频的工具类是单例, 单例生命周期为整个应用生命周期, 故而须在 `-viewWillDisappear:`(推荐)或其他方法里 调用 `stopPlay` 方法来停止视频播放, 否则当前控制器销毁了, 视频仍然在后台播放, 虽然看不到图像, 但是能听到声音(如果有).

#define JPVideoPlayerDemoRowHei ([UIScreen mainScreen].bounds.size.width*9.0/16.0)
static NSString *JPVideoPlayerDemoReuseID = @"JPVideoPlayerDemoReuseID";
@implementation JPVideoPlayerDemoVC_home

- (void)viewDidLoad {
    [super viewDidLoad];

    [self setup];
    [self insertLineInScreenCenter];
}

- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];

    CGRect tableViewFrame = self.tableView.frame;
    tableViewFrame.size.height -= self.tabBarController.tabBar.bounds.size.height;
    self.tableView.jp_tableViewVisibleFrame = tableViewFrame;
}

- (void)viewDidAppear:(BOOL)animated{
    [super viewDidAppear:animated];

    [self.tableView jp_playVideoInVisibleCellsIfNeed];

    // 用来防止选中 cell push 到下个控制器时, tableView 再次调用 scrollViewDidScroll 方法, 造成 playingVideoCell 被置空.
    self.tableView.delegate = self;
    self.tableViewRange.hidden = NO;
}

- (void)viewWillDisappear:(BOOL)animated{
    [super viewWillDisappear:animated];

    // 用来防止选中 cell push 到下个控制器时, tableView 再次调用 scrollViewDidScroll 方法, 造成 playingVideoCell 被置空.
    self.tableView.delegate = nil;
    if (self.tableView.jp_playingVideoCell) {
        [self.tableView.jp_playingVideoCell.jp_videoPlayView jp_stopPlay];
    }

    self.tableViewRange.hidden = YES;
}


#pragma mark - Data Srouce

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section{
    tableView.separatorStyle = UITableViewCellSeparatorStyleNone;
    return self.pathStrings.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath{
    JPVideoPlayerDemoCell *cell = [tableView dequeueReusableCellWithIdentifier:JPVideoPlayerDemoReuseID forIndexPath:indexPath];
    cell.indexPath = indexPath;
    cell.selectionStyle = UITableViewCellSelectionStyleNone;
    cell.jp_videoURL = [NSURL URLWithString:self.pathStrings[indexPath.row]];
    cell.jp_videoPlayView = cell.videoImv;
    [tableView jp_handleCellUnreachableTypeForCell:cell
                                       atIndexPath:indexPath];
    return cell;
}


#pragma mark - TableView Delegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath{
    JPVideoPlayerDemoVC_push *single = [JPVideoPlayerDemoVC_push new];
    single.hidesBottomBarWhenPushed = YES;
    [self.navigationController pushViewController:single animated:YES];
    JPVideoPlayerDemoCell *cell = [tableView cellForRowAtIndexPath:indexPath];
    single.videoPath = cell.jp_videoURL.absoluteString;
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath{
    return indexPath.row % 2 == 0 ? JPVideoPlayerDemoRowHei : (JPVideoPlayerDemoRowHei + 40);
}

/**
 * Called on finger up if the user dragged. decelerate is true if it will continue moving afterwards
 * 松手时已经静止, 只会调用scrollViewDidEndDragging
 */
- (void)scrollViewDidEndDragging:(UIScrollView *)scrollView willDecelerate:(BOOL)decelerate {
    [self.tableView jp_scrollViewDidEndDragging:scrollView willDecelerate:decelerate];
}

/**
 * Called on tableView is static after finger up if the user dragged and tableView is scrolling.
 * 松手时还在运动, 先调用scrollViewDidEndDragging, 再调用scrollViewDidEndDecelerating
 */
- (void)scrollViewDidEndDecelerating:(UIScrollView *)scrollView{
    [self.tableView jp_scrollViewDidEndDecelerating:scrollView];
}

- (void)scrollViewDidScroll:(UIScrollView *)scrollView{
    [self.tableView jp_scrollViewDidScroll:scrollView];
}


#pragma mark - JPTableViewPlayVideoDelegate

- (void)tableView:(UITableView *)tableView readyPlayVideoOnCell:(UITableViewCell *)cell {
    [cell.jp_videoPlayView jp_playVideoMuteWithURL:cell.jp_videoURL progressView:nil];
}


#pragma mark - Setup

- (void)setup{
    // 自定义导航栏
    UIImageView *navBarImageView = [UIImageView new];
    UIImage *navImage = [UIImage imageNamed:@"navbar"];
    navBarImageView.image = navImage;
    navBarImageView.frame = CGRectMake(0, -navImage.size.height + 44.f, [UIScreen mainScreen].bounds.size.width, navImage.size.height);
    [self.navigationController.navigationBar addSubview:navBarImageView];

    self.tableView.delegate = self;
    self.tableView.dataSource = self;
    [self.tableView registerNib:[UINib nibWithNibName:NSStringFromClass([JPVideoPlayerDemoCell class]) bundle:nil] forCellReuseIdentifier:JPVideoPlayerDemoReuseID];

    self.tableView.jp_delegate = self;

    // location file in disk.
    // 本地视频播放.
    NSString *locVideoPath = [[NSBundle mainBundle]pathForResource:@"designedByAppleInCalifornia" ofType:@"mp4"];
    NSURL *url = [NSURL fileURLWithPath:locVideoPath];
    self.pathStrings = @[
            url.absoluteString,
//            @"http://p11s9kqxf.bkt.clouddn.com/thinkDifferent.mp4",
//            @"http://p11s9kqxf.bkt.clouddn.com/thinkDifferent.mp4",
//            @"http://p11s9kqxf.bkt.clouddn.com/thinkDifferent.mp4",
//            @"http://p11s9kqxf.bkt.clouddn.com/thinkDifferent.mp4",
//            @"http://p11s9kqxf.bkt.clouddn.com/thinkDifferent.mp4",
//            @"http://p11s9kqxf.bkt.clouddn.com/thinkDifferent.mp4",
//            @"http://p11s9kqxf.bkt.clouddn.com/thinkDifferent.mp4",
//            @"http://p11s9kqxf.bkt.clouddn.com/thinkDifferent.mp4",
//            @"http://p11s9kqxf.bkt.clouddn.com/thinkDifferent.mp4",
//            @"http://p11s9kqxf.bkt.clouddn.com/thinkDifferent.mp4",
//            @"http://p11s9kqxf.bkt.clouddn.com/thinkDifferent.mp4",
//            @"http://p11s9kqxf.bkt.clouddn.com/thinkDifferent.mp4",
//            @"http://p11s9kqxf.bkt.clouddn.com/thinkDifferent.mp4",
//            @"http://p11s9kqxf.bkt.clouddn.com/thinkDifferent.mp4",
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


#pragma mark - Private

- (void)insertLineInScreenCenter{
    [[UIApplication sharedApplication].keyWindow insertSubview:self.tableViewRange aboveSubview:self.tableView];
}

- (UIView *)tableViewRange{
    CGFloat navAndStatusBarHeight = [UIApplication sharedApplication].statusBarFrame.size.height + self.navigationController.navigationBar.bounds.size.height;
    CGFloat tabBarHeight = self.tabBarController.tabBar.bounds.size.height;
    if (!_tableViewRange) {
        _tableViewRange = [UIView new];
        _tableViewRange.userInteractionEnabled = NO;
        CGSize screenSize = [UIScreen mainScreen].bounds.size;
        _tableViewRange.backgroundColor = [UIColor clearColor];
        _tableViewRange.frame = CGRectMake(0, navAndStatusBarHeight, screenSize.width, screenSize.height -  navAndStatusBarHeight - tabBarHeight);
        _tableViewRange.hidden = YES;

        UIBezierPath *linePath1 = [UIBezierPath bezierPath];
        {
            [linePath1 moveToPoint:CGPointMake(1, 1)];
            [linePath1 addLineToPoint:CGPointMake(screenSize.width-1, 1)];
            [linePath1 addLineToPoint:CGPointMake(screenSize.width-1, screenSize.height-navAndStatusBarHeight-tabBarHeight-1)];
            [linePath1 addLineToPoint:CGPointMake(1, screenSize.height-navAndStatusBarHeight-tabBarHeight-1)];
            [linePath1 addLineToPoint:CGPointMake(1, 1)];
        }

        CAShapeLayer *layer1 = [CAShapeLayer layer];
        {
            UIColor *drawColor = [UIColor colorWithRed:1 green:0 blue:0 alpha:1];
            layer1.path = linePath1.CGPath;
            layer1.strokeColor = drawColor.CGColor;
            layer1.fillColor = [UIColor clearColor].CGColor;
            layer1.lineWidth = 1;
            [layer1 setLineDashPattern:
                    [NSArray arrayWithObjects:[NSNumber numberWithInt:6],
                                              [NSNumber numberWithInt:3],nil]];
            layer1.lineCap = @"round";
            [_tableViewRange.layer addSublayer:layer1];
        }

        UIBezierPath *linePath2 = [UIBezierPath bezierPath];
        {
            [linePath2 moveToPoint:CGPointMake(1, 0.5*(screenSize.height-navAndStatusBarHeight-tabBarHeight-1))];
            [linePath2 addLineToPoint:CGPointMake(screenSize.width-1, 0.5*(screenSize.height-navAndStatusBarHeight-tabBarHeight-1))];
        }

        CAShapeLayer *layer2 = [CAShapeLayer layer];
        {
            UIColor *drawColor = [UIColor colorWithRed:0 green:0.98 blue:0 alpha:1];
            layer2.path = linePath2.CGPath;
            layer2.strokeColor = drawColor.CGColor;
            layer2.fillColor = [UIColor clearColor].CGColor;
            layer2.lineWidth = 1;
            [layer2 setLineDashPattern:
                    [NSArray arrayWithObjects:[NSNumber numberWithInt:6],
                                              [NSNumber numberWithInt:3],nil]];
            layer2.lineCap = @"round";
            [_tableViewRange.layer addSublayer:layer2];
        }

    }
    return _tableViewRange;
}

@end
