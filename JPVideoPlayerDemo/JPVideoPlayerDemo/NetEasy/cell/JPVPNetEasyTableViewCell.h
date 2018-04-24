//
//  JPVPNetEasyTableViewCell.h
//  JPVideoPlayerDemo
//
//  Created by Memet on 2018/4/24.
//  Copyright © 2018 NewPan. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface JPVPNetEasyTableViewCell : UITableViewCell

@property (nonatomic,copy) void (^PlayBtnClicked)(void);
@property (weak, nonatomic) IBOutlet UIImageView *videoPlayView;

@end
