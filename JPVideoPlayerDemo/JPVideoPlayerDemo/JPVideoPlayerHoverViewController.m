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

#import "JPVideoPlayerHoverViewController.h"
#import "JPVideoPlayerKit.h"
#import "UINavigationController+FulllScreenPopPush.h"

@interface JPVideoPlayerHoverViewController()<UITableViewDataSource, UITableViewDelegate, JPVideoPlayerDelegate>

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

        view;
    });

    self.headerView = ({
        UIView *view = [UIView new];
        view.bounds = CGRectMake(0, 0, 0, ([UIScreen mainScreen].bounds.size.width * 9.0 / 16.0));
        view.backgroundColor = [UIColor blackColor];
        view.jp_videoPlayerDelegate = self;

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
    self.tableView.jp_scrollViewVisibleFrame = tableViewFrame;
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];

    NSString *videoString = @"http://mvvideo2.meitudata.com/576bc2fc91ef22121.mp4";
    self.tableView.delegate = self;
    [self.headerView jp_playVideoWithURL:[NSURL URLWithString:videoString]
                      bufferingIndicator:nil
                             controlView:nil
                            progressView:nil
                           configuration:nil];
}

- (void)viewDidDisappear:(BOOL)animated {
    [super viewDidDisappear:animated];
    self.tableView.delegate = nil;
    [self.headerView jp_stopPlay];
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
    NSString *videoString = @"http://mvvideo2.meitudata.com/576bc2fc91ef22121.mp4";
    BOOL headerVisible = [self.tableView jp_viewIsVisibleInVisibleFrameAtScrollViewDidScroll:self.headerView];
    if(headerVisible && !self.hoverView.hidden){
       self.hoverView.hidden = YES;
        [self.headerView jp_resumePlayWithURL:[NSURL URLWithString:videoString]
                           bufferingIndicator:nil
                                  controlView:nil
                                 progressView:nil
                                configuration:nil];
    }
    else if(!headerVisible && self.hoverView.hidden){
        self.hoverView.hidden = NO;
        [self.hoverView jp_resumePlayWithURL:[NSURL URLWithString:videoString]
                                     options:JPVideoPlayerRetryFailed
                               configuration:nil];
    }
}


#pragma mark - JPVideoPlayerDelegate

- (BOOL)shouldResumePlaybackFromPlaybackRecordForURL:(NSURL *)videoURL
                                      elapsedSeconds:(NSTimeInterval)elapsedSeconds {
    return YES;
}

@end
