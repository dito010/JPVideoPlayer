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
#import "JPVideoPlayerDemoVC_present.h"
#import "JPVideoPlayerCache.h"
#import "JPVideoPlayerDemoVC_home+VideoPlay.h"

@interface JPVideoPlayerDemoVC_home ()<UITableViewDelegate, UITableViewDataSource>

/**
 * Arrary of video paths.
 * 播放路径数组集合.
 */
@property(nonatomic, strong, nonnull)NSArray *pathStrings;

/**
 * For calculate the scroll derection of tableview, we need record the offset-Y of tableview when begain drag.
 * 刚开始拖拽时scrollView的偏移量Y值, 用来判断滚动方向.
 */
@property(nonatomic, assign)CGFloat offsetY_last;

/**
 * Center indicator line.
 * 中心指示线.
 */
@property(nonatomic, strong, nonnull)UIView *tableViewRange;

@end

#warning 注意: 播放视频的工具类是单例, 单例生命周期为整个应用生命周期, 故而须在 `-viewWillDisappear:`(推荐)或其他方法里 调用 `stopPlay` 方法来停止视频播放, 否则当前控制器销毁了, 视频仍然在后台播放, 虽然看不到图像, 但是能听到声音(如果有).

static NSString *JPVideoPlayerDemoReuseID = @"JPVideoPlayerDemoReuseID";
@implementation JPVideoPlayerDemoVC_home

- (void)viewDidLoad {
    [super viewDidLoad];
    
    [self setup];
    
    [self insertLineInScreenCenter];
}

-(void)viewDidAppear:(BOOL)animated{
    [super viewDidAppear:animated];
    
    if (!self.playingCell) {
        // Find the first cell need to play video in visiable cells.
        // 在可见cell中找第一个有视频的进行播放.
        [self playVideoInVisiableCells];
    }
    else{
        NSURL *url = [NSURL URLWithString:self.playingCell.videoPath];
        [self.playingCell.videoImv jp_playVideoMutedDisplayStatusViewWithURL:url];
    }
    
    self.tableViewRange.hidden = NO;
}

-(void)viewWillDisappear:(BOOL)animated{
    [super viewWillDisappear:animated];
    
    if (self.playingCell) {
        [self.playingCell.videoImv stopPlay];
    }
    
    self.tableViewRange.hidden = YES;
}


#pragma mark --------------------------------------------------
#pragma mark Data Srouce

-(NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section{
    tableView.separatorStyle = UITableViewCellSeparatorStyleNone;
    return self.pathStrings.count;
}

-(UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath{
    JPVideoPlayerDemoCell *cell = [tableView dequeueReusableCellWithIdentifier:JPVideoPlayerDemoReuseID forIndexPath:indexPath];
    cell.videoPath = self.pathStrings[indexPath.row];
    cell.indexPath = indexPath;
    cell.selectionStyle = UITableViewCellSelectionStyleNone;
    if (self.maxNumCannotPlayVideoCells > 0) {
        if (indexPath.row <= self.maxNumCannotPlayVideoCells-1) { // 上不可及
            cell.cellStyle = JPPlayUnreachCellStyleUp;
        }
        else if (indexPath.row >= self.pathStrings.count-self.maxNumCannotPlayVideoCells){ // 下不可及
            cell.cellStyle = JPPlayUnreachCellStyleDown;
        }
        else{
            cell.cellStyle = JPPlayUnreachCellStyleNone;
        }
    }
    else{
        cell.cellStyle = JPPlayUnreachCellStyleNone;
    }
    
    return cell;
}


#pragma mark -----------------------------------------
#pragma mark TableView Delegate

-(void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath{
    JPVideoPlayerDemoVC_present *single = [JPVideoPlayerDemoVC_present new];
    [self presentViewController:single animated:YES completion:nil];
    JPVideoPlayerDemoCell *cell = [tableView cellForRowAtIndexPath:indexPath];
    single.videoPath = cell.videoPath;
}

-(CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath{
    return JPVideoPlayerDemoRowHei;
}

/**
 * Called on finger up if the user dragged. decelerate is true if it will continue moving afterwards
 * 松手时已经静止, 只会调用scrollViewDidEndDragging
 */
- (void)scrollViewDidEndDragging:(UIScrollView *)scrollView willDecelerate:(BOOL)decelerate{
    
    if (decelerate == NO)
        // scrollView已经完全静止
        [self handleScrollStop];
}

/**
 * Called on tableView is static after finger up if the user dragged and tableView is scrolling.
 * 松手时还在运动, 先调用scrollViewDidEndDragging, 再调用scrollViewDidEndDecelerating
 */
- (void)scrollViewDidEndDecelerating:(UIScrollView *)scrollView{
    
    // scrollView已经完全静止
    [self handleScrollStop];
}

-(void)scrollViewDidScroll:(UIScrollView *)scrollView{
    
    // 处理滚动方向
    [self handleScrollDerectionWithOffset:scrollView.contentOffset.y];
    
    // Handle cyclic utilization
    // 处理循环利用
    [self handleQuickScroll];
}

-(void)scrollViewWillBeginDragging:(UIScrollView *)scrollView{
    self.offsetY_last = scrollView.contentOffset.y;
}

-(void)handleScrollDerectionWithOffset:(CGFloat)offsetY{
    self.currentDerection = (offsetY-self.offsetY_last>0) ? JPVideoPlayerDemoScrollDerectionUp : JPVideoPlayerDemoScrollDerectionDown;
    self.offsetY_last = offsetY;
}


#pragma mark -----------------------------------------
#pragma mark Setup

-(void)setup{
    
    // 自定义导航栏
    UIImageView *navBarImageView = [UIImageView new];
    navBarImageView.image = [UIImage imageNamed:@"navbar"];
    navBarImageView.frame = CGRectMake(0, -20, [UIScreen mainScreen].bounds.size.width, JPVideoPlayerDemoNavAndStatusTotalHei);
    [self.navigationController.navigationBar addSubview:navBarImageView];
    
    
    self.tableView.delegate = self;
    self.tableView.dataSource = self;
    [self.tableView registerNib:[UINib nibWithNibName:NSStringFromClass([JPVideoPlayerDemoCell class]) bundle:nil] forCellReuseIdentifier:JPVideoPlayerDemoReuseID];
    
    // location file in disk.
    // 本地视频播放.
    NSString *locVideoPath = [[NSBundle mainBundle]pathForResource:@"hello" ofType:@"mp4"];
    NSURL *url = [NSURL fileURLWithPath:locVideoPath];
    self.pathStrings = @[
                         // location video path.
                         url.absoluteString,
                         
                         @"http://lavaweb-10015286.video.myqcloud.com/%E5%B0%BD%E6%83%85LAVA.mp4",
                         @"http://lavaweb-10015286.video.myqcloud.com/lava-guitar-creation-2.mp4",
                         @"http://lavaweb-10015286.video.myqcloud.com/hong-song-mei-gui-mu-2.mp4",
                         @"http://lavaweb-10015286.video.myqcloud.com/ideal-pick-2.mp4",
                         
                         // This path is a https.
                         //                         @"https://bb-bang.com:9002/Test/Vedio/20170110/f49601b6bfe547e0a7d069d9319388f4.mp4",
                         //                         @"http://123.103.15.1JPVideoPlayerDemoNavAndStatusTotalHei:8880/myVirtualImages/14266942.mp4",
                         
                         // This video saved in amazon, maybe load sowly.
                         //                         @"http://vshow.s3.amazonaws.com/file147801253818487d5f00e2ae6e0194ab085fe4a43066c.mp4",
                         @"http://120.25.226.186:32812/resources/videos/minion_01.mp4",
                         @"http://120.25.226.186:32812/resources/videos/minion_02.mp4",
                         @"http://120.25.226.186:32812/resources/videos/minion_03.mp4",
                         @"http://120.25.226.186:32812/resources/videos/minion_04.mp4",
                         @"http://120.25.226.186:32812/resources/videos/minion_05.mp4",
                         @"http://120.25.226.186:32812/resources/videos/minion_06.mp4",
                         @"http://120.25.226.186:32812/resources/videos/minion_07.mp4",
                         @"http://120.25.226.186:32812/resources/videos/minion_08.mp4",
                         
                         // To simulate the cell have no video to play.
                         // 模拟有些cell没有视频
                         // @"",
                         @"http://120.25.226.186:32812/resources/videos/minion_10.mp4",
                         @"http://120.25.226.186:32812/resources/videos/minion_11.mp4"
                         ];
    
    
    // Count all cache size.
    // 计算缓存大小
    [[JPVideoPlayerCache sharedImageCache] calculateSizeWithCompletionBlock:^(NSUInteger fileCount, NSUInteger totalSize) {
        printf("Total cache size, 总缓存大小: %0.2f/MB, 总缓存文件数: %ld, 你可以使用框架提供的方法, 清除所有缓存或指定的缓存, 具体请查看 `JPVideoPlayerCache`\n", (unsigned long)totalSize/1024./1024., (unsigned long)fileCount);
    }];
    
    // Clear all cache.
    // 清空所有缓存
    // [[JPVideoPlayerCache sharedImageCache] clearDiskOnCompletion:^{
    //  NSLog(@"ClearDiskFinished, 清空磁盘完成");
    // }];
}


#pragma mark --------------------------------------------------
#pragma mark Private

-(void)insertLineInScreenCenter{
    [[UIApplication sharedApplication].keyWindow insertSubview:self.tableViewRange aboveSubview:self.tableView];
}

-(UIView *)tableViewRange{
    if (!_tableViewRange) {
        _tableViewRange = [UIView new];
        _tableViewRange.userInteractionEnabled = NO;
        CGSize screenSize = [UIScreen mainScreen].bounds.size;
        _tableViewRange.backgroundColor = [UIColor clearColor];
        _tableViewRange.frame = CGRectMake(0, JPVideoPlayerDemoNavAndStatusTotalHei, screenSize.width, screenSize.height-JPVideoPlayerDemoNavAndStatusTotalHei);
        _tableViewRange.hidden = YES;
        
        UIBezierPath *linePath1 = [UIBezierPath bezierPath];
        {
            [linePath1 moveToPoint:CGPointMake(1, 1)];
            [linePath1 addLineToPoint:CGPointMake(screenSize.width-1, 1)];
            [linePath1 addLineToPoint:CGPointMake(screenSize.width-1, screenSize.height-JPVideoPlayerDemoNavAndStatusTotalHei-1)];
            [linePath1 addLineToPoint:CGPointMake(1, screenSize.height-JPVideoPlayerDemoNavAndStatusTotalHei-1)];
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
            [linePath2 moveToPoint:CGPointMake(1, 0.5*(screenSize.height-JPVideoPlayerDemoNavAndStatusTotalHei-1))];
            [linePath2 addLineToPoint:CGPointMake(screenSize.width-1, 0.5*(screenSize.height-JPVideoPlayerDemoNavAndStatusTotalHei-1))];
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
