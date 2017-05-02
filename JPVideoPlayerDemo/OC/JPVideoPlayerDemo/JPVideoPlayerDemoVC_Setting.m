//
//  JPVideoPlayerDemoVC_Setting.m
//  JPVideoPlayerDemo
//
//  Created by 尹久盼 on 2017/4/30.
//  Copyright © 2017年 NewPan. All rights reserved.
//

#import "JPVideoPlayerDemoVC_Setting.h"
#import "UITableView+VideoPlay.h"
#import "JPVideoPlayerCache.h"
#import "JPQRCodeTool.h"

@interface JPVideoPlayerDemoVC_Setting ()

@property (weak, nonatomic) IBOutlet UIButton *clearBtn;

@property (weak, nonatomic) IBOutlet UILabel *cacheLabel;

@property (weak, nonatomic) IBOutlet UIButton *jianshuBtn;

@property (weak, nonatomic) IBOutlet UIButton *githubBtn;

@property (weak, nonatomic) IBOutlet UIButton *wechatBtn;

@end

@implementation JPVideoPlayerDemoVC_Setting

- (void)viewDidLoad {
    [super viewDidLoad];
    
    [self setup];
}


#pragma mark -----------------------------------------
#pragma mark Click Events

- (IBAction)clearBtnClick:(id)sender {
    
    __weak typeof(self) weakSelf = self;
    
    // Clear all cache.
    // 清空所有缓存
     [[JPVideoPlayerCache sharedCache] clearDiskOnCompletion:^{
         NSLog(@"clear disk finished, 清空磁盘完成");
         
         __strong typeof(weakSelf) strongSelf = weakSelf;
         if (!strongSelf) return;
         [strongSelf calculateCacheMes];
     }];
}

- (IBAction)jianshuBtnClick:(id)sender {
    [self gotoWebForGivenWebSite:@"http://www.jianshu.com/u/e2f2d779c022"];
}

- (IBAction)githubBtnClick:(id)sender {
    [self gotoWebForGivenWebSite:@"https://github.com/Chris-Pan"];
}

- (IBAction)wechatBtnClick:(id)sender {
    [self goWechat];
}


#pragma mark -----------------------------------------
#pragma mark Setup

-(void)setup{
    self.navigationController.navigationBar.hidden = YES;
    self.clearBtn.layer.cornerRadius =
    self.jianshuBtn.layer.cornerRadius =
    self.githubBtn.layer.cornerRadius =
    self.wechatBtn.layer.cornerRadius = 5.0;
    
    [self calculateCacheMes];
}

#pragma mark -----------------------------------------
#pragma mark Private

-(void)calculateCacheMes{
    __weak typeof(self) weakSelf = self;
    
    // Count all cache size.
    // 计算缓存大小
    [[JPVideoPlayerCache sharedCache] calculateSizeWithCompletionBlock:^(NSUInteger fileCount, NSUInteger totalSize) {
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf) return;
        
        NSString *cacheStr = [NSString stringWithFormat:@"总缓存大小: %0.2fMB, 总缓存文件数: %ld 个", (unsigned long)totalSize/1024./1024., (unsigned long)fileCount];
        
        strongSelf.cacheLabel.text = cacheStr;
        
        cacheStr = [cacheStr stringByAppendingString:@", 你可以使用框架提供的方法, 清除所有缓存或指定的缓存, 具体请查看 `JPVideoPlayerCache`\n"];
        printf("%s", [cacheStr UTF8String]);
    }];
}

-(void)gotoWebForGivenWebSite:(NSString *)webSite{
    if (webSite.length==0)
        return;
    
    [[UIApplication sharedApplication] openURL:[NSURL URLWithString:webSite]];
}

-(void)goWechat{
    UIViewController *vc = [[UIViewController alloc]init];
    vc.hidesBottomBarWhenPushed = YES;
    vc.view.backgroundColor = [UIColor whiteColor];
    vc.title = @"NewPan 的微信二维码";
    
    NSArray *colors = @[[UIColor colorWithRed:98.0/255.0 green:152.0/255.0 blue:209.0/255.0 alpha:1], [UIColor colorWithRed:190.0/255.0 green:53.0/255.0 blue:77.0/255.0 alpha:1]];
    NSString *codeStr = @"http://weixin.qq.com/r/FeMxKeHeT7wwraVK97YH";
    
    UIImage *img = [JPQRCodeTool generateCodeForString:codeStr withCorrectionLevel:kQRCodeCorrectionLevelHight SizeType:kQRCodeSizeTypeCustom customSizeDelta:50 drawType:kQRCodeDrawTypeCircle gradientType:kQRCodeGradientTypeDiagonal gradientColors:colors];
    UIImageView *imv = [UIImageView new];
    imv.image = img;
    imv.center = vc.view.center;
    imv.bounds = CGRectMake(0, 0, 250, 250);
    [vc.view addSubview:imv];
    
    [self.navigationController pushViewController:vc animated:YES];
}

@end
