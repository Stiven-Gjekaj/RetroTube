#import "RTTest.h"
#import "RTDiskCache.h"

@interface RTDiskCache (Testing)
- (NSString *)pathForKey:(NSString *)key;
@end

static NSString *TempDirectory(void) {
    NSString *name = [NSString stringWithFormat:@"rtcache-%@", [[NSProcessInfo processInfo] globallyUniqueString]];
    return [NSTemporaryDirectory() stringByAppendingPathComponent:name];
}

static NSData *Bytes(NSUInteger count) {
    return [NSMutableData dataWithLength:count];
}

RT_TEST(test_disk_cache_keeps_data) {
    NSString *directory = TempDirectory();
    RTDiskCache *cache = [[RTDiskCache alloc] initWithDirectory:directory limit:1000];
    NSData *data = [@"picture" dataUsingEncoding:NSUTF8StringEncoding];
    [cache setData:data forKey:@"https://i.ytimg.com/vi/abc/mqdefault.jpg?x=1&y=/2"];
    RTDiskCache *again = [[RTDiskCache alloc] initWithDirectory:directory limit:1000];
    RT_EQUAL([again dataForKey:@"https://i.ytimg.com/vi/abc/mqdefault.jpg?x=1&y=/2"], data);
    RT_EXPECT([again dataForKey:@"https://i.ytimg.com/vi/other/mqdefault.jpg"] == nil);
    RT_EXPECT([again dataForKey:nil] == nil);
}

RT_TEST(test_disk_cache_trim_removes_oldest_first) {
    RTDiskCache *cache = [[RTDiskCache alloc] initWithDirectory:TempDirectory() limit:1000];
    for (int i = 0; i < 5; i++) {
        NSString *key = [NSString stringWithFormat:@"k%d", i];
        [cache setData:Bytes(300) forKey:key];
        // Give each file its own time, oldest first.
        [[NSFileManager defaultManager] setAttributes:@{ NSFileModificationDate: [NSDate dateWithTimeIntervalSince1970:1000 + i] }
                                         ofItemAtPath:[cache pathForKey:key]
                                                error:NULL];
    }
    RT_EQUAL_INT([cache totalSize], 1500);
    [cache trim];
    // The limit is 1000, so the target is 750: two files of 300 stay.
    RT_EQUAL_INT([cache totalSize], 600);
    RT_EXPECT([cache dataForKey:@"k0"] == nil);
    RT_EXPECT([cache dataForKey:@"k2"] == nil);
    RT_EXPECT([cache dataForKey:@"k3"] != nil);
    RT_EXPECT([cache dataForKey:@"k4"] != nil);
}

RT_TEST(test_disk_cache_trim_under_limit_keeps_all) {
    RTDiskCache *cache = [[RTDiskCache alloc] initWithDirectory:TempDirectory() limit:1000];
    [cache setData:Bytes(400) forKey:@"a"];
    [cache setData:Bytes(400) forKey:@"b"];
    [cache trim];
    RT_EQUAL_INT([cache totalSize], 800);
}
