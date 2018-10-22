//
//  JPVideoPlayerNetEasyViewController.m
//  JPVideoPlayerDemo
//
//  Created by Memet on 2018/4/24.
//  Copyright © 2018 NewPan. All rights reserved.
//

#import "JPVPNetEasyViewController.h"
#import "JPVPNetEasyTableViewCell.h"
#import "JPVideoPlayerKit.h"

@interface JPVPNetEasyViewController ()<JPVideoPlayerDelegate, JPVPNetEasyTableViewCellDelegate>

/**
 * Arrary of video paths.
 * 播放路径数组集合.
 */
@property (nonatomic, strong, nonnull)NSArray *pathStrings;
@property (nonatomic, strong) JPVPNetEasyTableViewCell *playingCell;

@end

@implementation JPVPNetEasyViewController

#pragma mark -生命周期

- (void)viewDidLoad {
    [super viewDidLoad];
    [self setup];
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    if (self.playingCell) {
        [self.playingCell.videoPlayView jp_stopPlay];
    }
}

#pragma mark - TableViewDataSouce

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return self.pathStrings.count;
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    return 260;
}

- (UITableViewCell*)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    NSString *reuseIdentifier = NSStringFromClass([JPVPNetEasyTableViewCell class]);
    JPVPNetEasyTableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:reuseIdentifier forIndexPath:indexPath];
    cell.delegate = self;
    cell.indexPath = indexPath;
    cell.playButton.hidden = NO;
    return cell;
}

#pragma mark - JPVPNetEasyTableViewCellDelegate

- (void)cellPlayButtonDidClick:(JPVPNetEasyTableViewCell *)cell {
    if (self.playingCell) {
        [self.playingCell.videoPlayView jp_stopPlay];
        self.playingCell.playButton.hidden = NO;
    }
    self.playingCell = cell;
    self.playingCell.playButton.hidden = YES;
    self.playingCell.videoPlayView.jp_videoPlayerDelegate = self;
    NSIndexPath *indexPath = [self.tableView indexPathForCell:cell];
    [self.playingCell.videoPlayView jp_playVideoWithURL:[NSURL URLWithString:self.pathStrings[indexPath.row]]
                                     bufferingIndicator:[JPVideoPlayerBufferingIndicator new]
                                            controlView:[[JPVideoPlayerControlView alloc] initWithControlBar:nil blurImage:nil]
                                           progressView:nil
                                          configuration:nil];
}


#pragma mark - TableViewDelegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    NSLog(@"TableView Did Clicked IndexPath - %ld",indexPath.row);
}

- (void)tableView:(UITableView *)tableView didEndDisplayingCell:(UITableViewCell *)cell forRowAtIndexPath:(NSIndexPath *)indexPath {
    if (!self.playingCell) {
        return;
    }
    if (cell.hash == self.playingCell.hash) {
        [self.playingCell.videoPlayView jp_stopPlay];
        self.playingCell.playButton.hidden = NO;
        self.playingCell = nil;
    }
}


#pragma mark - Setup

- (void)setup {
    self.title = @"网易云音乐";
    [self.tableView registerNib:[UINib nibWithNibName:NSStringFromClass([JPVPNetEasyTableViewCell class]) bundle:nil] forCellReuseIdentifier:NSStringFromClass([JPVPNetEasyTableViewCell class])];
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

#pragma mark - JPVideoPlayerDelegate

- (BOOL)shouldShowBlackBackgroundWhenPlaybackStart {
    return YES;
}

- (BOOL)shouldShowBlackBackgroundBeforePlaybackStart {
    return YES;
}

- (BOOL)shouldAutoHideControlContainerViewWhenUserTapping {
    return YES;
}

- (BOOL)shouldShowDefaultControlAndIndicatorViews {
    return NO;
}

@end
