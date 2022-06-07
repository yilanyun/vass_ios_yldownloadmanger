 //
//  YLDownloadManager.m
//  YLDownloadManager
//
//  Created by Jabne on 2022/6/7.

#import "YLDownloadManager.h"
#import <UIKit/UIKit.h>
#import "YLDownloadModel.h"
#import <CommonCrypto/CommonDigest.h>


@implementation YLDownloadedFile

@end


@interface YLDownloadModel()

@end

@interface YLDownloadManager()<NSURLSessionDelegate>
@property (nonatomic, strong) NSFileManager *fileManager;

// Caches/YLDownloadCache/
@property (nonatomic, strong) NSString *fileCacheDirectory;

// Caches/YLDownloadCache/DownloadFileDirectory/
@property (nonatomic, copy) NSString *downloadFileDirectory;

//  Caches/YLDownloadCache/FinishedPlist.plist
@property (nonatomic, copy) NSString *finishedPlistFilePath;




@end

@implementation YLDownloadManager

@synthesize session = _session;

+(YLDownloadManager *)shareManager{
    static YLDownloadManager *manager = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        manager = [YLDownloadManager new];
    });
    return manager;
}

- (instancetype)init{
    if (self = [super init]) {
        _downloadModelList = @[].mutableCopy;
        _finishedlist = @[].mutableCopy;
        _downloadModelDic = @{}.mutableCopy;
        NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];
        NSString * max = [userDefaults valueForKey:@"maxCount"];
        if (max == nil) {
            [userDefaults setObject:@"1" forKey:@"maxCount"];
            max = @"1";
        }
        [userDefaults synchronize];
        _maxCount = [max intValue];
        [self loadFinishedfiles];
        _downloadModelList = [self loadDownloadList];
        
        NSURLSessionConfiguration *con = [NSURLSessionConfiguration backgroundSessionConfigurationWithIdentifier:@"com.YLDownloadManager.BackgrpoudSession"];
        con.timeoutIntervalForRequest = 10;
        con.sessionSendsLaunchEvents = YES;
        _session = [NSURLSession sessionWithConfiguration:con delegate:self delegateQueue:nil];

        //查看是否有进行中的下载
        NSArray *tasks = [self sessionDownloadTasks];
        for (NSURLSessionDownloadTask *task in tasks) {
            if (task.state == NSURLSessionTaskStateRunning) {
                YLDownloadModel *model = _downloadModelDic[task.currentRequest.URL.absoluteString];
                model.downloadTask = task;
            }
        }
    }
    return self;
}

- (NSMutableArray *)loadDownloadList{
    NSMutableArray *array = @[].mutableCopy;
    NSError *error;
    NSArray *filelist = [self.fileManager contentsOfDirectoryAtPath:[self downloadFileDirectory] error:&error];
    
    if(!error)
    {
        NSLog(@"%@",[error description]);
    }
    for(NSString *file in filelist) {
        NSString *filetype = [file pathExtension];
        if([filetype isEqualToString:@"plist"]){
            NSString *path = [[self downloadFileDirectory] stringByAppendingPathComponent:file];
            NSDictionary *dic = [NSDictionary dictionaryWithContentsOfFile:path];
            YLDownloadModel *model = [YLDownloadModel new];
            model.url = dic[@"url"];
            model.startTime = dic[@"startTime"];
            model.progress.totalBytesExpectedToWrite = [dic[@"totalBytesExpectedToWrite"] integerValue];
            model.progress.totalBytesWritten = [dic[@"totalBytesWritten"] integerValue];
            model.state = [dic[@"state"] integerValue];
            model.resumeData = dic[@"resumedata"];
            [array addObject:model];
            [_downloadModelDic setObject:model forKey:dic[@"url"]];
            [_downloadModelList addObject:model];
            if (model.state == YLDownloadModelRunningState) {
                self.downloadingCount++;
            }
        }
    }
    return array;
}


- (YLDownloadModel *)downLoadingModelForURLString:(NSString *)URLString
{
    return [self.downloadModelDic objectForKey:URLString];
}
- (BOOL)isInDownloadList:(NSString *)url{
    return [self.downloadModelDic objectForKey:url];
}

#pragma mark --get download model
- (YLDownloadModel *)downloadModelWithURL:(NSString *)url isInitTask:(BOOL)isInitTask{
    YLDownloadModel *model = [[YLDownloadModel alloc] initWithURL:url isInitTask:isInitTask] ;
    return model;
}

- (YLDownloadModel *)addDownloadModelWithURL:(NSString *)url{
    BOOL isInitTask = YES;
    if (self.downloadingCount == _maxCount)  {
        isInitTask = NO;
    }
    
    YLDownloadModel *model = [self downloadModelWithURL:url isInitTask:isInitTask ];
    if (model) {
        [_downloadModelList addObject:model];
        [_downloadModelDic setObject:model forKey:url];
        [self saveDownloadInfo:model];
    }
    if (self.downloadingCount == _maxCount) {
        
    }else{//没有达到最大下载数量就开始下载
        [model resume];
        self.downloadingCount++;
    }
    return model;
}


#pragma mark -- NSURLSessionTaskDelegate
- (void)URLSessionDidFinishEventsForBackgroundURLSession:(NSURLSession *)session{
    if (self.completionHandler) {
        self.completionHandler();
    }
}

static void extracted(NSError * _Nullable error, YLDownloadModel *model, NSURLSession *session, NSURLSessionTask *task) {
    [model URLSession:session task:task didCompleteWithError:error];
}

- (void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task
didCompleteWithError:(nullable NSError *)error{
    NSLog(@"%s", __func__);
    YLDownloadModel *model = [self modelWithUrl:task.currentRequest.URL.absoluteString];
    if (model == nil) {
        return;
    }
    NSAssert(model != nil, @"model不能为nil");
    NSData *resumeData = [error.userInfo objectForKey:NSURLSessionDownloadTaskResumeData];
    if (resumeData) {//user 主动暂停了应用或者等待下载
        if (model.state == YLDownloadModelPauseState || model.state == YLDownloadModelWillStartState) {
            model.resumeData = resumeData;
            [self saveDownloadInfo:model];
        }else if(model.state == YLDownloadModelRunningState){//如果是用户主动kill了应用，重启应用也可以在这里获取到resumedata
            model.resumeData = resumeData;
            [model resume];
        }
    }else{//下载完成或下载失败
        
//        if (model.state == YLDownloadModelRunningState || model.state == YLDownloadModelWillStartState) {
//            return;
//        }
        
        
        [self.downloadModelList removeObject:model];
        [self.downloadModelDic removeObjectForKey:model.url];

        NSString *path = [[self downloadFileDirectory ] stringByAppendingPathComponent:[NSString stringWithFormat:@"%@.plist", model.fileName]];
        [_fileManager removeItemAtPath:path error:nil];
        
        @synchronized(self){
            self.downloadingCount--;
            for (YLDownloadModel *model in self.downloadModelList) {
                if (model.state == YLDownloadModelWillStartState) {
                    [model resume];
                    self.downloadingCount++;
                    break;
                }
            }
        }
        extracted(error, model, session, task);
    }
}


- (YLDownloadModel *)modelWithUrl:(NSString *)url{
    YLDownloadModel *model = [self.downloadModelDic objectForKey:url];
    return model;
}

- (YLDownloadModel *)modelWithTask:(NSURLSessionDownloadTask *)task{
    for (YLDownloadModel * model in self.downloadModelList) {
        if (model.downloadTask == task) {
            return model;
        }
    }
    return nil;
}

- (void)deleteFinishFile:(YLDownloadedFile *)model
{
    
    [_finishedlist removeObject:model];
    NSString *path = model.filePath;
    NSError *error;
    if ([self.fileManager fileExistsAtPath:path]) {
       BOOL s = [self.fileManager removeItemAtPath:path error:&error];
        NSAssert(s, @"删除失败");

        if (s) {
            NSLog(@"删除成功");
        }else{
            NSLog(@"删除失败");
        }
    }
    [self saveFinishedFile];
}

#pragma mark -- 
#pragma mark -- NSURLSessionDownloadDelegate

/* Sent when a download task that has completed a download.  The delegate should
 * copy or move the file at the given location to a new location as it will be
 * removed when the delegate message returns. URLSession:task:didCompleteWithError: will
 * still be called.
 */
- (void)URLSession:(NSURLSession *)session downloadTask:(NSURLSessionDownloadTask *)downloadTask
didFinishDownloadingToURL:(NSURL *)location{
    NSLog(@"%s", __func__);
    YLDownloadModel *model = [self modelWithTask:downloadTask];
    NSString *path = [[self fileCacheDirectory] stringByAppendingPathComponent:downloadTask.response.suggestedFilename];//[self fileCachePath:downloadTask.response.suggestedFilename] ;
    [self.fileManager moveItemAtURL:location toURL:[NSURL fileURLWithPath:path] error:nil];

    YLDownloadedFile * finish = [YLDownloadedFile new];
    finish.fileName = model.fileName;
    finish.fileSize = model.progress.totalFileSize;
    finish.filePath = path;
    
    [self.finishedlist addObject:finish];
    [[YLDownloadManager shareManager] saveFinishedFile];
    [model URLSession:session downloadTask:downloadTask didFinishDownloadingToURL:location];
}



/* Sent periodicallt  o notify the delegate of download progress. */
- (void)URLSession:(NSURLSession *)session downloadTask:(NSURLSessionDownloadTask *)downloadTask
      didWriteData:(int64_t)bytesWritten
 totalBytesWritten:(int64_t)totalBytesWritten
totalBytesExpectedToWrite:(int64_t)totalBytesExpectedToWrite{
    NSLog(@"%s", __func__);

    YLDownloadModel *model = [self modelWithTask:downloadTask];
    [model URLSession:session downloadTask:downloadTask didWriteData:bytesWritten totalBytesWritten:totalBytesWritten totalBytesExpectedToWrite:totalBytesExpectedToWrite];
}

/* Sent when a download has been resumed. If a download failed with an
 * error, the -userInfo dictionary of the error will contain an
 * NSURLSessionDownloadTaskResumeData key, whose value is the resume
 * data.
 */

- (void)URLSession:(NSURLSession *)session downloadTask:(NSURLSessionDownloadTask *)downloadTask
 didResumeAtOffset:(int64_t)fileOffset
expectedTotalBytes:(int64_t)expectedTotalBytes{
    YLDownloadModel *model = [self modelWithTask:downloadTask];
    [model URLSession:session downloadTask:downloadTask didResumeAtOffset:fileOffset expectedTotalBytes:expectedTotalBytes];
    NSLog(@"%s", __func__);
}

// 获取所有的后台下载session
- (NSArray *)sessionDownloadTasks
{
    __block NSArray *tasks = nil;
    dispatch_semaphore_t semaphore = dispatch_semaphore_create(0);//使用信号量把异步变同步，是这个函数返回时tasks有值
    [self.session getTasksWithCompletionHandler:^(NSArray *dataTasks, NSArray *uploadTasks, NSArray *downloadTasks) {
        tasks = downloadTasks;
        if (tasks.count > 0) {
            NSURLSessionDownloadTask *task = tasks[0];
            NSLog(@"aa");
        }
        dispatch_semaphore_signal(semaphore);
    }];
    dispatch_semaphore_wait(semaphore, DISPATCH_TIME_FOREVER);
    return tasks;
}
//- (nullable NSString *)cachedFileNameForKey:(nullable NSString *)key {
//
//    const char *cStr = [key UTF8String];
//    if (cStr == NULL) {
//        cStr = "";
//    }
//    unsigned char result[CC_MD5_DIGEST_LENGTH];
//    CC_MD5( cStr, (CC_LONG)strlen(cStr), result );
//    return [NSString stringWithFormat:
//            @"%02X%02X%02X%02X%02X%02X%02X%02X%02X%02X%02X%02X%02X%02X%02X%02X",
//            result[0], result[1], result[2], result[3],
//            result[4], result[5], result[6], result[7],
//            result[8], result[9], result[10], result[11],
//            result[12], result[13], result[14], result[15]
//            ];
//}

- (void)pauseDownload:(YLDownloadModel *)model{
    [model pause];
    if (model.progressInfoBlock) {
        model.progressInfoBlock(model.progress);
    }
    self.downloadingCount--;
    for (YLDownloadModel *aModel  in _downloadModelList) {
        if (aModel.state == YLDownloadModelWillStartState) {
            [aModel resume];
            self.downloadingCount++;
            if (model.progressInfoBlock) {
                model.progressInfoBlock(model.progress);
            }
            break;
        }
    }
}

//YLDownloadModelPauseState或者YLDownloadModelWillStartState调用这个方法开启下载
- (void)resumeDownload:(YLDownloadModel *)model{
    
    int tem = 0;
    for (YLDownloadModel *aModel in _downloadModelList) {
        if (aModel.state == YLDownloadModelRunningState) {
            tem++;
            if (tem == _maxCount) {//
                [aModel wait];
                if (aModel.progressInfoBlock) {
                    aModel.progressInfoBlock(aModel.progress);
                }
                self.downloadingCount--;
                break;
            }
        }
    }
    [model resume];
    
    if (model.progressInfoBlock) {
        model.progressInfoBlock(model.progress);
    }
    self.downloadingCount++;
}

#pragma mark -- handle finish file

- (void)loadFinishedfiles
{
    if ([self.fileManager fileExistsAtPath:self.finishedPlistFilePath]) {
        NSMutableArray *finishArr = [[NSMutableArray alloc] initWithContentsOfFile:[self finishedPlistFilePath]];
        for (NSDictionary *dic in finishArr) {
            YLDownloadedFile *file = [[YLDownloadedFile alloc]init];
            file.fileName = [dic objectForKey:@"fileName"];
            file.fileType = [file.fileName pathExtension];
            file.fileSize = [dic objectForKey:@"fileSize"];
            file.filePath = [self.fileCacheDirectory stringByAppendingPathComponent:file.fileName];
            [_finishedlist addObject:file];
        }
    }
}

- (void)saveFinishedFile
{
    if (_finishedlist == nil) { return; }
    NSMutableArray *finishedinfo = [[NSMutableArray alloc] init];
    for (YLDownloadedFile *fileinfo in _finishedlist) {
        NSDictionary *filedic = [NSDictionary dictionaryWithObjectsAndKeys: fileinfo.fileName,@"fileName",
                                 fileinfo.fileSize,@"fileSize",
                                 nil];
        [finishedinfo addObject:filedic];
    }
    if (![finishedinfo writeToFile:self.finishedPlistFilePath atomically:YES]) {
        NSLog(@"write plist fail");
    }
}



- (void)deleteDownload:(YLDownloadModel *)model{
    if (model.state == YLDownloadModelRunningState) {
        [model cancel];
        [self.downloadModelList removeObject:model];
        [self.downloadModelDic removeObjectForKey:model.url];
        NSString *path = [[self downloadFileDirectory ] stringByAppendingPathComponent:[NSString stringWithFormat:@"%@.plist", model.fileName]];
        [_fileManager removeItemAtPath:path error:nil];
        
        @synchronized(self){
            self.downloadingCount--;
            for (YLDownloadModel *model in self.downloadModelList) {
                if (model.state == YLDownloadModelWillStartState) {
                    [model resume];
                    self.downloadingCount++;
                    break;
                }
            }
        }

    }else{
        [self.downloadModelDic removeObjectForKey:model.url];
        [self.downloadModelList removeObject:model];

        NSError *error;
        BOOL s1 = [self.fileManager removeItemAtPath: [[self downloadFileDirectory ] stringByAppendingPathComponent:[NSString stringWithFormat:@"%@.plist", model.fileName]] error:&error];
        if (s1) {
            NSLog(@"s");
            if(model.completeBlock){
                dispatch_async(dispatch_get_main_queue(), ^{
                    model.completeBlock(nil);
                });
            }
        }else{
            NSLog(@"f");
        }
    }
    if (model.url == nil) {
        NSLog(@"aaaaaaaaaaa%@", model);
    }
    
}

#pragma mark -- File Manager

- (NSString *)finishedPlistFilePath{
    if (!_finishedPlistFilePath) {
        _finishedPlistFilePath = [[self fileCacheDirectory] stringByAppendingPathComponent:@"FinishedPlist.plist"];
    }
    return _finishedPlistFilePath;
}

- (NSFileManager *)fileManager
{
    if (!_fileManager) {
        _fileManager = [[NSFileManager alloc]init];
    }
    return _fileManager;
}


- (void)createDirectory:(NSString *)directory
{
    if (![self.fileManager fileExistsAtPath:directory]) {
        [self.fileManager createDirectoryAtPath:directory withIntermediateDirectories:YES attributes:nil error:NULL];
    }
}



- (NSString *)fileCacheDirectory
{
    if (!_fileCacheDirectory) {
        _fileCacheDirectory = [[NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES) lastObject] stringByAppendingPathComponent:@"YLDownloadCache"];
        [self createDirectory:_fileCacheDirectory];
    }
    return _fileCacheDirectory;
}
- (NSString *)downloadFileDirectory{
    //DownloadFilePlsits
    if (!_downloadFileDirectory) {
        _downloadFileDirectory = [self.fileCacheDirectory stringByAppendingPathComponent:@"DownloadFileDirectory"];
        [self createDirectory:_downloadFileDirectory];
    }
    return _downloadFileDirectory;
}

- (void)saveDownloadInfo:(YLDownloadModel *)model{
    NSMutableDictionary *dic = @{}.mutableCopy;
    if (model.url) {
        [dic setObject:model.url forKey:@"url"];
    }
    
    if (model.startTime) {
        [dic setObject:model.startTime forKey:@"startTime"];
    }
    
    if (model.progress.totalFileSize) {
        [dic setObject:@(model.progress.totalBytesExpectedToWrite) forKey:@"totalBytesExpectedToWrite"];
    }
    
    if (model.progress.writtenFileSize) {
        [dic setObject: @(model.progress.totalBytesWritten) forKey:@"totalBytesWritten"];
    }
    
    if (model.resumeData) {
        [dic setObject:model.resumeData forKey:@"resumedata"];
    }
    
    [dic setObject:@(model.state) forKey:@"state"];

    NSString *path = [[self downloadFileDirectory ] stringByAppendingPathComponent:[NSString stringWithFormat:@"%@.plist", model.fileName]];
    BOOL s = [dic writeToFile:path atomically:YES];
    NSAssert(s, @"写入失败");
}

- (BOOL)fileExist:(NSString *)fileName{
    NSString *path = [self.fileCacheDirectory stringByAppendingPathComponent:fileName];
    return [self.fileManager fileExistsAtPath:path];
}

- (BOOL)isFinishedDownload:(NSString *)url{
    NSString *fileName = url.lastPathComponent;
    NSString *path = [self.fileCacheDirectory stringByAppendingPathComponent:fileName];
    return [self.fileManager fileExistsAtPath:path];
}

- (void)setMaxCount:(NSInteger)maxCount{
    if (_maxCount == maxCount) {
        return;
    }else{
        _maxCount = maxCount;
        [[NSUserDefaults standardUserDefaults] setValue:@(maxCount) forKey:@"maxCount"];
        [[NSUserDefaults standardUserDefaults] synchronize];
        if (self.downloadingCount > _maxCount) {
            int tem = 0;
            for (YLDownloadModel *model in _downloadModelList) {
                if (model.state == YLDownloadModelRunningState) {
                    if (tem < maxCount) {
                        tem++;
                    }else{
                        [model wait];
                        if (model.progressInfoBlock) {
                            model.progressInfoBlock(model.progress);
                        }
                    }
                }
            }
            self.downloadingCount = tem;
            
        }else if (self.downloadingCount < _maxCount){
            int tem = 0;
            for (YLDownloadModel *model in _downloadModelList) {
                if (model.state == YLDownloadModelRunningState) {
                    tem++;
                }
                else if (model.state == YLDownloadModelWillStartState) {
                    if (tem < maxCount) {
                        [model resume];
                        if (model.progressInfoBlock) {
                            model.progressInfoBlock(model.progress);
                        }
                        tem++;
                    }
                }
            }
            self.downloadingCount = tem;
        }
    }
}



@end
