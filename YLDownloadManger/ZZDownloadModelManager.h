//
//  ZZManager.h
//  ZZDownloadManager
//
//  Created by 赵铭 on 2018/11/19.
//  Copyright © 2018年 zm. All rights reserved.
//

#import <Foundation/Foundation.h>
@class ZZDownloadProgress;
@class ZZDownloadModel;



@interface ZZDownloadModelManager : NSObject

+ (instancetype)shareManager;

- (ZZDownloadModel *)startDownload:(NSString *)url;

@property (nonatomic, strong) NSMutableArray <ZZDownloadModel *> * downloadingModels;

@end
