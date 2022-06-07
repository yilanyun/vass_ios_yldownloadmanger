//
//  YLDownloadModel.m
//  YLDownloadManager
//
//  Created by Jabne on 2022/6/7.

#import "YLDownloadModel.h"
#import <UIKit/UIKit.h>
#import "YLDownloadManager.h"


@interface YLDownloadProgress ()
// 续传大小
@property (nonatomic, assign) int64_t resumeBytesWritten;
// 这次写入的数量
@property (nonatomic, assign) int64_t bytesWritten;
// 已下载的数量
//@property (nonatomic, assign) int64_t totalBytesWritten;
//// 文件的总大小
//@property (nonatomic, assign) int64_t totalBytesExpectedToWrite;

// 下载进度
@property (nonatomic, assign) float progress;
// 下载速度
@property (nonatomic, assign) float speed;
// 下载剩余时间
@property (nonatomic, assign) int remainingTime;

@property (nonatomic, copy) NSString * speedString;

@end

@implementation YLDownloadProgress
- (float)progress{
    if (_totalBytesWritten == 0) {
        return 0;
    }
    return (CGFloat)_totalBytesWritten/_totalBytesExpectedToWrite;
}

- (NSString *)writtenFileSize{
    NSString *writtenFileSize = [NSString stringWithFormat:@"%.2f %@",
                                 [self calculateFileSizeInUnit:(unsigned long long)self.totalBytesWritten],
                                 [self calculateUnit:(unsigned long long)self.totalBytesWritten]];
    
    return writtenFileSize;

}

- (NSString *)totalFileSize{
    NSString *totalFileSize = [NSString stringWithFormat:@"%.2f %@",
                                     [self calculateFileSizeInUnit:(unsigned long long)self.totalBytesExpectedToWrite],
                                     [self calculateUnit:(unsigned long long)self.totalBytesExpectedToWrite]];
    return totalFileSize;
}

- (NSString *)speedString{
    NSString *speedS = [NSString stringWithFormat:@"%.2f %@",[self calculateFileSizeInUnit:(unsigned long long)self.speed],
                        [self calculateUnit:(unsigned long long)self.speed]];
    return speedS;
}

- (float)calculateFileSizeInUnit:(unsigned long long)contentLength
{
    if(contentLength >= pow(1024, 3))
        return (float) (contentLength / (float)pow(1024, 3));
    else if(contentLength >= pow(1024, 2))
        return (float) (contentLength / (float)pow(1024, 2));
    else if(contentLength >= 1024)
        return (float) (contentLength / (float)1024);
    else
        return (float) (contentLength);
}

- (NSString *)calculateUnit:(unsigned long long)contentLength
{
    if(contentLength >= pow(1024, 3))
        return @"GB";
    else if(contentLength >= pow(1024, 2))
        return @"MB";
    else if(contentLength >= 1024)
        return @"KB";
    else
        return @"Bytes";
}
@end

@interface YLDownloadModel()<NSURLSessionDelegate>
@property (nonatomic, strong) NSDate * date;
@property (nonatomic, assign) int64_t bytes;

@end


@implementation YLDownloadModel

- (instancetype)initWithURL:(NSString *)url isInitTask:(BOOL)isInitTask{
    if (!url) {
        return nil;
    }
    if ([[YLDownloadManager shareManager] isFinishedDownload:url] || [[YLDownloadManager shareManager] isInDownloadList:url]) {
        return nil;
    }
    self = [super init];
    if (self) {
        if (isInitTask) {
            NSURLSessionDownloadTask *task = [[YLDownloadManager shareManager].session downloadTaskWithURL:[NSURL URLWithString:url]];
            self.downloadTask = task;
        }
        self.url = url;
        self.startTime = [self dateToString:[NSDate date]];
        _progress = [YLDownloadProgress new];
    }
    return self;
}

- (NSString *)fileName{
    return [self.url lastPathComponent];
}

- (instancetype)init{
    if (self = [super init]) {
        _progress = [YLDownloadProgress new];
    }
    return self;
}


- (void)saveInfo{
    [[YLDownloadManager shareManager] saveDownloadInfo:self];
}

#pragma mark -- NSURLSessionTaskDelegate
- (void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task
didCompleteWithError:(nullable NSError *)error{
    if(self.completeBlock){
        dispatch_async(dispatch_get_main_queue(), ^{
            self.completeBlock(error);
        });
    }
}

#pragma mark -- NSURLSessionDownloadDelegate

- (void)URLSession:(NSURLSession *)session downloadTask:(NSURLSessionDownloadTask *)downloadTask
didFinishDownloadingToURL:(NSURL *)location{
    NSLog(@"%s", __func__);
   
}

- (void)URLSession:(NSURLSession *)session downloadTask:(NSURLSessionDownloadTask *)downloadTask
      didWriteData:(int64_t)bytesWritten
 totalBytesWritten:(int64_t)totalBytesWritten
totalBytesExpectedToWrite:(int64_t)totalBytesExpectedToWrite{
    NSLog(@"%s", __func__);
    
    _progress.bytesWritten = bytesWritten;
    _progress.totalBytesWritten = totalBytesWritten;
    _progress.totalBytesExpectedToWrite = totalBytesExpectedToWrite;
    
    _progress.progress = (CGFloat)totalBytesWritten/totalBytesExpectedToWrite;
    
    NSDate *currentDate = [NSDate date];
    double time = [currentDate timeIntervalSinceDate:self.date];
    self.bytes = self.bytes + bytesWritten;
    if (time >= 1) {
        float speed  = _bytes/time;
        
        int64_t remainingContentLength = totalBytesExpectedToWrite - totalBytesWritten;
        int remainingTime = ceilf(remainingContentLength / speed);
        
        _progress.speed = speed;
        _progress.remainingTime = remainingTime;
        
        _date = currentDate;
        _bytes = 0;
    }
    
    if (self.progressInfoBlock) {
        dispatch_async(dispatch_get_main_queue(), ^{
            self.progressInfoBlock(self.progress);
        });
    }
}

- (void)URLSession:(NSURLSession *)session downloadTask:(NSURLSessionDownloadTask *)downloadTask
 didResumeAtOffset:(int64_t)fileOffset
expectedTotalBytes:(int64_t)expectedTotalBytes{
    NSLog(@"%s", __func__);
}

- (void)pause{
    if (self.state == YLDownloadModelRunningState) {
        self.state = YLDownloadModelPauseState;
        [self.downloadTask cancelByProducingResumeData:^(NSData * _Nullable resumeData) {

        }];
    }
}
- (void)wait{
    if (self.state == YLDownloadModelRunningState) {
        self.state = YLDownloadModelWillStartState;
        [self.downloadTask cancelByProducingResumeData:^(NSData * _Nullable resumeData) {
            
        }];
    }
}

- (void)resume{
    
    if (self.state == YLDownloadModelPauseState) {
        if (self.resumeData) {
            [self resumeWithResumeData:self.resumeData];
        }
    }
    else if (self.state == YLDownloadModelWillStartState) {
        if (self.resumeData) {
            [self resumeWithResumeData:self.resumeData];
        }else{
            [self recoverResume];
        }
        
    }
   else if (self.state == YLDownloadModelRunningState){
       if (self.downloadTask) {
           return;
       }else{
           if (self.resumeData) {
               [self resumeWithResumeData:self.resumeData];
           }else{
               [self recoverResume];
           }
       }
      }
}


- (void)resumeWithResumeData:(NSData *)resumeData{
    if (self.resumeData) {
        self.downloadTask = [[YLDownloadManager shareManager].session downloadTaskWithResumeData:self.resumeData];
        [self.downloadTask resume];
        self.date = [NSDate date];
        self.state = YLDownloadModelRunningState;
        [self saveInfo];
    }
}

- (void)recoverResume{
    if (!self.downloadTask) {
        self.downloadTask = [[YLDownloadManager shareManager].session downloadTaskWithURL:[NSURL URLWithString:self.url]];
        
    }
    [self.downloadTask resume];
    self.date = [NSDate date];
    self.state = YLDownloadModelRunningState;
    [self saveInfo];
}

- (void)cancel{
    [self.downloadTask cancel];
}


- (NSString *)dateToString:(NSDate*)date {
    NSDateFormatter *df = [[NSDateFormatter alloc] init];
    [df setDateFormat:@"yyyy-MM-dd HH:mm:ss"];
    NSString *datestr = [df stringFromDate:date];
    return datestr;
}

@end
