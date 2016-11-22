
//
//  ADVideoPlayerCell.m
//  ADVideoPlayer
//
//  Created by 王奥东 on 16/10/9.
//  Copyright © 2016年 王奥东. All rights reserved.
//

#import "ADVideoPlayerCell.h"

@implementation ADVideoPlayerCell

- (void)awakeFromNib {
    [super awakeFromNib];
    // Initialization code
    
    
    // 处理在切换视频的短暂时间内, 当前播放视频的cell吸收了滑动事件, 如果滑动当前播放视频的cell, 会导致tableView无法接收到滑动事件, 造成tableView假死. 这个问题很简单, 因为这个容器视图只是负责显示视频的, 所以把它的userInteractionEnabled关掉就可以了
    self.containerView.userInteractionEnabled = NO;
}


@end
