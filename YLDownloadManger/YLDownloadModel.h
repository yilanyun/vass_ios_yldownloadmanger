//
//  YLDownloadModel.h
//  YLDownloadManager
//
//  Created by Jabne on 2022/6/7.

#import <Foundation/Foundation.h>
@class YLDownloadProgress;

typedef void(^ZZDownloadProgressBlock)(int64_t bytesWritten, int64_t totalBytesWritten, int64_t totalBytesExpectedToWrite);
typedef void(^ZZDownloadProgressInfoBlock)(YLDownloadProgress *);
typedef void(^ZZDownloadCompleteBlock)(NSError * error);

typedef enum : NSUInteger {
    YLDownloadModelWillStartState,
    YLDownloadModelRunningState,
    YLDownloadModelPauseState,
    YLDownloadModelResumableState,
    YLDownloadModelCompleteState
} YLDownloadModelState;

@interface YLDownloadProgress : NSObject
// 续传大小
@property (nonatomic, assign, readonly) int64_t resumeBytesWritten;
// 这次写入的数量
@property (nonatomic, assign, readonly) int64_t bytesWritten;
// 已下载的数量
@property (nonatomic, assign) int64_t totalBytesWritten;
// 文件的总大小
@property (nonatomic, assign) int64_t totalBytesExpectedToWrite;

// 下载进度
@property (nonatomic, assign, readonly) float progress;
// 下载速度
@property (nonatomic, assign, readonly) float speed;
// 下载剩余时间
@property (nonatomic, assign, readonly) int remainingTime;

// 已下载的数量
@property (nonatomic, copy) NSString *writtenFileSize;
// 文件的总大小
@property (nonatomic, copy) NSString *totalFileSize;

// 下载速度
@property (nonatomic, copy, readonly) NSString * speedString;



@end


@interface YLDownloadModel : NSObject<NSURLSessionDownloadDelegate>

@property (nonatomic, copy) NSString *url;
//@property (nonatomic, strong) NSDate *startDate;
@property (nonatomic, strong) NSString *startTime;

@property (nonatomic, copy) NSString *fileName;
//@property (nonatomic, copy) NSString *destinyPath;
@property (nonatomic, strong) NSURLSessionDownloadTask *downloadTask;
@property (nonatomic, strong) NSData *resumeData;

@property (nonatomic, assign) YLDownloadModelState state;
@property (nonatomic, strong) YLDownloadProgress * progress;


@property (nonatomic, copy) ZZDownloadProgressInfoBlock progressInfoBlock;
@property (nonatomic, copy) ZZDownloadCompleteBlock completeBlock;

//- (instancetype)initWithTask:(NSURLSessionDownloadTask * )task;
- (instancetype)initWithURL:(NSString *)url isInitTask:(BOOL)isInitTask;
//- (instancetype)initWithResumeData:(NSData *)resumeData url:(NSString *)url;
//- (void)startDownload;

- (void)pause;

- (void)wait;

- (void)resume;

//取消下载的task并且会删除之前下载到本地的tem文件
- (void)cancel;

@end
