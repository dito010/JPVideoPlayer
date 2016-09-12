//
//  ViewController.m
//  JPVideoPlayer
//
//  Created by lava on 16/8/18.
//  Copyright © 2016年 lavaMusic. All rights reserved.
//

#import "ViewController.h"
#import "JPVideoPlayer/JPPlayer.h"
#import "JPVideoPlayerCell.h"

// 滚动类型
typedef NS_ENUM(NSUInteger, ScrollDerection) {
    ScrollDerectionUp = 1, // 上滑
    ScrollDerectionDown = 2 // 下滑
};

@interface ViewController ()

/** listArr */
@property(nonatomic, strong)NSArray *listArr;

/** 正在播放视频的cell */
@property(nonatomic, strong)JPVideoPlayerCell *playingCell;

/** 当前播放视频的网络链接地址 */
@property(nonatomic, strong)NSString *currentVideoPath;

/** 之前滚动方向类型 */
@property(nonatomic, assign)ScrollDerection preDerection;

/** 当前滚动方向类型 */
@property(nonatomic, assign)ScrollDerection currentDerection;

/** 刚开始拖拽时scrollView的偏移量Y值, 用来判断滚动方向 */
@property(nonatomic, assign)CGFloat contentOffsetY;

/** 不可播放视频cell个数 */
@property(nonatomic, assign)NSUInteger maxNumCannotPlayVideoCells;

/** 不可播放视频的cell数字典 */
@property(nonatomic, strong)NSDictionary *dictOfVisiableAndNotPlayCells;

@end

/*
    当有永远到不了屏幕中心的cell, 并且这种类型的cell不止一个, 需要播放视频的时候
    向上拖动一次, 播放靠近中心的cell的视频
    再向上拖动一次, 播放cell更下面的cell的视频, 并以此类推
    向下拖动也是一样的处理逻辑
    每屏cell个数           4 3 2
    不能播放视频的cell个数   1 1 0
 */

static NSString *reuseID = @"reuseID";
const CGFloat rowHeight = 210;
@implementation ViewController

-(NSDictionary *)dictOfVisiableAndNotPlayCells{
    // 以每屏可见cell的最大个数为key, 对应的不能播放视频的cell为value
    // 只有每屏可见cell数在3以上时,才会出现滑动时有cell的视频永远播放不到
    // 以下值都是实际测量得到
    if (!_dictOfVisiableAndNotPlayCells) {
        _dictOfVisiableAndNotPlayCells = @{
                                           @"4" : @"1",
                                           @"3" : @"1",
                                           };
    }
    return _dictOfVisiableAndNotPlayCells;
}

- (void)viewDidLoad {
    [super viewDidLoad];

    [self.tableView registerNib:[UINib nibWithNibName:NSStringFromClass([JPVideoPlayerCell class]) bundle:nil] forCellReuseIdentifier:reuseID];
    
    self.listArr = @[
                     @"http://120.25.226.186:32812/resources/videos/minion_01.mp4",
                     @"http://120.25.226.186:32812/resources/videos/minion_02.mp4",
                     @"http://120.25.226.186:32812/resources/videos/minion_03.mp4",
                     @"http://120.25.226.186:32812/resources/videos/minion_04.mp4",
                     @"http://120.25.226.186:32812/resources/videos/minion_05.mp4",
                     @"http://120.25.226.186:32812/resources/videos/minion_06.mp4",
                     @"http://120.25.226.186:32812/resources/videos/minion_07.mp4",
                     @"http://120.25.226.186:32812/resources/videos/minion_08.mp4",
                     // 模拟有些cell没有视频
//                     @"",
                     @"http://120.25.226.186:32812/resources/videos/minion_10.mp4",
                     @"http://120.25.226.186:32812/resources/videos/minion_11.mp4",
                     ];
}

-(void)viewDidAppear:(BOOL)animated{
    [super viewDidAppear:animated];
    
    // 在可见cell中找第一个有视频的进行播放
    [self playVideoInVisiableCells];
}


#pragma mark --------------------------------------------------
#pragma mark Datasrouce

-(NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section{
    return self.listArr.count;
}

-(UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath{
    JPVideoPlayerCell *cell = [tableView dequeueReusableCellWithIdentifier:reuseID forIndexPath:indexPath];
    cell.videoPath = self.listArr[indexPath.row];
    cell.indexPath = indexPath;
    cell.containerView.backgroundColor = [self randomColor];
    
    if (self.maxNumCannotPlayVideoCells > 0) {
        if (indexPath.row <= self.maxNumCannotPlayVideoCells-1) {
            cell.cellStyle = PlayUnreachCellStyleUp;
        }
        else if (indexPath.row >= self.listArr.count-self.maxNumCannotPlayVideoCells){
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
    // 计算顶部和底部各有几个cell是永远不可能滑动到中心
    [self resetNumOfUnreachCells];
    return rowHeight;
}

// 松手时已经静止,只会调用scrollViewDidEndDragging
- (void)scrollViewDidEndDragging:(UIScrollView *)scrollView willDecelerate:(BOOL)decelerate{
    if (decelerate == NO) { // scrollView已经完全静止
        [self handleScroll];
    }
}

// 松手时还在运动, 先调用scrollViewDidEndDragging,在调用scrollViewDidEndDecelerating
- (void)scrollViewDidEndDecelerating:(UIScrollView *)scrollView{
    // scrollView已经完全静止
    [self handleScroll];
}

-(void)scrollViewWillBeginDragging:(UIScrollView *)scrollView{
    self.contentOffsetY = scrollView.contentOffset.y;
}

-(void)scrollViewDidScroll:(UIScrollView *)scrollView{
    
    [self handleQuickScroll];
}

-(void)handleScroll{
    
    // 找到下一个要播放的cell(最在屏幕中心的)
    JPVideoPlayerCell *finnalCell = nil;
    NSArray *visiableCells = [self.tableView visibleCells];
    NSMutableArray *indexPaths = [NSMutableArray array];
    CGFloat gap = MAXFLOAT;
    for (JPVideoPlayerCell *cell in visiableCells) {
        
        [indexPaths addObject:cell.indexPath];
        
        if (cell.videoPath.length > 0) { // 如果这个cell有视频
            
            // 优先查找滑动不可及cell
            if (cell.cellStyle != PlayUnreachCellStyleNone) {
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
    
    // 注意, 如果正在播放的cell和finnalCell是同一个cell, 不应该在播放
    if (self.playingCell != finnalCell && finnalCell != nil) {
        [[JPPlayer sharedInstance]stop];
        [[JPPlayer sharedInstance]playWithUrl:[NSURL URLWithString:finnalCell.videoPath] showView:finnalCell.containerView];
        self.playingCell = finnalCell;
        self.currentVideoPath = finnalCell.videoPath;
        [JPPlayer sharedInstance].mute = YES;
        return;
    }
    
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
    
    // 在可见cell中找到第一个有视频的cell
    JPVideoPlayerCell *videoCell = nil;
    for (JPVideoPlayerCell *cell in visiableCells) {
        if (cell.videoPath.length > 0) {
            videoCell = cell;
            break;
        }
    }
    
    // 如果找到了, 就开始播放视频
    if (videoCell) {
        self.playingCell = videoCell;
        self.currentVideoPath = videoCell.videoPath;
        JPPlayer *player = [JPPlayer sharedInstance];
        [player playWithUrl:[NSURL URLWithString:videoCell.videoPath] showView:videoCell.containerView];
        player.mute = YES;
    }
}

// 快速滑动循环利用问题
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
    
    // 当前播放视频的cell移出视线， 或者cell被快速的循环利用了， 都要移除播放器
    if (!isPlayingCellVisiable || ![self.playingCell.videoPath isEqualToString:self.currentVideoPath]) {
        [self stopPlay];
    }
}

// 停止播放
-(void)stopPlay{
    [[JPPlayer sharedInstance] stop];
    self.playingCell = nil;
    self.currentVideoPath = nil;
}

// 计算不可播放cell数
-(void)resetNumOfUnreachCells{
    CGFloat radius = [UIScreen mainScreen].bounds.size.height / rowHeight;
    NSUInteger maxNumOfVisiableCells = ceil(radius);
    if (maxNumOfVisiableCells >= 3) {
        self.maxNumCannotPlayVideoCells =  [[self.dictOfVisiableAndNotPlayCells valueForKey:[NSString stringWithFormat:@"%ld", maxNumOfVisiableCells]] integerValue];
    }
}


@end
