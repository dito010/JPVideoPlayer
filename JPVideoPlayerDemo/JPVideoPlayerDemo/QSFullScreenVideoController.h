//
//  QSFullScreenVideoController.h
//  ComponentDemo
//
//  Created by Xuzixiang on 2018/6/15.
//  Copyright © 2018年 frankxzx. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface QSFullScreenVideoController : UIViewController

@property(nonatomic, strong) NSURL *videoURL;
@property(nonatomic, assign) CGSize playerSize;

-(void)display;

@end
