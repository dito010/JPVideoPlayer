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

/*
 * The scroll derection of tableview.
 * 滚动类型
 */
typedef NS_ENUM(NSUInteger, JPVideoPlayerDemoScrollDerection) {
    JPVideoPlayerDemoScrollDerectionNone = 0,
    JPVideoPlayerDemoScrollDerectionUp = 1, // 向上滚动
    JPVideoPlayerDemoScrollDerectionDown = 2 // 向下滚动
};

@interface JPVideoPlayerDemoVC_home ()<UITableViewDelegate, UITableViewDataSource>

/**
 * Arrary of video paths.
 * 播放路径数组集合.
 */
@property(nonatomic, strong)NSArray *pathStrings;

/**
 * The cell of playing video.
 * 正在播放视频的cell.
 */
@property(nonatomic, strong)JPVideoPlayerDemoCell *playingCell;

/**
 * The number of cells cannot stop in screen center.
 * 滑动不可及cell个数.
 */
@property(nonatomic, assign)NSUInteger maxNumCannotPlayVideoCells;

/**
 * The dictionary of record the number of cells that cannot stop in screen center.
 * 滑动不可及cell字典.
 */
@property(nonatomic, strong)NSDictionary *dictOfVisiableAndNotPlayCells;

/**
 * The scroll derection of tableview now.
 * 当前滚动方向类型.
 */
@property(nonatomic, assign)JPVideoPlayerDemoScrollDerection currentDerection;

/**
 * For calculate the scroll derection of tableview, we need record the offset-Y of tableview when begain drag.
 * 刚开始拖拽时scrollView的偏移量Y值, 用来判断滚动方向.
 */
@property(nonatomic, assign)CGFloat offsetY_last;

/**
 * Center indicator line.
 * 中心指示线.
 */
@property(nonatomic, strong)UIView *tableViewRange;

@end

#warning 注意: 必须在 `-viewWillDisappear:` 方法里调用 `stopPlay` 方法来停止视频播放.

CGFloat const JPVideoPlayerDemoNavAndStatusTotalHei = 64;
static NSString *JPVideoPlayerDemoReuseID = @"JPVideoPlayerDemoReuseID";
#define JPVideoPlayerDemoRowHei ([UIScreen mainScreen].bounds.size.width*9.0/16.0)
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
        [self.playingCell.videoImv jp_playVideoMutedWithURL:url];
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

-(void)tableView:(UITableView *)tableView willDisplayCell:(UITableViewCell *)cell forRowAtIndexPath:(NSIndexPath *)indexPath{
    
    // Handle cyclic utilization
    // 处理循环利用
    [self handleQuickScroll];
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


#pragma mark --------------------------------------------------
#pragma mark Video Play Events

-(void)handleScrollStop{
    JPVideoPlayerDemoCell *bestCell = [self findTheBestToPlayVideoCell];
    
    // If the found cell is the cell playing video, this situation cannot play video again.
    // 注意, 如果正在播放的 cell 和 finnalCell 是同一个 cell, 不应该在播放.
    if (self.playingCell.hash != bestCell.hash && bestCell.hash != 0) {
        
        [self.playingCell.videoImv stopPlay];
        
        NSURL *url = [NSURL URLWithString:bestCell.videoPath];
        
        // display status view.
        [bestCell.videoImv jp_playVideoMutedDisplayStatusViewWithURL:url];
        
        // hide status view.
        // [bestCell.videoImv jp_playVideoMutedWithURL:url];
        
        self.playingCell = bestCell;
    }
}

-(JPVideoPlayerDemoCell *)findTheBestToPlayVideoCell{
    
    // To find next cell need play video.
    // 找到下一个要播放的cell(最在屏幕中心的).
    
    JPVideoPlayerDemoCell *finnalCell = nil;
    NSArray *visiableCells = [self.tableView visibleCells];
    CGFloat gap = MAXFLOAT;
    
    for (JPVideoPlayerDemoCell *cell in visiableCells) {
        
        @autoreleasepool {
            
            CGRect windowRect = self.view.window.bounds;
            windowRect.origin.y = JPVideoPlayerDemoNavAndStatusTotalHei;
            windowRect.size.height -= JPVideoPlayerDemoNavAndStatusTotalHei;
            
            if (cell.videoPath.length > 0) { // If need to play video, 如果这个cell有视频
                
                
                // Find the cell cannot stop in screen center first.
                // 优先查找滑动不可及cell.
                if (cell.cellStyle != JPPlayUnreachCellStyleNone) {
                    
                    // Must the all area of the cell is visiable.
                    // 并且不可及cell要全部露出.
                    if (cell.cellStyle == JPPlayUnreachCellStyleUp) {
                        CGPoint cellLeftUpPoint = cell.frame.origin;
                        
                        // 不要在边界上.
                        cellLeftUpPoint.y += 2;
                        CGPoint coorPoint = [cell.superview convertPoint:cellLeftUpPoint toView:nil];
                        BOOL isContain = CGRectContainsPoint(windowRect, coorPoint);
                        if (isContain){
                            finnalCell = cell;
                            break;
                        }
                    }
                    else if (cell.cellStyle == JPPlayUnreachCellStyleDown){
                        CGPoint cellLeftUpPoint = cell.frame.origin;
                        CGFloat cellDownY = cellLeftUpPoint.y + cell.bounds.size.height;
                        CGPoint cellLeftDownPoint = CGPointMake(cellLeftUpPoint.x, cellDownY);
                        
                        // 不要在边界上.
                        cellLeftDownPoint.y -= 1;
                        CGPoint coorPoint = [cell.superview convertPoint:cellLeftDownPoint toView:nil];
                        BOOL isContain = CGRectContainsPoint(windowRect, coorPoint);
                        if (isContain){
                            finnalCell = cell;
                            break;
                        }
                    }
                    
                }
                else{
                    CGPoint coorCentre = [cell.superview convertPoint:cell.center toView:nil];
                    CGFloat delta = fabs(coorCentre.y-JPVideoPlayerDemoNavAndStatusTotalHei-windowRect.size.height*0.5);
                    if (delta < gap) {
                        gap = delta;
                        finnalCell = cell;
                    }
                }
            }
        }
    }
    
    return finnalCell;
}

-(void)playVideoInVisiableCells{
    
    NSArray *visiableCells = [self.tableView visibleCells];
    
    // Find first cell need play video in visiable cells.
    // 在可见cell中找到第一个有视频的cell
    JPVideoPlayerDemoCell *videoCell = nil;
    
    for (JPVideoPlayerDemoCell *cell in visiableCells) {
        if (cell.videoPath.length > 0) {
            videoCell = cell;
            break;
        }
    }
    
    // If found, play.
    // 如果找到了, 就开始播放视频
    if (videoCell) {
        self.playingCell = videoCell;
        
        // display status view.
        [videoCell.videoImv jp_playVideoMutedDisplayStatusViewWithURL:[NSURL URLWithString:videoCell.videoPath]];
        
        // hide status view.
        // [videoCell.videoImv jp_playVideoMutedWithURL:[NSURL URLWithString:videoCell.videoPath]];
    }
}

-(void)handleQuickScroll{
    
    if (!self.playingCell) return;
    
    // Stop play when the cell playing video is unvisiable.
    // 当前播放视频的cell移出视线，要移除播放器.
    if (![self playingCellIsVisiable]) {
        [self stopPlay];
    }
}

-(void)stopPlay{
    [self.playingCell.videoImv stopPlay];
    self.playingCell = nil;
}

-(NSUInteger)maxNumCannotPlayVideoCells{
    if (_maxNumCannotPlayVideoCells==0) {
        CGFloat radius = [UIScreen mainScreen].bounds.size.height / JPVideoPlayerDemoRowHei;
        NSUInteger maxNumOfVisiableCells = ceil(radius);
        if (maxNumOfVisiableCells >= 3) {
            _maxNumCannotPlayVideoCells =  [[self.dictOfVisiableAndNotPlayCells valueForKey:[NSString stringWithFormat:@"%ld", (unsigned long)maxNumOfVisiableCells]] integerValue];
        }
    }
    return _maxNumCannotPlayVideoCells;
}

-(void)handleScrollDerectionWithOffset:(CGFloat)offsetY{
    self.currentDerection = (offsetY-self.offsetY_last>0) ? JPVideoPlayerDemoScrollDerectionUp : JPVideoPlayerDemoScrollDerectionDown;
    self.offsetY_last = offsetY;
}

-(BOOL)playingCellIsVisiable{
    if (self.currentDerection==JPVideoPlayerDemoScrollDerectionUp) { // 向上滚动
        CGPoint cellLeftUpPoint = self.playingCell.frame.origin;
        CGFloat cellDownY = cellLeftUpPoint.y + self.playingCell.bounds.size.height;
        CGPoint cellLeftDownPoint = CGPointMake(cellLeftUpPoint.x, cellDownY);
        
        // 不要在边界上.
        cellLeftUpPoint.y -= 1;
        CGPoint coorPoint = [self.playingCell.superview convertPoint:cellLeftDownPoint toView:nil];
        CGRect windowRect = self.view.window.bounds;
        // because have UINavigationBar here.
        windowRect.origin.y = JPVideoPlayerDemoNavAndStatusTotalHei;
        windowRect.size.height -= JPVideoPlayerDemoNavAndStatusTotalHei;
        BOOL isContain = CGRectContainsPoint(windowRect, coorPoint);
        return isContain;
    }
    else if(self.currentDerection==JPVideoPlayerDemoScrollDerectionDown){ // 向下滚动
        CGPoint cellLeftUpPoint = self.playingCell.frame.origin;
        
        // 不要在边界上.
        cellLeftUpPoint.y += 1;
        CGPoint coorPoint = [self.playingCell.superview convertPoint:cellLeftUpPoint toView:nil];
        CGRect windowRect = self.view.window.bounds;
        // because have UINavigationBar here.
        windowRect.origin.y = JPVideoPlayerDemoNavAndStatusTotalHei;
        windowRect.size.height -= JPVideoPlayerDemoNavAndStatusTotalHei;
        BOOL isContain = CGRectContainsPoint(windowRect, coorPoint);
        return isContain;
    }
    return NO;
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
    NSString *locVideoPath = [[NSBundle mainBundle]pathForResource:@"ppap" ofType:@"mp4"];
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
                         @"http://120.25.226.186:32812/resources/videos/minion_11.mp4",
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

/**
 * Because we start to play video on cell only when the tableview was stoped scrolling and the cell stoped on screen center, so always some cells cannot stop in screen center maybe, the cells always is those on top or bottom in tableview.
 * So we need handle this especially. But first we need do is that to check the situation of this type cell appear.
 * Here is the result of my measure on iPhone 6s(CH).
 * The number of visiable cells in screen:              4  3  2
 * The number of cells cannot stop in screen center:    1  1  0
 * Tip : you need to know that the mean of result, For example, when we got 4 cells in screen, this time mean that we find 1 cell of cannot stop in screen center on top, and we got the cell of cannot stop in screen center on bottom at the same time.
 * Watch out : the cell of cannot stop in screen center only appear when the number of visiable cell is greater than 3.
 *
 * 由于我们是在tableView静止的时候播放停在屏幕中心的cell, 所以可能出现总有一些cell无法满足我们的播放条件.
 * 所以我们必须特别处理这种情况, 我们首先要做的就是检查什么样的情况下才会出现这种类型的cell.
 * 下面是我的测量结果(iPhone 6s, iPhone 6 plus).
 * 每屏可见cell个数           4  3  2
 * 滑动不可及的cell个数        1  1  0
 * 注意 : 你需要仔细思考一下我的测量结果, 举个例子, 如果屏幕上有4个cell, 那么这个时候, 我们能够在顶部发现一个滑动不可及cell, 同时, 我们在底部也会发现一个这样的cell.
 * 注意 : 只有每屏可见cell数在3以上时,才会出现滑动不可及cell.
 */
-(NSDictionary *)dictOfVisiableAndNotPlayCells{
    
    // The key is the number of visiable cells in screen, the value is the number of cells cannot stop in screen center.
    // 以每屏可见cell的最大个数为key, 对应的滑动不可及cell数为value
    
    if (!_dictOfVisiableAndNotPlayCells) {
        _dictOfVisiableAndNotPlayCells = @{
                                           @"4" : @"1",
                                           @"3" : @"1",
                                           @"2" : @"0"
                                           };
    }
    return _dictOfVisiableAndNotPlayCells;
}

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
