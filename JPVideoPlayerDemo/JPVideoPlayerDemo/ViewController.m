//
//  ViewController.m
//  JPVideoPlayer
//
//  Created by lava on 16/8/18.
//  Hello! I am NewPan from Guangzhou of China, Glad you could use my framework, If you have any question or wanna to contact me, please open https://github.com/Chris-Pan or http://www.jianshu.com/users/e2f2d779c022/latest_articles


#import "ViewController.h"
#import "JPVideoPlayer/JPVideoPlayer.h"
#import "JPVideoPlayerCell.h"


/*
 * The scroll derection of tableview.
 * 滚动类型
 */
typedef NS_ENUM(NSUInteger, ScrollDerection) {
    ScrollDerectionUp = 1, // 向上滚动
    ScrollDerectionDown = 2 // 向下滚动
};

@interface ViewController ()

/**
 * Arrary of video paths.
 * 播放路径数组集合
 */
@property(nonatomic, strong)NSArray *pathStrings;

/** 
 * The cell of playing video.
 * 正在播放视频的cell 
 */
@property(nonatomic, strong)JPVideoPlayerCell *playingCell;

/**
 * The video path of playing with.
 * 当前播放视频的网络链接地址
 */
@property(nonatomic, strong)NSString *currentVideoPath;

/** 
 * The scroll derection of tableview before.
 * 之前滚动方向类型 
 */
@property(nonatomic, assign)ScrollDerection preDerection;

/** 
 * The scroll derection of tableview now.
 * 当前滚动方向类型
 */
@property(nonatomic, assign)ScrollDerection currentDerection;

/** 
 * For calculate the scroll derection of tableview, we need record the offset-Y of tableview when begain drag.
 * 刚开始拖拽时scrollView的偏移量Y值, 用来判断滚动方向
 */
@property(nonatomic, assign)CGFloat contentOffsetY;

/**
 * The number of cells cannot stop in screen center.
 * 滑动不可及cell个数
 */
@property(nonatomic, assign)NSUInteger maxNumCannotPlayVideoCells;

/**
 * The dictionary of record the number of cells that cannot stop in screen center.
 * 滑动不可及cell字典
 */
@property(nonatomic, strong)NSDictionary *dictOfVisiableAndNotPlayCells;

@end


static NSString *reuseID = @"reuseID";
const CGFloat rowHeight = 210;
@implementation ViewController

/**
 * Because we start to play video on cell only when the tableview was stoped scrolling and the cell stoped on screen center, so always some cells cannot stop in screen center maybe, the cells always is those on top or bottom in tableview.
 * So we need handle this especially. But first we need do is that to check the situation of this type cell appear.
 * Here is the result of my measure on iPhone 6s(CH).
 * The number of visiable cells in screen:              4  3  2
 * The number of cells cannot stop in screen center:    1  1  0
 * Tip : you need to know that the mean of result, For example, when we got 4 cells in screen, this time mean that we find 1 cell of cannot stop in screen center on top, and we got the cell of cannot stop in screen center on bottom at the same time.
 * Watch out : the cell of cannot stop in screen center only appear when the number of visiable cell is greater than 3.
 * 由于我们是在tableView静止的时候播放停在屏幕中心的cell, 所以可能出现总有一些cell无法满足我们的播放条件.
 * 所以我们必须特别处理这种情况, 我们首先要做的就是检查什么样的情况下才会出现这种类型的cell.
 * 下面是我的测量结果(iPhone 6s).
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


#pragma mark --------------------------------------------------
#pragma mark System Call

- (void)viewDidLoad {
    [super viewDidLoad];

    [self.tableView registerNib:[UINib nibWithNibName:NSStringFromClass([JPVideoPlayerCell class]) bundle:nil] forCellReuseIdentifier:reuseID];
    
    self.pathStrings = @[
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
}

-(void)viewDidAppear:(BOOL)animated{
    [super viewDidAppear:animated];
    
    // Find the first cell need to play video in visiable cells.
    // 在可见cell中找第一个有视频的进行播放
    [self playVideoInVisiableCells];
}

-(BOOL)prefersStatusBarHidden{
    return YES;
}


#pragma mark --------------------------------------------------
#pragma mark Datasrouce

-(NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section{
    return self.pathStrings.count;
}

-(UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath{
    JPVideoPlayerCell *cell = [tableView dequeueReusableCellWithIdentifier:reuseID forIndexPath:indexPath];
    cell.videoPath = self.pathStrings[indexPath.row];
    cell.indexPath = indexPath;
    cell.containerView.backgroundColor = [self randomColor];
    
    if (self.maxNumCannotPlayVideoCells > 0) {
        if (indexPath.row <= self.maxNumCannotPlayVideoCells-1) {
            cell.cellStyle = PlayUnreachCellStyleUp;
        }
        else if (indexPath.row >= self.pathStrings.count-self.maxNumCannotPlayVideoCells){
            cell.cellStyle = PlayUnreachCellStyleDown;
        }
        else{
            cell.cellStyle = PlayUnreachCellStyleNone;
        }
    }
    
    return cell;
}

-(UIColor*)randomColor{
    float red = arc4random_uniform(256) / 255.0;
    float green = arc4random_uniform(256) / 255.0;
    float blue = arc4random_uniform(256) / 255.0;
    return [UIColor colorWithRed:red green:green blue:blue alpha:1];
}


#pragma mark -----------------------------------------
#pragma mark TableView Delegate

-(CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath{
    
    // To calculate the number of cells cannot stop in screen center.
    // 计算滑动不可及cell个数
    [self resetNumOfUnreachCells];
    return rowHeight;
}

/**
 * Called on finger up if the user dragged. decelerate is true if it will continue moving afterwards
 * 松手时已经静止, 只会调用scrollViewDidEndDragging
 */
- (void)scrollViewDidEndDragging:(UIScrollView *)scrollView willDecelerate:(BOOL)decelerate{
  
    if (decelerate == NO) {
        // scrollView已经完全静止
        [self handleScrollStop];
    }
}

/**
 * Called on tableView is static after finger up if the user dragged and tableView is scrolling.
 * 松手时还在运动, 先调用scrollViewDidEndDragging, 再调用scrollViewDidEndDecelerating
 */
- (void)scrollViewDidEndDecelerating:(UIScrollView *)scrollView{
    
    // scrollView已经完全静止
    [self handleScrollStop];
}

-(void)scrollViewWillBeginDragging:(UIScrollView *)scrollView{
    self.contentOffsetY = scrollView.contentOffset.y;
}

-(void)scrollViewDidScroll:(UIScrollView *)scrollView{
    // Handle cyclic utilization
    // 处理循环利用
    [self handleQuickScroll];
}


#pragma mark --------------------------------------------------
#pragma mark Private

-(void)handleScrollStop{
    
    // To find next cell need play video.
    // 找到下一个要播放的cell(最在屏幕中心的)
    JPVideoPlayerCell *finnalCell = nil;
    NSArray *visiableCells = [self.tableView visibleCells];
    NSMutableArray *indexPaths = [NSMutableArray array];
    CGFloat gap = MAXFLOAT;
    
    for (JPVideoPlayerCell *cell in visiableCells) {
        
        [indexPaths addObject:cell.indexPath];
        
        if (cell.videoPath.length > 0) { // If need to play video, 如果这个cell有视频
            
            // Find the cell cannot stop in screen center first.
            // 优先查找滑动不可及cell
            if (cell.cellStyle != PlayUnreachCellStyleNone) {
                
                // Must the all area of the cell is visiable.
                // 并且不可及cell要全部露出
                if (cell.cellStyle == PlayUnreachCellStyleUp) {
                    CGPoint cellLeftUpPoint = cell.frame.origin;
                    // 不要在边界上
                    cellLeftUpPoint.y += 1;
                    CGPoint coorPoint = [cell.superview convertPoint:cellLeftUpPoint toView:nil];
                    CGRect windowRect = self.view.window.bounds;
                    BOOL isContain = CGRectContainsPoint(windowRect, coorPoint);
                    if (isContain) {
                         finnalCell = cell;
                    }
                }
                else if (cell.cellStyle == PlayUnreachCellStyleDown){
                    CGPoint cellLeftUpPoint = cell.frame.origin;
                    cellLeftUpPoint.y += cell.bounds.size.height;
                    // 不要在边界上
                    cellLeftUpPoint.y -= 1;
                    CGPoint coorPoint = [cell.superview convertPoint:cellLeftUpPoint toView:nil];
                    CGRect windowRect = self.view.window.bounds;
                    BOOL isContain = CGRectContainsPoint(windowRect, coorPoint);
                    if (isContain) {
                        finnalCell = cell;
                    }
                }
                
            }
            else if(!finnalCell || finnalCell.cellStyle == PlayUnreachCellStyleNone){
                CGPoint coorCentre = [cell.superview convertPoint:cell.center toView:nil];
                CGFloat delta = fabs(coorCentre.y-[UIScreen mainScreen].bounds.size.height*0.5);
                if (delta < gap) {
                    gap = delta;
                    finnalCell = cell;
                }
            }
        }
    }
    
    // If the found cell is the cell playing video, this situation cannot play video again.
    // 注意, 如果正在播放的cell和finnalCell是同一个cell, 不应该在播放
    if (self.playingCell != finnalCell && finnalCell != nil) {
        [[JPVideoPlayer sharedInstance]stop];
        [[JPVideoPlayer sharedInstance]playWithUrl:[NSURL URLWithString:finnalCell.videoPath] showView:finnalCell.containerView];
        self.playingCell = finnalCell;
        self.currentVideoPath = finnalCell.videoPath;
        [JPVideoPlayer sharedInstance].mute = YES;
        return;
    }
    
    // Stop play when the cell is unvisiable.
    // 再看正在播放视频的那个cell移出视野, 则停止播放
    BOOL isPlayingCellVisiable = YES;
    if (![indexPaths containsObject:self.playingCell.indexPath]) {
        isPlayingCellVisiable = NO;
    }
    if (!isPlayingCellVisiable && self.playingCell) {
        [self stopPlay];
    }
}

-(void)playVideoInVisiableCells{
    
    NSArray *visiableCells = [self.tableView visibleCells];
    
    // Find first cell need play video in visiable cells.
    // 在可见cell中找到第一个有视频的cell
    JPVideoPlayerCell *videoCell = nil;
    for (JPVideoPlayerCell *cell in visiableCells) {
        if (cell.videoPath.length > 0) {
            videoCell = cell;
            break;
        }
    }
    
    // If found, play.
    // 如果找到了, 就开始播放视频
    if (videoCell) {
        self.playingCell = videoCell;
        self.currentVideoPath = videoCell.videoPath;
        JPVideoPlayer *player = [JPVideoPlayer sharedInstance];
        [player playWithUrl:[NSURL URLWithString:videoCell.videoPath] showView:videoCell.containerView];
        player.mute = YES;
    }
}

-(void)handleQuickScroll{
    
    if (!self.playingCell) return;
    
    NSArray *visiableCells = [self.tableView visibleCells];
    
    NSMutableArray *indexPaths = [NSMutableArray array];
    for (JPVideoPlayerCell *cell in visiableCells) {
        [indexPaths addObject:cell.indexPath];
    }
    
    BOOL isPlayingCellVisiable = YES;
    if (![indexPaths containsObject:self.playingCell.indexPath]) {
        isPlayingCellVisiable = NO;
    }
    
    // Stop play when the cell playing video is unvisiable.
    // 当前播放视频的cell移出视线， 或者cell被快速的循环利用了， 都要移除播放器
    if (!isPlayingCellVisiable || ![self.playingCell.videoPath isEqualToString:self.currentVideoPath]) {
        [self stopPlay];
    }
}

-(void)stopPlay{
    [[JPVideoPlayer sharedInstance] stop];
    self.playingCell = nil;
    self.currentVideoPath = nil;
}

-(void)resetNumOfUnreachCells{
    CGFloat radius = [UIScreen mainScreen].bounds.size.height / rowHeight;
    NSUInteger maxNumOfVisiableCells = ceil(radius);
    if (maxNumOfVisiableCells >= 3) {
        self.maxNumCannotPlayVideoCells =  [[self.dictOfVisiableAndNotPlayCells valueForKey:[NSString stringWithFormat:@"%ld", maxNumOfVisiableCells]] integerValue];
    }
}

@end
