//
//  JPVideoPlayerWeiBoUnequalHeightCell.m
//  JPVideoPlayerDemo
//
//  Created by NewPan on 2018/4/6.
//  Copyright © 2018年 NewPan. All rights reserved.
//

#import "JPVideoPlayerWeiBoUnequalHeightCell.h"

@interface JPVideoPlayerWeiBoUnequalHeightCell()

@end

@implementation JPVideoPlayerWeiBoUnequalHeightCell

- (void)setIndexPath:(NSIndexPath *)indexPath{
    _indexPath = indexPath;
    
    if (indexPath.row % 2) {
        self.videoPlayView.image = [UIImage imageNamed:@"placeholder1"];
    }
    else{
        self.videoPlayView.image = [UIImage imageNamed:@"placeholder2"];
    }
}

@end
