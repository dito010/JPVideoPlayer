//
//  JPVideoPlayerControlViews.m
//  JPVideoPlayerDemo
//
//  Created by NewPan on 2018/2/20.
//  Copyright © 2018年 NewPan. All rights reserved.
//

#import "JPVideoPlayerControlViews.h"

@interface JPVideoPlayerProgressView()

/**
 * Download progress indicator layer.
 */
@property(nonatomic, strong)CALayer *downloadLayer;

/**
 * Playing progress indicator layer.
 */
@property(nonatomic, strong)CALayer *playingLayer;

/**
 * The download progress value.
 */
@property(nonatomic, assign, readwrite)CGFloat downloadProgressValue;

/**
 * The playing progress value.
 */
@property(nonatomic, assign, readwrite)CGFloat playingProgressValue;

@end

@implementation JPVideoPlayerProgressView

- (instancetype)init{
    self = [super init];
    if (self) {
        self.backgroundColor = [UIColor colorWithRed:22.0/255.0 green:30.0/255.0 blue:37.0/255.0 alpha:0.8];
    }
    return self;
}


#pragma mark - Public

- (void)setDownloadProgress:(CGFloat)downloadProgress{
    if (downloadProgress<0 || downloadProgress > 1) {
        return;
    }
    _downloadProgressValue = downloadProgress;
    [self addIndicatorLayerOnce];
    [self refreshProgressWithProgressVaule:downloadProgress forLayer:self.downloadLayer];
}

- (void)setPlayingProgress:(CGFloat)playingProgress{
    if (playingProgress<0 || playingProgress > 1) {
        return;
    }
    _playingProgressValue = playingProgress;
    [self addIndicatorLayerOnce];
    [self refreshProgressWithProgressVaule:playingProgress forLayer:self.playingLayer];
}

- (void)perfersPlayingProgressViewColor:(UIColor *)color{
    if (color != nil) {
        self.playingLayer.backgroundColor = color.CGColor;
    }
}

- (void)perfersDownloadProgressViewColor:(UIColor *)color{
    if (color != nil) {
        self.downloadLayer.backgroundColor = color.CGColor;
    }
}

- (void)refreshProgressViewForScreenEvents{
    [self refreshProgressWithProgressVaule:_downloadProgressValue forLayer:_downloadLayer];
    [self refreshProgressWithProgressVaule:_playingProgressValue forLayer:_playingLayer];
}


#pragma mark - Private

- (void)refreshProgressWithProgressVaule:(CGFloat)progressValue forLayer:(CALayer *)layer{
    CGRect frame = layer.frame;
    frame.size.width = self.bounds.size.width  * progressValue;
    layer.frame = frame;
}

- (void)addIndicatorLayerOnce{
    if (!self.downloadLayer.superlayer) {
        self.downloadLayer.frame = CGRectMake(0, 0, 0, self.bounds.size.height);
        [self.layer addSublayer:self.downloadLayer];
    }
    
    if (!self.playingLayer.superlayer) {
        self.playingLayer.frame = CGRectMake(0, 0,  0, self.bounds.size.height);
        [self.layer addSublayer:self.playingLayer];
    }
}

- (CALayer *)downloadLayer{
    if (!_downloadLayer) {
        _downloadLayer = [CALayer new];
        _downloadLayer.backgroundColor = [UIColor colorWithRed:196.0/255.0 green:193.0/255.0 blue:195.0/255.0 alpha:0.8].CGColor;
    }
    return _downloadLayer;
}

- (CALayer *)playingLayer{
    if (!_playingLayer) {
        _playingLayer = [CALayer new];
        _playingLayer.backgroundColor = self.tintColor.CGColor;
    }
    return _playingLayer;
}

@end

CGFloat const JPVideoPlayerActivityIndicatorWH = 46;

@interface JPVideoPlayerActivityIndicator()

@property(nonatomic, strong, nullable)UIActivityIndicatorView *activityIndicator;

@property(nonatomic, strong, nullable)UIVisualEffectView *blurView;

@property(nonatomic, assign, getter=isAnimating)BOOL animating;

@end

@implementation JPVideoPlayerActivityIndicator

- (instancetype)init{
    self = [super init];
    if (self) {
        [self setup_];
    }
    return self;
}

- (void)layoutSubviews{
    [super layoutSubviews];
    
    self.blurView.frame = self.bounds;
    self.activityIndicator.frame = self.bounds;
}


#pragma mark - Public

- (void)startAnimating{
    if (!self.isAnimating) {
        self.hidden = NO;
        [self.activityIndicator startAnimating];
        self.animating = YES;
    }
}

- (void)stopAnimating{
    if (self.isAnimating) {
        self.hidden = YES;
        [self.activityIndicator stopAnimating];
        self.animating = NO;
    }
}


#pragma mark - Private

- (void)setup_{
    self.backgroundColor = [UIColor clearColor];
    self.layer.cornerRadius = 8;
    self.clipsToBounds = YES;
    
    UIVisualEffectView *blurView = [[UIVisualEffectView alloc]initWithEffect:[UIBlurEffect effectWithStyle:UIBlurEffectStyleLight]];
    [self addSubview:blurView];
    self.blurView = blurView;
    
    UIActivityIndicatorView *indicator = [UIActivityIndicatorView new];
    indicator.activityIndicatorViewStyle = UIActivityIndicatorViewStyleGray;
    indicator.color = [UIColor colorWithRed:35.0/255 green:35.0/255 blue:35.0/255 alpha:1];
    [self addSubview:indicator];
    self.activityIndicator = indicator;
    
    self.animating = NO;
}

@end
