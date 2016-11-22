//
//  ADVideoURLAssetResourceLoader.h
//  ADVideoPlayer
//
//  Created by 王奥东 on 16/10/9.
//  Copyright © 2016年 王奥东. All rights reserved.
//
/// 这个connenction的功能是把task缓存到本地的临时数据根据播放器需要的 offset和length去取数据并返回给播放器
#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>

@class ADDownloadManager;

@protocol  ADVideoURLAssetResourceLoaderDelegate <NSObject>
@optional
///完成下载
-(void)didFinishLoadingWithManager:(ADDownloadManager *)manager fileSavePath:(NSString *)filePath;

///下载失败(错误码)
-(void)didFailLoadingWithManager:(ADDownloadManager *)manager WithError:(NSError *)errorCode;

///已经存在下载好的这个文件了
-(void)manager:(ADDownloadManager *)manager fileExistedWithPath:(NSString *)filePath;

@end

@interface ADVideoURLAssetResourceLoader : NSObject<AVAssetResourceLoaderDelegate>
/**
 * To be the delegate, It can pass the statu of download by Delegate-Method
 * @see JPVideoURLAssetResourceLoaderDelegate
 * 成为代理, 就能获得下载状态
 */
@property (nonatomic, weak) id<ADVideoURLAssetResourceLoaderDelegate>delegate;

/**
 * This method be used to re-scheme the url, it use on fixing the scheme from other to "streaming", then through change request strategies, will be of huge capacity to piecewise continuous media data, divided into numerous small files for transfer.
 * NSURLComponents用来替代NSMutableURL，可以readwrite修改URL，这里通过更改请求策略，将容量巨大的连续媒体数据进行分段，分割为数量众多的小文件进行传递。采用了一个不断更新的轻量级索引文件来控制分割后小媒体文件的下载和播放，可同时支持直播和点播
 * @param url   Request url
 * @return      Fixed url
 */
-(NSURL *)getSchemeVideoURL:(NSURL *)url;

@end
