// Keeps small files, such as thumbnails, in a directory. When the files are
// larger than the limit, the oldest files go first.

#import <Foundation/Foundation.h>

@interface RTDiskCache : NSObject

// limit is the largest total size in bytes.
- (instancetype)initWithDirectory:(NSString *)directory limit:(unsigned long long)limit;

- (NSData *)dataForKey:(NSString *)key;
- (void)setData:(NSData *)data forKey:(NSString *)key;

// Removes the oldest files until the total is under three quarters of the
// limit. It does nothing when the total is under the limit. It blocks.
- (void)trim;

// The total size of the files, in bytes.
- (unsigned long long)totalSize;

@end
