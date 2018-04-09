//
// Created by NewPan on 2018/4/9.
// Copyright (c) 2018 NewPan. All rights reserved.
//

#import "JPVideoPlayerHoverViewController.h"
#import "UIView+WebVideoCache.h"
#import "UINavigationController+FulllScreenPopPush.h"

@interface JPVideoPlayerHoverViewController()<UITableViewDataSource, UITableViewDelegate>

@property (nonatomic, strong) UIView *headerView;

@property (nonatomic, strong) UIView *hoverView;

@property (nonatomic, strong) UITableView *tableView;

@end

@implementation JPVideoPlayerHoverViewController

- (void)dealloc {
    [self.headerView jp_stopPlay];
}

- (void)viewDidLoad {
    [super viewDidLoad];

    self.navigationController.jp_useCustomPopAnimationForCurrentViewController = YES;
    self.title = @"悬停播放";

    self.tableView = ({
        UITableView *view = [UITableView new];
        [self.view addSubview:view];
        view.frame = self.view.bounds;
        view.dataSource = self;
        view.delegate = self;

        view;
    });

    self.headerView = ({
        UIView *view = [UIView new];
        view.bounds = CGRectMake(0, 0, 0, ([UIScreen mainScreen].bounds.size.width * 9.0 / 16.0));
        view.backgroundColor = [UIColor blackColor];

        view;
    });

    self.hoverView = ({
        UIView *view = [UIView new];
        CGSize screenSize = [UIScreen mainScreen].bounds.size;
        CGFloat width = screenSize.width * 0.5;
        view.frame = CGRectMake(width, screenSize.height * 0.5 , width, (width * 9.0 / 16.0) );
        view.backgroundColor = [UIColor blackColor];
        view.userInteractionEnabled = NO;
        [self.view addSubview:view];
        view.hidden = YES;

        view;
    });
    [self.tableView registerClass:[UITableViewCell class] forCellReuseIdentifier:NSStringFromClass([UITableViewCell class])];
    self.tableView.tableHeaderView = self.headerView;
}

- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];

    CGRect tableViewFrame = self.tableView.frame;
    tableViewFrame.size.height -= self.tabBarController.tabBar.bounds.size.height;
    self.tableView.jp_tableViewVisibleFrame = tableViewFrame;
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];

    [self.headerView jp_playVideoWithURL:[NSURL URLWithString:@"http://p11s9kqxf.bkt.clouddn.com/bianche.mp4"]
                      bufferingIndicator:nil
                             controlView:nil
                            progressView:nil
                 configurationCompletion:nil];
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return 15;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:NSStringFromClass([UITableViewCell class]) forIndexPath:indexPath];
    return cell;
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    return 60;
}

- (void)scrollViewDidScroll:(UIScrollView *)scrollView {
    BOOL headerVisible = [self.tableView jp_viewIsVisibleInVisibleFrameAtScrollViewDidScroll:self.headerView];
    if(headerVisible && !self.hoverView.hidden){
       self.hoverView.hidden = YES;
       [self.headerView jp_resumePlayWithURL:[NSURL URLWithString:@"http://p11s9kqxf.bkt.clouddn.com/bianche.mp4"]
                          bufferingIndicator:nil
                                 controlView:nil
                                progressView:nil
                     configurationCompletion:nil];
    }
    else if(!headerVisible && self.hoverView.hidden){
        self.hoverView.hidden = NO;
        [self.hoverView jp_resumePlayWithURL:[NSURL URLWithString:@"http://p11s9kqxf.bkt.clouddn.com/bianche.mp4"]
                                     options:JPVideoPlayerRetryFailed
                     configurationCompletion:nil];
    }
}

@end