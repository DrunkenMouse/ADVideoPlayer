//
//  ADDownloadManager.h
//  ADVideoPlayer
//
//  Created by 王奥东 on 16/10/9.
//  Copyright © 2016年 王奥东. All rights reserved.
//

/// 这个类的功能是从网络请求数据，并把数据保存到本地的一个临时文件，网络请求结束的时候，如果数据完整，则把数据缓存到指定的路径，不完整就删除


#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>
@class ADDownloadManager;


@protocol ADDownloadManagerDelegate <NSObject>

@optional

///开始下载数据(包括长度和类型)
-(void)manager:(ADDownloadManager *)manager didReceiveVideoLength:(NSUInteger)ideoLength mimeType:(NSString *)mimeType;

///完成下载
-(void)didFinishLoadingWithManager:(ADDownloadManager *)manager fileSavePath:(NSString *)filePath;

///下载失败(错误码)
-(void)didFailLoadingWithManager:(ADDownloadManager *)manager WithError:(NSError *)errorCode;

///已经存在下载好的这个文件了
-(void)manager:(ADDownloadManager *)manager fileExistedWithPath:(NSString *)filePath;

///正在下载
-(void)manager:(ADDownloadManager *)manager didReceiveData:(NSData *)data downloadOffset:(NSInteger)offset tempFilePath:(NSString *)filePath;


@end

//// 存储路径，用户沙盒的Cache目录中
static NSString *ad_tempPath = @"/ADVideoPlayer_temp";
static NSString *ad_savePath = @"/ADVideoPlayer_save";

@interface ADDownloadManager : NSObject

/**
 * The url of network file
 * 要下载的文件的URL
 */
@property (nonatomic, strong, readonly) NSURL *url;

/**
 * The value of start download position
 * 下载位置的偏移量
 */
@property (nonatomic, readonly) NSUInteger offset;

/**
 * The total length of file
 * 文件总长度
 */
@property (nonatomic, readonly) NSUInteger fileLength;

/**
 * The current length of downloaded file
 * 当前下载了的文件的偏移量
 */
@property (nonatomic, readonly) NSUInteger downLoadingOffset;

/**
 * The mimeType of the downloading file
 * mineType 类型
 */
@property (nonatomic, strong, readonly) NSString *mimeType;

/**
 * Query is finished download
 * 查询是否已经下载完成
 */
@property (nonatomic, assign) BOOL isFinishLoad;

/**
 * To be the delegate, It can pass the statu of download by Delegate-Method
 * @see JPDownloadManagerDelegate
 * 成为代理, 就能获得下载状态
 */
@property (nonatomic, weak) id<ADDownloadManagerDelegate> delegate;

/**
 * It be used to save data as temporary file when requesting data from network
 * It also can auto move temporary file to the path you assigned when the temporary file is a complete file (mean that the length of temporary file is equal to the file in network) after request finished or canceled
 * And it will delete the temporary file if the temporary file is not a complete file after request finish or cancel
 * 传递要下载的文件的URL和下载初始偏移量, 这个方法功能是从网络请求数据，并把数据保存到本地的一个临时文件.
 * 当网络请求结束或取消的时候，如果数据完整，则把数据缓存到指定的路径，不完整就删除
 * @param url       The url of network file
 * @param offset    The value of start download position, it can be 0
 */
-(void)setUrl:(NSURL *)url offset:(NSUInteger)offset;

/**
 * Cancel current download task
 * 取消当前下载进程
 */
-(void)cancel;


@end
