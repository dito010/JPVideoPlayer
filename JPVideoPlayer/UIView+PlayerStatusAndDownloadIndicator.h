/*
 * This file is part of the JPVideoPlayer package.
 * (c) NewPan <13246884282@163.com>
 *
 * For the full copyright and license information, please view the LICENSE
 * file that was distributed with this source code.
 *
 * Click https://github.com/Chris-Pan
 * or http://www.jianshu.com/users/e2f2d779c022/latest_articles to contact me.
 */


#import <UIKit/UIKit.h>

@interface UIView (PlayerStatusAndDownloadIndicator)

/**
 * The progress view indicator the downloading progress.
 */
@property(nonatomic, readonly, nullable)UIProgressView *progressView;

/**
 * The view to display video layer.
 */
@property(nonatomic, readonly, nullable)UIView *videoLayerView;

/**
 * Call this method to custom the tint color of progress view(@optional).
 *
 * @param tintColor a `UIColor` instance to custom the progress view tint color.
 */
-(void)perfersProgressViewColor:(UIColor * _Nonnull)tintColor;

/**
 * Call this method to custom the background color of progress view(@optional).
 *
 * @param backgroundColor a `UIColor` instance for progress view background color.
 */
-(void)perfersProgressViewBackgroundColor:(UIColor * _Nonnull)backgroundColor;

/**
 * Show the progress view for downloading progress.
 */
-(void)showProgressView;

/**
 * Hide the progress view for downloading progress.
 */
-(void)hideProgressView;

/**
 * Update the progress view's progress.
 * 
 * @param receivedSize The video data cached in disk.
 * @param expectSize  The video data total length.
 */
-(void)progressViewStatusChangedWithReceivedSize:(NSUInteger)receivedSize expectSize:(NSUInteger)expectSize;

/**
 * Show the activity indicator view for player status.
 */
-(void)showActivityIndicatorView;

/**
 * Hide tthe activity indicator view for player status.
 */
-(void)hideActivityIndicatorView;

/**
 * Set up the video layer view and indicator view.
 */
-(void)setupVideoLayerViewAndIndicatorView;

/**
 * Remove the video layer view and indicator view..
 */
-(void)removeVideoLayerViewAndIndicatorView;

@end
