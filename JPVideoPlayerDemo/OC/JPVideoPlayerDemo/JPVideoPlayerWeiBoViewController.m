//
// Created by NewPan on 2018/4/6.
// Copyright (c) 2018 NewPan. All rights reserved.
//

#import "JPVideoPlayerWeiBoViewController.h"
#import "JPVideoPlayerWeiBoListViewController.h"

@interface JPVideoPlayerWeiBoViewController()

@property (nonatomic, strong) NSArray<NSString *> *cellTypeStrings;

@end

@implementation JPVideoPlayerWeiBoViewController

- (void)viewDidLoad {
    [super viewDidLoad];

    self.title = @"微博";
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
    return 40;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    JPVideoPlayerWeiBoListViewController *viewController = nil;
    if(indexPath.row == 0){
        viewController = [[JPVideoPlayerWeiBoListViewController alloc] initWithPlayStrategyType:JPScrollPlayStrategyTypeBestVideoView];
    } else {
        viewController = [[JPVideoPlayerWeiBoListViewController alloc] initWithPlayStrategyType:JPScrollPlayStrategyTypeBestCell];
    }
    [self.navigationController pushViewController:viewController animated:YES];
}

- (NSArray<NSString *> *)cellTypeStrings {
    if(!_cellTypeStrings){
       _cellTypeStrings = @[@"不等高 Cell 自动播放", @"等高 Cell 自动播放"];
    }
    return _cellTypeStrings;
}

@end