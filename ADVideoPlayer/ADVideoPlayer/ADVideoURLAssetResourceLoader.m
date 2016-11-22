//
//  ADVideoURLAssetResourceLoader.m
//  ADVideoPlayer
//
//  Created by 王奥东 on 16/10/9.
//  Copyright © 2016年 王奥东. All rights reserved.
//
//

#import "ADVideoURLAssetResourceLoader.h"
#import <MobileCoreServices/MobileCoreServices.h>
#import "ADDownloadManager.h"

@interface ADVideoURLAssetResourceLoader()<ADDownloadManagerDelegate>
///下载器
@property(nonatomic, strong) ADDownloadManager *manager;

///请求队列
@property(nonatomic, strong) NSMutableArray *pendingRequests;

///视频路径
@property(nonatomic, strong) NSString *videoPath;

///文件名
@property(nonatomic, strong) NSString *suggestFileName;

@end


@implementation ADVideoURLAssetResourceLoader

-(instancetype)init {
    self = [super init];
    if (self) {
        _pendingRequests = [NSMutableArray array];
    }
    return self;
}

#pragma mark -------------------------------
#pragma mark publish

#pragma mark - 将要下载的数据分割成小块进行下载并保存视频路径
-(NSURL *)getSchemeVideoURL:(NSURL *)url {
    // NSURLComponents用来替代NSMutableURL，可以readwrite修改URL，这里通过更改请求策略，将容量巨大的连续媒体数据进行分段，分割为数量众多的小文件进行传递。采用了一个不断更新的轻量级索引文件来控制分割后小媒体文件的下载和播放，可同时支持直播和点播
    NSURLComponents *components = [[NSURLComponents alloc] initWithURL:url resolvingAgainstBaseURL:NO];
    //scheme为streaming，代表将要下载的数据分割成小块进行下载
    components.scheme = @"streaming";
    
    //获取并保存视频路径
    NSString *path = [NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES).lastObject stringByAppendingString:ad_tempPath];
    NSString *suggestFileName = [[url absoluteString] lastPathComponent];
    path = [path stringByAppendingPathComponent:suggestFileName];
    
    //获取并保存视频路径
    _videoPath = path;
    
    return [components URL];
}

#pragma mark -----------------------------------------
#pragma mark AVAssetResourceLoaderDelegate

/**
 *  必须返回Yes，如果返回NO，则resourceLoader将会加载出现故障的数据
 *  这里会出现很多个loadingRequest请求， 需要为每一次请求作出处理
 *  @param resourceLoader 资源管理器
 *  @param loadingRequest 每一小块数据的请求
 *
 */

#pragma mark - 获取到每次的请求
-(BOOL)resourceLoader:(AVAssetResourceLoader *)resourceLoader shouldWaitForLoadingOfRequestedResource:(AVAssetResourceLoadingRequest *)loadingRequest{
    //保存请求
    [self.pendingRequests addObject:loadingRequest];
    //需要时修改请求范围
    [self dealLoadingRequest:loadingRequest];
    
    return YES;
}

#pragma mark - 请求结束,将请求移除
-(void)resourceLoader:(AVAssetResourceLoader *)resourceLoader didCancelLoadingRequest:(AVAssetResourceLoadingRequest *)loadingRequest{
  
    [self.pendingRequests removeObject:loadingRequest];
}

#pragma mark -----------------------------------------
#pragma mark Private

#pragma mark - 需要时修改请求范围
-(void)dealLoadingRequest:(AVAssetResourceLoadingRequest *)loadingRequest{
    
    NSURL *interceptedURL = [loadingRequest.request URL];
    
    long long loc = (NSUInteger)loadingRequest.dataRequest.currentOffset;
    
    //如果下载管理器存在
    if (self.manager) {
        //如果下载的有数据
        if (self.manager.downLoadingOffset > 0) {
            //让请求响应已经缓存的数据并移除已经完成的
            [self processPendingRequests];
        }
        //如果新的请求的起始位置比当前缓存的位置还大300k，则重新按照range请求数据
        //通常出现在快进的时候
        if (self.manager.offset + self.manager.downLoadingOffset + 1024*300 < loc) {
            
            [self.manager setUrl:interceptedURL offset:loc];
        }
    }
    else {
        self.manager = [ADDownloadManager new];
        self.manager.delegate = self;
        [self.manager setUrl:interceptedURL offset:0];
    }
}

#pragma mark - 让请求响应已经缓存的数据并移除已经完成的
-(void)processPendingRequests{
    
    // Enumerate all loadingRequest
    // For every singal loadingRequest, combine response-data length and file mimeType
    // Then judge the download file data is contain the loadingRequest's data or not, if Yes, take out the request's data and return to loadingRequest, next to colse this loadingRequest. if No, continue wait for download finished.
    // 遍历所有的请求, 为每个请求加上请求的数据长度和文件类型等信息.
    // 在判断当前下载完的数据长度中有没有要请求的数据, 如果有,就把这段数据取出来,并且把这段数据填充给请求, 然后关闭这个请求
    // 如果没有, 继续等待下载完成.
    
    NSMutableArray *requestsCompleted = [NSMutableArray array]; //请求完成的数组
    
    //每下载一块数据都是一次请求，把这些请求放到数组，遍历数组
    for (AVAssetResourceLoadingRequest *loadingRequest in self.pendingRequests) {
        //对每次请求加上长度，文件类型等信息
        [self fillInContentInformation:loadingRequest.contentInformationRequest];
        
        //判断此次请求的数据是否处理完全
        BOOL didRespondCompletely = [self respondWithDataForRequest:loadingRequest.dataRequest];
        
        // 如果完整，把这段数据取出来,并且把这段数据填充给请求, 然后关闭这个请求
        // 在respondWithDataForRequest方法内部就响应了
        if (didRespondCompletely) {
            [requestsCompleted addObject:loadingRequest];
            [loadingRequest finishLoading];
        }
    }
    //在所有请求的数组中移除已经完成的
    [self.pendingRequests removeObjectsInArray:[requestsCompleted copy]];
}

#pragma mark - 判断此次请求的数据是否处理完全
-(BOOL)respondWithDataForRequest:(AVAssetResourceLoadingDataRequest *)dataRequest{
    
    //请求起始点
    long long startOffset = dataRequest.requestedOffset;
    
    //当前请求偏移量不为0
    if (dataRequest.currentOffset != 0) {
        //起始点 = 当前请求偏移量
        startOffset = dataRequest.currentOffset;
    }
    
    
    //获取缓存的data数据
    NSData *fileData = [NSData dataWithContentsOfFile:_videoPath options:NSDataReadingMappedIfSafe error:nil];
    
    //没有读取的已下载数据 = 当前下载器下载了的文件的偏移量 - 下载器的下载位置的偏移量 - 当前请求起始点
    NSInteger unreadBytes = self.manager.downLoadingOffset - self.manager.offset - (NSInteger)startOffset;
    
    //已下载的可响应的字节 = 数据的请求长度 与 没有读取的已下载数据 的最小值
    NSUInteger numberOfBytesToRespondWith = MIN((NSUInteger)dataRequest.requestedLength, unreadBytes);
    
    //让请求去响应缓存的数据
    //数据为，从 请求起始点 - 下载器的下载位置的偏移量  到 已下载的可响应的字节
    [dataRequest respondWithData:[fileData subdataWithRange:NSMakeRange((NSUInteger)startOffset-self.manager.offset, (NSUInteger)numberOfBytesToRespondWith)]];

    //结束位置 = 此次请求的起始点 + 数据的请求长度
    long long endOffset = startOffset + dataRequest.requestedLength;
    
    //下载器的下载位置的偏移量 + 当前下载器下载了的文件的偏移量 >= 结束位置
    BOOL didRespondFully = (self.manager.offset + self.manager.downLoadingOffset) >= endOffset;

    return didRespondFully;
    
}

#pragma mark - 对每次请求加上长度，文件类型等信息
-(void)fillInContentInformation:(AVAssetResourceLoadingContentInformationRequest *)contentInformationRequest {
    NSString *mimetype = self.manager.mimeType;
    CFStringRef contentType = UTTypeCreatePreferredIdentifierForTag(kUTTagClassMIMEType, (__bridge CFStringRef _Nonnull)(mimetype),NULL);
    contentInformationRequest.byteRangeAccessSupported = YES;
    contentInformationRequest.contentType = CFBridgingRelease(contentType);
    contentInformationRequest.contentLength = self.manager.fileLength;
}

#pragma mark -----------------------------------------
#pragma mark JPDownloadManagerDelegate

#pragma mark - 已经存在下载好的这个文件了
-(void)manager:(ADDownloadManager *)manager fileExistedWithPath:(NSString *)filePath{
    
    //移除所有请求
    [self.pendingRequests enumerateObjectsUsingBlock:^(id  _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        [obj finishLoading];
        [self.pendingRequests removeObject:obj];
    }];
    
    if ([self.delegate respondsToSelector:@selector(manager:fileExistedWithPath:)]) {
        [self.delegate manager:manager fileExistedWithPath:filePath];
    }
    
}

#pragma mark - 开始下载
-(void)manager:(ADDownloadManager *)manager didReceiveVideoLength:(NSUInteger)ideoLength mimeType:(NSString *)mimeType{
    //什么也不做
}

#pragma mark - 正在下载
-(void)manager:(ADDownloadManager *)manager didReceiveData:(NSData *)data downloadOffset:(NSInteger)offset tempFilePath:(NSString *)filePath{
     //让请求响应已经缓存的数据并移除已经完成的
    [self processPendingRequests];
}

#pragma mark - 完成下载
-(void)didFinishLoadingWithManager:(ADDownloadManager *)manager fileSavePath:(NSString *)filePath{
    // File download success, and the downloaded file be auto move to cache path, so must change the _videoPath from temporary path to cache path
    // 此时文件下载完成, 已经将临时文件存储到filePath中了, 所以需要调转获取视频数据的路径到存储完整视频的路径
    _videoPath = filePath;
    if ([self.delegate respondsToSelector:@selector(didFinishLoadingWithManager:fileSavePath:)]) {
        [self.delegate didFinishLoadingWithManager:manager fileSavePath:filePath];
    }
}

#pragma mark - 下载失败
-(void)didFailLoadingWithManager:(ADDownloadManager *)manager WithError:(NSError *)errorCode {
    if ([self.delegate respondsToSelector:@selector(didFailLoadingWithManager:WithError:)]) {
        [self.delegate didFailLoadingWithManager:manager WithError:errorCode];
    }
}

@end