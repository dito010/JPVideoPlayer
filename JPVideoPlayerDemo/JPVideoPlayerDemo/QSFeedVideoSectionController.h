//
//  QSFeedVideoSectionController.h
//  QS
//
//  Created by Xuzixiang on 2018/6/29.
//  Copyright © 2018年 frankxzx. All rights reserved.
//

#import <IGListKit/IGListKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface FeedModel : NSObject <IGListDiffable, NSCopying>

@property (nonatomic, copy) NSString *videoURL;
@property (nonatomic, copy) NSString *photoThumbnail;
@property (nonatomic, copy) NSString *videoThumbnail;

@end


@interface QSFeedVideoSectionController : IGListSectionController

@end

NS_ASSUME_NONNULL_END
