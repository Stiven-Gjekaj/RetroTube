#import "RTDiskCache.h"
#import <CommonCrypto/CommonDigest.h>

@interface RTDiskCache ()
@property (nonatomic, copy) NSString *directory;
@property (nonatomic) unsigned long long limit;
@end

@implementation RTDiskCache

- (instancetype)initWithDirectory:(NSString *)directory limit:(unsigned long long)limit {
    if ((self = [super init])) {
        _directory = [directory copy];
        _limit = limit;
        [[NSFileManager defaultManager] createDirectoryAtPath:directory withIntermediateDirectories:YES attributes:nil
                                                        error:NULL];
    }
    return self;
}

// The file name is the MD5 of the key, so that any key is a safe name.
- (NSString *)pathForKey:(NSString *)key {
    const char *text = key.UTF8String;
    unsigned char digest[CC_MD5_DIGEST_LENGTH];
    CC_MD5(text, (CC_LONG)strlen(text), digest);
    NSMutableString *name = [NSMutableString stringWithCapacity:CC_MD5_DIGEST_LENGTH * 2];
    for (int i = 0; i < CC_MD5_DIGEST_LENGTH; i++) [name appendFormat:@"%02x", digest[i]];
    return [self.directory stringByAppendingPathComponent:name];
}

- (NSData *)dataForKey:(NSString *)key {
    if (!key.length) return nil;
    return [NSData dataWithContentsOfFile:[self pathForKey:key]];
}

- (void)setData:(NSData *)data forKey:(NSString *)key {
    if (!key.length || !data) return;
    [data writeToFile:[self pathForKey:key] atomically:YES];
}

- (NSArray *)files {
    NSMutableArray *files = [NSMutableArray array];
    NSFileManager *manager = [NSFileManager defaultManager];
    for (NSString *name in [manager contentsOfDirectoryAtPath:self.directory error:NULL]) {
        NSString *path = [self.directory stringByAppendingPathComponent:name];
        NSDictionary *attributes = [manager attributesOfItemAtPath:path error:NULL];
        if (![attributes[NSFileType] isEqualToString:NSFileTypeRegular]) continue;
        [files addObject:@{ @"path": path, @"size": attributes[NSFileSize] ?: @0,
                            @"date": attributes[NSFileModificationDate] ?: [NSDate distantPast] }];
    }
    return files;
}

- (unsigned long long)totalSize {
    unsigned long long total = 0;
    for (NSDictionary *file in [self files]) total += [file[@"size"] unsignedLongLongValue];
    return total;
}

- (void)trim {
    NSArray *files = [[self files] sortedArrayUsingComparator:^NSComparisonResult(NSDictionary *a, NSDictionary *b) {
        return [a[@"date"] compare:b[@"date"]];
    }];
    unsigned long long total = 0;
    for (NSDictionary *file in files) total += [file[@"size"] unsignedLongLongValue];
    if (total <= self.limit) return;
    unsigned long long target = self.limit / 4 * 3;
    for (NSDictionary *file in files) {
        if (total <= target) break;
        if ([[NSFileManager defaultManager] removeItemAtPath:file[@"path"] error:NULL]) {
            total -= [file[@"size"] unsignedLongLongValue];
        }
    }
}

@end
