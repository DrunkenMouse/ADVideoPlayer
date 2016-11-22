//
//  ADDownloadManager.m
//  ADVideoPlayer
//
//  Created by 王奥东 on 16/10/9.
//  Copyright © 2016年 王奥东. All rights reserved.
//


#import "ADDownloadManager.h"


@interface ADDownloadManager()<NSURLSessionDataDelegate>

@property (nonatomic, strong) NSURL *url;

@property (nonatomic, assign) long long curOffset;
//下载的文件的长度
@property (nonatomic) NSUInteger fileLength;

@property (nonatomic, strong) NSString *mimeType;

@property (nonatomic, strong) NSURLSession *session;

@property (nonatomic, assign) NSUInteger downLoadingOffset;

//网络超时，重连一次。用于判断是否是第一次重连
@property (nonatomic, assign) BOOL once;

@property (nonatomic, strong) NSOutputStream *outputStream;

//缓存存储路径
@property (nonatomic, strong) NSString *tempPath;

///文件名
@property (nonatomic, strong) NSString *suggestFileName;

@end

@implementation ADDownloadManager

#pragma mark ---------------------------
#pragma mark Public

#pragma mark - 关闭下载器
-(void)cancel{
    [self.session invalidateAndCancel];
}

#pragma mark - 设置视频的请求地址与请求偏移位置
-(void)setUrl:(NSURL *)url offset:(long long)offset{
    _url = url;
    _curOffset = offset;
    _downLoadingOffset = 0;
    
    //检查有没有缓存
    NSString *urlString = [url absoluteString];
    self.suggestFileName = [urlString lastPathComponent];
    
    NSFileManager *manager = [NSFileManager defaultManager];
    NSString *savePath = [self fileSavePath];
    savePath = [savePath stringByAppendingPathComponent:self.suggestFileName];
  
    
    if ([manager fileExistsAtPath:savePath]) {
        //已经存在这个下载好的文件了,返回文件地址
        if ([self.delegate respondsToSelector:@selector(manager:fileExistedWithPath:)]) {
            [self.delegate manager:self fileExistedWithPath:savePath];
        }
        return;
    }
    
    //不存在下载好的就去下载
    [self startLoading];
   
    
}

-(void)startLoading {
    
    
    //替代NSMutableURL,可以动态修改scheme
    //如果resolve是YES，则url通过[url absoluteURL]使用
    //如果url不正确，则返回nil
    NSURLComponents *actualUrlComponents = [[NSURLComponents alloc] initWithURL:_url resolvingAgainstBaseURL:NO];
    actualUrlComponents.scheme = @"http";
    
    //创建请求
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:[actualUrlComponents URL]cachePolicy:NSURLRequestReloadIgnoringCacheData timeoutInterval:20.0];
    
    //修改请求数据范围
    if (_curOffset > 0 && self.fileLength > 0) {
        [request addValue:[NSString stringWithFormat:@"bytes=%ld-%ld",(unsigned long)_curOffset, (unsigned long)self.fileLength - 1] forHTTPHeaderField:@"Range"];
    }

    //重置,就是使session无效并关闭
    [self.session invalidateAndCancel];
    
    //创建Session,并设置代理
    self.session = [NSURLSession sessionWithConfiguration:[NSURLSessionConfiguration defaultSessionConfiguration] delegate:self delegateQueue:[NSOperationQueue mainQueue]];
    
    //创建会话对象
    NSURLSessionDataTask *dataTask = [self.session dataTaskWithRequest:request];
    
    //开始下载
    [dataTask resume];
}

#pragma mark --------------------------------------------------
#pragma mark NSURLSessionDataDelegate

// 1.接收到服务器响应的时候
-(void)URLSession:(NSURLSession *)session dataTask:(NSURLSessionDataTask *)dataTask didReceiveResponse:(NSURLResponse *)response completionHandler:(void (^)(NSURLSessionResponseDisposition))completionHandler {
    
//    NSLog(@"开始下载");
    
    _isFinishLoad = NO;
    _mimeType = @"video/mp4";
    
    // 拼接临时文件存储路径
    self.tempPath = [self fileCachePath];
    
    //获得当前要下载文件的总长度
    //如果响应头里有文件长度数据, 就取这个长度; 如果没有, 就取代理方法返回给我们的长度
    NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse *)response;
    NSDictionary *dic = (NSDictionary *)[httpResponse allHeaderFields];
    NSString *content = [dic valueForKey:@"Content - Range"];
    NSArray *array = [content componentsSeparatedByString:@"/"];
    NSString *length = array.lastObject;
    
    NSUInteger fileLength;
    if ([length integerValue] == 0) {
        
        fileLength = (NSUInteger)httpResponse.expectedContentLength;
    }else {
        fileLength = [length integerValue];
    }
    
    //设置文件的总大小与文件类型
    self.fileLength = fileLength;
    
    //开始下载数据(包括长度和类型)
    if ([self.delegate respondsToSelector:@selector(manager:didReceiveVideoLength:mimeType:)]) {
        [self.delegate manager:self didReceiveVideoLength:self.fileLength mimeType:self.mimeType];
    }
    
    //开启输出管道并允许持续添加
    self.outputStream = [[NSOutputStream alloc] initToFileAtPath:_tempPath append:YES];
    [self.outputStream open];
    
    //通过该回调告诉系统是否要继续接收服务器返回给我们的数据
    //NSURLSessionResponseAllow == 接收
    completionHandler(NSURLSessionResponseAllow);
}

// 2.接收到服务器返回数据的时候调用,会调用多次
-(void)URLSession:(NSURLSession *)session dataTask:(NSURLSessionDataTask *)dataTask didReceiveData:(NSData *)data{
   
    //保存已经下载的偏移量
    _downLoadingOffset += data.length;
    [self.outputStream write:data.bytes maxLength:data.length];
    
     //    NSLog(@"%lf", 1.0 * _downLoadingOffset / self.videoLength);
    //正在下载
    if ([self.delegate respondsToSelector:@selector(manager:didReceiveData:downloadOffset:tempFilePath:)]) {
        [self.delegate manager:self didReceiveData:data downloadOffset:_downLoadingOffset tempFilePath:_tempPath];
    }
  
}

// 3.请求结束的时候调用(成功|失败),如果失败那么error有值
-(void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task didCompleteWithError:(NSError *)error{
    if (!error) { //下载成功
        [self downloadSuccessWithURLSession:session task:task];
    }else { //下载失败
        [self downloadFailedWithURLSession:session task:task error:error];
    }
}

//下载成功
-(void)downloadSuccessWithURLSession:(NSURLSession *)session task:(NSURLSessionTask *)task{
    // If download success, then move the complete file from temporary path to cache path
    // 如果下载完成, 就把文件移到缓存文件夹
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSString *savePath = [self fileSavePath];
    savePath = [savePath stringByAppendingPathComponent:self.suggestFileName];
    
    if ([fileManager fileExistsAtPath:self.tempPath]) {
        [fileManager moveItemAtPath:self.tempPath toPath:savePath error:nil];
        if ([self.delegate respondsToSelector:@selector(didFinishLoadingWithManager:fileSavePath:)]) {
            [self.delegate didFinishLoadingWithManager:self fileSavePath:savePath];
          
        }
        [self.outputStream close];
        self.outputStream = nil;
    }

}

//下载失败
-(void)downloadFailedWithURLSession:(NSURLSession *)session task:(NSURLSessionTask *)task error:(NSError *)error{
    //网络中断：-1005
    //无网络连接：-1009
    //请求超时：-1001
    //服务器内部错误：-1004
    //找不到服务器：-1003
    if (error.code == -1001 && !_once) {
        //网络超时，重连一次
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            [self startLoading];
            _once = YES;
        });
    }
    if ([self.delegate respondsToSelector:@selector(didFailLoadingWithManager:WithError:)]) {
        [self.delegate didFailLoadingWithManager:self WithError:error];
    }
    
    if (error.code == -1009) {
        NSLog(@"No Connect 无网络链接");
    }
}

#pragma mark --------------------------------------------------
#pragma mark Private

// 缓存存储路径
-(NSString *)fileCachePath{
    NSFileManager *fileManager = [NSFileManager defaultManager];
    
    NSString *path = [NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES).lastObject stringByAppendingString:ad_tempPath];
    
    //如果缓存路径文件夹不存在，就创建文件
    if (![fileManager fileExistsAtPath:path]) {
        [fileManager createDirectoryAtPath:path withIntermediateDirectories:YES attributes:nil error:nil];
    }
    
    path = [path stringByAppendingPathComponent:self.suggestFileName];
    
    //如果文件存在并且不是重连状态
    if ([fileManager fileExistsAtPath:path] && !self.once) {
        [fileManager removeItemAtPath:path error:nil];
        [fileManager createFileAtPath:path contents:nil attributes:nil];
    } else {
        [fileManager createFileAtPath:path contents:nil attributes:nil];
    }
    return path;
    
}
// Combine complete file path
// 拼接完整的 下载完成以后的文件存储路径
-(NSString *)fileSavePath{
    NSFileManager *fileManager = [NSFileManager defaultManager];
    
    NSString *path = [NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES).lastObject stringByAppendingString:ad_savePath];
    //创建文件夹
    if (![fileManager fileExistsAtPath:path]) {
        [fileManager createDirectoryAtPath:path withIntermediateDirectories:YES attributes:nil error:nil];
    }
    return path;
}

#pragma mark - 清除数据
-(void)clearData{
    [self.session invalidateAndCancel];
    [self.outputStream close];
    self.outputStream = nil;
    //移除文件
    [[NSFileManager defaultManager] removeItemAtPath:_tempPath error:nil];
}


@end

