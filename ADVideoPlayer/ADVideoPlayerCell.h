//
//  ADVideoPlayerCell.h
//  ADVideoPlayer
//
//  Created by 王奥东 on 16/10/9.
//  Copyright © 2016年 王奥东. All rights reserved.
//

#import <UIKit/UIKit.h>

// 播放滑动不可及cell的类型
typedef NS_ENUM(NSUInteger, PlayUnreachCellStyle) {
    PlayUnreachCellStyleUp = 1, //顶部不可及
    PlayUnreachCellStyleDown = 2, //底部不可及
    PlayUnreachCellStyleNone = 3 //播放滑动可及cell
};

@interface ADVideoPlayerCell : UITableViewCell

@property (nonatomic, weak) IBOutlet UIView *containerView;

/** videoPath */
@property(nonatomic, strong)NSString *videoPath;

/** indexPath */
@property(nonatomic, strong)NSIndexPath *indexPath;

/** cell类型 */
@property(nonatomic, assign)PlayUnreachCellStyle cellStyle;

@end
