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

#import "JPVideoPlayerSettingViewController.h"
#import "JPVideoPlayerKit.h"
#import "JPQRCodeTool.h"

@interface JPVideoPlayerSettingViewController ()

@property (weak, nonatomic) IBOutlet UIButton *clearBtn;

@property (weak, nonatomic) IBOutlet UILabel *cacheLabel;

@property (weak, nonatomic) IBOutlet UIButton *jianshuBtn;

@property (weak, nonatomic) IBOutlet UIButton *githubBtn;

@property (weak, nonatomic) IBOutlet UIButton *qqBtn;

@end

@implementation JPVideoPlayerSettingViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    [self setup];
}

- (UIStatusBarStyle)preferredStatusBarStyle {
    return UIStatusBarStyleLightContent;
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    [self setNeedsStatusBarAppearanceUpdate];
}

#pragma mark - Click Events

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
    [self gotoWebForGivenWebSite:@"https://github.com/newyjp"];
}

- (IBAction)qqBtnClick:(id)sender {
    [self goWechat];
}


#pragma mark - Setup

- (void)setup{
    self.navigationController.navigationBar.hidden = YES;
    self.clearBtn.layer.cornerRadius =
    self.jianshuBtn.layer.cornerRadius =
    self.githubBtn.layer.cornerRadius =
    self.qqBtn.layer.cornerRadius = 5.0;
    
    [self calculateCacheMes];
}

#pragma mark - Private

- (void)calculateCacheMes{
    __weak typeof(self) weakSelf = self;
    
    // Count all cache size.
    // 计算缓存大小
    [[JPVideoPlayerCache sharedCache] calculateSizeOnCompletion:^(NSUInteger fileCount, NSUInteger totalSize) {
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf) return;

        NSString *cacheStr = [NSString stringWithFormat:@"总缓存大小: %0.2fMB, 总缓存文件数: %ld 个", (unsigned long) totalSize / 1024. / 1024., (unsigned long) fileCount];

        strongSelf.cacheLabel.text = cacheStr;

        cacheStr = [cacheStr stringByAppendingString:@", 你可以使用框架提供的方法, 清除所有缓存或指定的缓存, 具体请查看 `JPVideoPlayerCache`\n"];
        printf("%s", [cacheStr UTF8String]);
    }];
}

- (void)gotoWebForGivenWebSite:(NSString *)webSite{
    if (webSite.length==0)
        return;
    
    [[UIApplication sharedApplication] openURL:[NSURL URLWithString:webSite]];
}

- (void)goWechat{
    UIViewController *vc = [[UIViewController alloc]init];
    vc.hidesBottomBarWhenPushed = YES;
    vc.view.backgroundColor = [UIColor whiteColor];
    vc.title = @"扫描加入 NewPan 和他的朋友们群";
    
    NSArray *colors = @[[UIColor colorWithRed:98.0/255.0 green:152.0/255.0 blue:209.0/255.0 alpha:1], [UIColor colorWithRed:190.0/255.0 green:53.0/255.0 blue:77.0/255.0 alpha:1]];
    NSString *codeStr = @"http://qm.qq.com/cgi-bin/qm/qr?k=iOcOSuD9eYS7kdmcclRFnWFkHZbGIjdm";
    
    UIImage *img = [JPQRCodeTool generateCodeForString:codeStr withCorrectionLevel:kQRCodeCorrectionLevelNormal SizeType:kQRCodeSizeTypeCustom customSizeDelta:50 drawType:kQRCodeDrawTypeCircle gradientType:kQRCodeGradientTypeDiagonal gradientColors:colors];
    UIImageView *imv = [UIImageView new];
    imv.image = img;
    imv.center = vc.view.center;
    imv.bounds = CGRectMake(0, 0, 250, 250);
    [vc.view addSubview:imv];
    
    [self.navigationController pushViewController:vc animated:YES];
}

@end
