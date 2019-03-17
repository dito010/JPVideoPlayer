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

#import "JPVideoPlayerWeiBoViewController.h"
#import "JPVideoPlayerWeiBoListViewController.h"
#import "JPVideoPlayerHoverViewController.h"
#import "JPVideoPlayerAudioViewController.h"
#import "JPVideoPlayerCustomizedVideoViewController.h"

@interface JPVideoPlayerWeiBoViewController()

@property (nonatomic, strong) NSArray<NSString *> *cellTypeStrings;

@end

// https://www.jianshu.com/p/5fab7968f76a
@implementation JPVideoPlayerWeiBoViewController

- (void)viewDidLoad {
    [super viewDidLoad];

    self.title = @"仿微博";
    [self.tableView registerClass:[UITableViewCell class] forCellReuseIdentifier:NSStringFromClass([UITableViewCell class])];
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return self.cellTypeStrings.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:NSStringFromClass([UITableViewCell class]) forIndexPath:indexPath];
    cell.textLabel.text = self.cellTypeStrings[indexPath.row];
    return cell;
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    return 60;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    UIViewController *viewController = nil;
    if(indexPath.row == 0){
        viewController = [[JPVideoPlayerWeiBoListViewController alloc] initWithPlayStrategyType:JPScrollPlayStrategyTypeBestVideoView];
    }
    else if(indexPath.row == 1) {
        viewController = [[JPVideoPlayerWeiBoListViewController alloc] initWithPlayStrategyType:JPScrollPlayStrategyTypeBestCell];
    }
    else if(indexPath.row == 2) {
        viewController = [JPVideoPlayerHoverViewController new];
    }
    else if(indexPath.row == 3) {
        viewController = [JPVideoPlayerAudioViewController new];
    }
    else if(indexPath.row == 4) {
        viewController = [JPVideoPlayerCustomizedVideoViewController new];
    }
    [self.navigationController pushViewController:viewController animated:YES];
}

- (NSArray<NSString *> *)cellTypeStrings {
    if(!_cellTypeStrings){
       _cellTypeStrings = @[@"不等高 Cell 自动播放", @"等高 Cell 自动播放", @"悬停播放", @"音频播放", @"自定义视频地址"];
    }
    return _cellTypeStrings;
}

@end
