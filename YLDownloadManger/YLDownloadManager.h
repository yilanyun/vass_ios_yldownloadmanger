//
//  YLDownloadManager.h
//  YLDownloadManager
//
//  Created by Jabne on 2022/6/7.


#import <Foundation/Foundation.h>
#import "YLDownloadModel.h"

@interface YLDownloadedFile:NSObject

@property (nonatomic, copy) NSString        *fileName;
/** 文件的总长度 */
@property (nonatomic, copy) NSString        *fileSize;

@property (nonatomic, copy) NSString        *filePath;

@property (nonatomic, copy) NSString        *fileType;

@end


@interface YLDownloadManager : NSObject

@property (nonatomic, strong) NSURLSession *session;
@property (nonatomic, copy) void (^completionHandler)(void);
@property (nonatomic, strong) NSMutableArray <YLDownloadModel *> * downloadModelList;
@property (atomic, strong) NSMutableArray  <YLDownloadedFile *> *finishedlist;
@property (nonatomic, strong) NSMutableDictionary *downloadModelDic;
@property (nonatomic, assign) NSInteger maxCount;
@property (nonatomic, assign) NSInteger downloadingCount;


+(YLDownloadManager *)shareManager;

- (YLDownloadModel *)addDownloadModelWithURL:(NSString *)url;


- (void)saveDownloadInfo:(YLDownloadModel *)model;


//是否在下载的列表里
- (BOOL)isInDownloadList:(NSString *)url;
- (BOOL)isFinishedDownload:(NSString *)url;

//- (YLDownloadModel *)startDownload:(NSString *)url;



- (void)deleteDownload:(YLDownloadModel *)model;
- (void)resumeDownload:(YLDownloadModel *)model;
- (void)pauseDownload:(YLDownloadModel *)model;
- (void)deleteFinishFile:(YLDownloadedFile *)model;
@end
