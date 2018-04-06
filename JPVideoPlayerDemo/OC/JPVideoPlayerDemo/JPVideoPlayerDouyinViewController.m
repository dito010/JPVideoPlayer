//
// Created by NewPan on 2018/4/6.
// Copyright (c) 2018 NewPan. All rights reserved.
//

#import "JPVideoPlayerDouyinViewController.h"
#import "UIView+WebVideoCache.h"

@interface JPVideoPlayerDouyinViewController()<UIScrollViewDelegate>

@property (nonatomic, strong) UIScrollView *scrollView;

@property (nonatomic, strong) UIImageView *firstImageView;

@property (nonatomic, strong) UIImageView *secondImageView;

@property (nonatomic, strong) UIImageView *thridImageView;

@property (nonatomic, strong) NSArray<NSString *> *douyinVideoStrings;

@property(nonatomic, assign) NSUInteger currentVideoIndex;

@end

@implementation JPVideoPlayerDouyinViewController

- (void)viewDidLoad {
    [super viewDidLoad];

    [self setup];
}

- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
    self.scrollView.contentInset = UIEdgeInsetsZero;
    if (@available(iOS 11.0, *)) {
        self.scrollView.contentInsetAdjustmentBehavior = UIScrollViewContentInsetAdjustmentNever;
    }
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    [self scrollViewDidEndScrolling];
}

- (void)viewDidDisappear:(BOOL)animated {
    [super viewDidDisappear:animated];

    [self.secondImageView jp_stopPlay];
}


#pragma mark - UIScrollViewDelegate

- (void)scrollViewDidEndDragging:(UIScrollView *)scrollView
                  willDecelerate:(BOOL)decelerate {
    if (decelerate == NO) {
        [self scrollViewDidEndScrolling];
    }
}

- (void)scrollViewDidEndDecelerating:(UIScrollView *)scrollView{
    [self scrollViewDidEndScrolling];
}


#pragma mark - Private

- (void)scrollViewDidEndScrolling {
    CGSize referenceSize = UIScreen.mainScreen.bounds.size;
    [self.scrollView setContentOffset:CGPointMake(0, referenceSize.height) animated:NO];
    [self.secondImageView jp_stopPlay];
    [self.secondImageView jp_playVideoMuteWithURL:[self fetchDouyinURL]
                               bufferingIndicator:nil
                                     progressView:nil];
    [self.secondImageView jp_setPlayerMute:NO];
}

- (NSURL *)fetchDouyinURL {
    if(self.currentVideoIndex == (self.douyinVideoStrings.count - 1)){
       self.currentVideoIndex = 0;
    }
    NSURL *url = [NSURL URLWithString:self.douyinVideoStrings[self.currentVideoIndex]];
    self.currentVideoIndex++;
    return url;
}

- (NSArray<NSString *> *)douyinVideoStrings {
    if(!_douyinVideoStrings){
        _douyinVideoStrings = @[
                @"http://v11-dy.ixigua.com/55c1a1fd600c55efeef8b951e30c77e7/5ac73f03/video/m/2203dfce5c241324ba19a52f4aa78bd978611528ff7000012a4415e4230/",
                @"http://v3-dy.ixigua.com/d82582b6f628e9c5e69ed31de59d9fc6/5ac73e6b/video/m/220d08e6e2afc594e7a833f1d4138e8ead71151f0d9000001bda4197342/",
                @"http://v11-dy.ixigua.com/4c526ed6090db9c3639d6366e30486c6/5ac73e9e/video/m/2200051563bc67a48e3a3119e4ed8e9f3b11151fe65000024d6e26c6037/",
                @"http://v3-dy.ixigua.com/39040c63f17ffad646948d8a9caf5549/5ac73ebf/video/m/2200a790866a6b74ec9bc9a28df68394172115155740000125250ae1387/",
                @"http://v9-dy.ixigua.com/5062eb8b6f86d347b22b842f69445104/5ac73f65/video/m/220d7ce789aa7df452eb88d8b56a7aa8aad1153ff310000ceae37741d13/",
                @"http://v9-dy.ixigua.com/3974e0fc54fe8475dec4800d65e3b5cf/5ac73f8e/video/m/2203fdd9eac6ddc44f9a7c4efc3e03792971154bb610000f76db499e069/",
                @"http://v3-dy.ixigua.com/4d78b9506393f250db56cb0365c71200/5ac73fb3/video/m/220b41c09a5883f43d89411d1194efa44a9115403940000d374c3423b1e/",
                @"http://v11-dy.ixigua.com/80ca284f0b2cce24efac3408a03d1f7f/5ac74020/video/m/220d1975b23649a49d9845d98ee8af12b69115586c900002afa8a24b7ed/",
                @"http://v3-dy.ixigua.com/e993b0bdb78f6abeea6cbab667c1ecb5/5ac7405a/video/m/2205aeb8490652d4bc4bf67a54b57f4c074115567360000ae58310792cf/",
                @"http://v11-dy.ixigua.com/40d6433296273ef2422b41ee5fbbbe7b/5ac7408f/video/m/2203a11092b8a9a4f23bdb5cdbab9ce537311534c0e0000f328ec239c54/",
                @"http://v3-dy.ixigua.com/5867516a28e982bdde6b3801384ce55a/5ac740d2/video/m/22089068e1b97c54c90ab48fec9f83e493311553f8800004c07261b82fa/",
                @"http://v11-dy.ixigua.com/6bc290f0c622a48153ad8f720776c33c/5ac740e7/video/m/22007ea69bdea62463ba968cb74f13335a111550ad500006538b0d41fab/",
                @"http://v9-dy.ixigua.com/7f6c4283220342a24cf18c74312bcca8/5ac740fc/video/m/220b9124694c68e43f782fba55f54ce8187115543640000933f775dd2e0/",
                @"http://v1-dy.ixigua.com/b938fdc47add409a9c2b033a1eeae4f1/5ac74110/video/m/2201b0e8e8f18934cf4a18b9dcd5c8f9d6c1154b8c1000094805f54e808/",
                @"http://v3-dy.ixigua.com/da1596cd4f738e47d5d0633dd48212b9/5ac74137/video/m/2209372beb7431947b693ab0e26da0570c91154a9e700007917abfabb6a/"
        ];
    }
    return _douyinVideoStrings;
}


#pragma mark - Setup

- (void)setup {
    self.view.backgroundColor = [UIColor whiteColor];
    CGSize referenceSize = UIScreen.mainScreen.bounds.size;
    self.currentVideoIndex = 0;

    self.scrollView = ({
        UIScrollView *scrollView = [UIScrollView new];
        scrollView.backgroundColor = [UIColor blackColor];
        [self.view addSubview:scrollView];
        scrollView.frame = self.view.bounds;
        scrollView.contentSize = CGSizeMake(referenceSize.width, referenceSize.height * 3);
        scrollView.pagingEnabled = YES;
        scrollView.delegate = self;

        scrollView;
    });

    self.firstImageView = ({
        UIImageView *imageView = [UIImageView new];
        [self.scrollView addSubview:imageView];
        imageView.frame = CGRectMake(0, 0, referenceSize.width, referenceSize.height);

        imageView;
    });

    self.secondImageView = ({
        UIImageView *imageView = [UIImageView new];
        [self.scrollView addSubview:imageView];
        imageView.frame = CGRectMake(0, referenceSize.height, referenceSize.width, referenceSize.height);

        imageView;
    });

    self.thridImageView = ({
        UIImageView *imageView = [UIImageView new];
        [self.scrollView addSubview:imageView];
        imageView.frame = CGRectMake(0, referenceSize.height * 2, referenceSize.width, referenceSize.height);

        imageView;
    });
}

@end