//
//  FileReader.h
//  LinSpell
//
//  Created by Shyngys Kassymov on 23.01.2018.
//  Copyright © 2018 Shyngys Kassymov. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface FileReader : NSObject {
    NSString *filePath;

    NSFileHandle *fileHandle;
    unsigned long long currentOffset;
    unsigned long long totalFileLength;

    NSString *lineDelimiter;
    NSUInteger chunkSize;
}

@property (nonatomic, copy) NSString *lineDelimiter;
@property (nonatomic) NSUInteger chunkSize;

- (id)initWithFilePath:(NSString *)aPath;

- (NSString *)readLine;
- (NSString *)readTrimmedLine;

- (void)enumerateLinesUsingBlock:(void(^)(NSString *, BOOL *))block;

@end
