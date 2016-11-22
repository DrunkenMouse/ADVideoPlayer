//
//  ADVideoPlayer.m
//  ADVideoPlayer
//
//  Created by 王奥东 on 16/10/9.
//  Copyright © 2016年 王奥东. All rights reserved.
//



#import "ADVideoPlayer.h"
#import "ADVideoURLAssetResourceLoader.h"
#import "ADDownloadManager.h"


@interface ADVideoPlayer()<ADVideoURLAssetResourceLoaderDelegate>

///数据源
@property(nonatomic, strong)ADVideoURLAssetResourceLoader *resourceLoader;

///asset
@property(nonatomic, strong)AVURLAsset *videoURLAsset;

///当前正在播放的Item
@property(nonatomic, strong)AVPlayerItem *currentPlayerItem;

///当前图像层
@property(nonatomic, strong)AVPlayerLayer *currentPlayerLayer;

/**
 * The view of video will play on
 * 视频图像载体View
 */
@property(nonatomic, weak)UIView *showView;

///播放视频源的url
@property(nonatomic, strong)NSURL *playPathURL;

///player
@property(nonatomic, strong)AVPlayer *player;

@end



@implementation ADVideoPlayer

#pragma mark --------------------------------------------------
#pragma mark INITIALIZER


/**
    alloc 就是调用allocWithZone
    为了避免手动调用allocWithZone生成对象，故将单列生成放在allocWithZone中
 */
+(instancetype)sharedInstance {
    
    return [[self alloc] init];
}

+(instancetype)allocWithZone:(struct _NSZone *)zone {
    static id _shareInstace;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _shareInstace = [super allocWithZone:zone];
    });
    return _shareInstace;
}

-(instancetype)init{
    self = [super init];
    
    if (self) {
        
        _stopWhenAppDidEnterBackground = YES;
        
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(appDidEnterBackground) name:UIApplicationWillResignActiveNotification object:nil];
        
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(appDidEnterPlayGround) name:UIApplicationDidBecomeActiveNotification object:nil];
        
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(playerItemDidPlayToEnd:) name:AVPlayerItemDidPlayToEndTimeNotification object:nil];
        
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(receiveMemoryWarning) name:UIApplicationDidReceiveMemoryWarningNotification object:nil];
        
    }
    return self;
}

-(void)dealloc{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

#pragma mark --------------------------------------------------
#pragma mark Public

#pragma mark - 继续
-(void)resume{
    if (!self.currentPlayerItem) {
        return;
    }
    [self.player play];
}

#pragma mark - 暂停
-(void)pause{
    if (!self.currentPlayerItem) {
        return;
    }
    [self.player pause];
}

#pragma mark - 停止
-(void)stop{
    if (!self.currentPlayerItem) {
        return;
    }
    [self.player pause];
    [self.player cancelPendingPrerolls];
    if (self.currentPlayerLayer) {
        [self.currentPlayerLayer removeFromSuperlayer];
        self.currentPlayerLayer = nil;
    }
    self.currentPlayerItem = nil;
    self.player = nil;
    self.playPathURL = nil;
}

#pragma mark - 静音
-(void)setMute:(BOOL)mute{
    _mute = mute;
    self.player.muted = mute;
}


#pragma mark - 设置视频URL 与 要展示的View
-(void)playWithUrl:(NSURL *)url showView:(UIView *)showView{
    
    self.playPathURL = url;
    _showView = showView;
    
    //释放之前的配置
    [self stop];
    
    //将播放器请求数据的代理设为缓存中间区
    //也就是请求数据的类的代理对象设为self
    ADVideoURLAssetResourceLoader *resourceLoader = [ADVideoURLAssetResourceLoader new];
    self.resourceLoader = resourceLoader;
    resourceLoader.delegate = self;
    
    NSURL *playUrl = [resourceLoader getSchemeVideoURL:url];
    AVURLAsset *videoURLAsset = [AVURLAsset URLAssetWithURL:playUrl options:nil];
    self.videoURLAsset = videoURLAsset;
    
    [self.videoURLAsset.resourceLoader setDelegate:resourceLoader queue:dispatch_get_main_queue()];
    
    AVPlayerItem *playerItem = [AVPlayerItem playerItemWithAsset:videoURLAsset];
    self.currentPlayerItem = playerItem;
    
    //每次都重新创建播放器
    //防止莫名重播10次会假死的Bug
    self.player = [AVPlayer playerWithPlayerItem:playerItem];
    self.currentPlayerLayer = [AVPlayerLayer playerLayerWithPlayer:self.player];
    self.currentPlayerLayer.frame = CGRectMake(0, 0, showView.bounds.size.width, showView.bounds.size.height);
    
}

#pragma mark -----------------------------------------
#pragma mark Observer

#pragma mark - 收到内存警告
-(void)receiveMemoryWarning{
    NSLog(@"内存警告");
    //停止播放
    [self stop];
}


#pragma mark - 进到后台
-(void)appDidEnterBackground{
    if (self.stopWhenAppDidEnterBackground) {
        [self pause];
    }
}

#pragma mark - 从后台返回
-(void)appDidEnterPlayGround{
    [self resume];
}


#pragma marl - 播放结束
-(void)playerItemDidPlayToEnd:(NSNotification *)notification{
    //重复播放, 从起点开始重播, 没有内存暴涨
    __weak typeof(self) weak_self = self;
    
    [self.player seekToTime:CMTimeMake(0, 1) completionHandler:^(BOOL finished) {
        __strong typeof(weak_self) strong_self = weak_self;
        if (!strong_self) {
            return ;
        }
        [strong_self.player play];
    }];
    
}

#pragma mark - 只有准备完毕后才可以播放
-(void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary<NSString *,id> *)change context:(void *)context{
    if ([keyPath isEqualToString:@"status"]) {
        AVPlayerItem *playerItem = (AVPlayerItem *)object;
        AVPlayerItemStatus status = playerItem.status;
        switch (status) {
            case AVPlayerItemStatusUnknown:
            {
                
            }
                break;
            //准备开始播放
            case AVPlayerItemStatusReadyToPlay:{
                [self.player play];
                self.player.muted = self.mute;
                //显示图像逻辑
                [self handleShowViewSublayers];
            }
                break;
                
            case AVPlayerItemStatusFailed:{
                
            }
                break;
                
            default:
                break;
        }
    }
}

#pragma mark -----------------------------------------
#pragma mark Private

#pragma mark - 显示图像逻辑
-(void)handleShowViewSublayers{
    
    //先隐藏要显示图像的View，隐藏完后并移除显示层
    //而后添加新的显示层并显示View
    [UIView animateWithDuration:0.4 animations:^{
        _showView.alpha = 0;
    } completion:^(BOOL finished) {
        for (CALayer *layer in _showView.subviews) {
            [layer removeFromSuperlayer];
        }
        //添加视图
        [_showView.layer addSublayer:self.currentPlayerLayer];
        
        [UIView animateWithDuration:0.5 animations:^{
            _showView.alpha = 1;
            
        } completion:nil];
    }];
}

#pragma mark - 设置播放的数据
-(void)setCurrentPlayerItem:(AVPlayerItem *)currentPlayerItem{
    //如果之前有数据，则先移除数据的监听者
    if (_currentPlayerItem) {
        [_currentPlayerItem removeObserver:self forKeyPath:@"status"];
    }
    //保存播放的数据
    _currentPlayerItem = currentPlayerItem;
    //添加监听
    [_currentPlayerItem addObserver:self forKeyPath:@"status" options:NSKeyValueObservingOptionNew context:nil];
}

#pragma mark - 设置播放图层
-(void)setCurrentPlayerLayer:(AVPlayerLayer *)currentPlayerLayer{
    //移除旧的播放图层保存新的播放图层
    if (_currentPlayerLayer) {
        [_currentPlayerLayer removeFromSuperlayer];
    }
    _currentPlayerLayer = currentPlayerLayer;
}

#pragma mark -----------------------------------------
#pragma mark JPLoaderURLConnectionDelegate

#pragma mark - 检测文件已经存在
-(void)manager:(ADDownloadManager *)manager fileExistedWithPath:(NSString *)filePath{
//    NSLog(@"文件已存在，从本地读取播放.由downloadManager传消息给代理ADVideoURLAssetResourceLoader，再由ADVideoURLAssetResourceLoader传消息给代理ADVideoPlayer");
    
    //释放之前的配置
    [self stop];
    
    //直接从本地读取数据进行播放
    NSURL *playPathURL = [NSURL fileURLWithPath:filePath];
    AVURLAsset *videoURLAsset = [AVURLAsset URLAssetWithURL:playPathURL options:nil];
    AVPlayerItem *playerItem = [AVPlayerItem playerItemWithAsset:videoURLAsset];
    self.currentPlayerItem = playerItem;
    
    self.player = [AVPlayer playerWithPlayerItem:playerItem];
    self.currentPlayerLayer = [AVPlayerLayer playerLayerWithPlayer:self.player];
    self.currentPlayerLayer.frame = CGRectMake(0, 0, _showView.bounds.size.width, _showView.bounds.size.height);
    
}


-(void)didFailLoadingWithManager:(ADDownloadManager *)manager WithError:(NSError *)errorCode{
//    NSLog(@"下载失败");
}

-(void)didFinishLoadingWithManager:(ADDownloadManager *)manager fileSavePath:(NSString *)filePath{
//    NSLog(@"下载完成");
}

@end