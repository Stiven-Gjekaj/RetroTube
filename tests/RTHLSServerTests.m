#import "RTTest.h"
#import "RTHLSServer.h"

@interface StaticSource : NSObject <RTHLSSource>
- (NSData *)playlist;
@end

@implementation StaticSource

- (NSData *)playlist {
    return [@"#EXTM3U\n" dataUsingEncoding:NSUTF8StringEncoding];
}

// "index.m3u8", "0.ts", "1.ts", "deep/file.ts", and "broken.ts" (502).
- (NSData *)dataForPath:(NSString *)path contentType:(NSString **)contentType status:(NSInteger *)status {
    *status = 200;
    if ([path isEqualToString:@"index.m3u8"]) {
        *contentType = @"application/vnd.apple.mpegurl";
        return [self playlist];
    }
    if ([path isEqualToString:@"broken.ts"]) {
        *status = 502;
        return nil;
    }
    NSDictionary *fills = @{ @"0.ts": @1, @"1.ts": @2, @"deep/file.ts": @3 };
    if (!fills[path]) {
        *status = 404;
        return nil;
    }
    *contentType = @"video/mp2t";
    NSMutableData *data = [NSMutableData dataWithLength:300000];
    memset(data.mutableBytes, [fills[path] intValue], data.length);
    return data;
}

@end

static NSData *Get(NSURL *url, NSInteger *status, NSString **type) {
    NSHTTPURLResponse *response = nil;
    NSURLRequest *request = [NSURLRequest requestWithURL:url cachePolicy:NSURLRequestReloadIgnoringLocalCacheData
                                         timeoutInterval:5];
    NSData *data = [NSURLConnection sendSynchronousRequest:request returningResponse:(NSURLResponse **)&response error:NULL];
    *status = response.statusCode;
    if (type) *type = response.allHeaderFields[@"Content-Type"];
    return data;
}

RT_TEST(test_server_serves_playlist_and_segments) {
    RTHLSServer *server = [RTHLSServer new];
    NSError *error = nil;
    RT_EXPECT([server start:&error]);
    RT_EXPECT(server.port > 0);
    StaticSource *source = [StaticSource new];
    NSURL *playlist = [server addSource:source];
    RT_EQUAL(playlist.host, @"127.0.0.1");
    RT_EQUAL(playlist.lastPathComponent, @"index.m3u8");

    NSInteger status = 0;
    NSString *type = nil;
    NSData *body = Get(playlist, &status, &type);
    RT_EQUAL_INT(status, 200);
    RT_EQUAL(type, @"application/vnd.apple.mpegurl");
    RT_EQUAL(body, [source playlist]);

    NSData *segment = Get([NSURL URLWithString:@"1.ts" relativeToURL:playlist], &status, &type);
    RT_EQUAL_INT(status, 200);
    RT_EQUAL(type, @"video/mp2t");
    RT_EQUAL_INT(segment.length, 300000);
    RT_EQUAL_INT(((const uint8_t *)segment.bytes)[299999], 2);
    [server stop];
}

RT_TEST(test_server_gives_status_of_source) {
    RTHLSServer *server = [RTHLSServer new];
    [server start:NULL];
    NSURL *playlist = [server addSource:[StaticSource new]];
    NSInteger status = 0;
    Get([NSURL URLWithString:@"broken.ts" relativeToURL:playlist], &status, NULL);
    RT_EQUAL_INT(status, 502);
    Get([NSURL URLWithString:@"other.txt" relativeToURL:playlist], &status, NULL);
    RT_EQUAL_INT(status, 404);
    NSString *missing = [NSString stringWithFormat:@"http://127.0.0.1:%u/nothing/index.m3u8", server.port];
    Get([NSURL URLWithString:missing], &status, NULL);
    RT_EQUAL_INT(status, 404);
    [server stop];
}

RT_TEST(test_server_passes_deep_paths) {
    RTHLSServer *server = [RTHLSServer new];
    [server start:NULL];
    NSURL *playlist = [server addSource:[StaticSource new]];
    NSInteger status = 0;
    NSData *data = Get([NSURL URLWithString:@"deep/file.ts" relativeToURL:playlist], &status, NULL);
    RT_EQUAL_INT(status, 200);
    RT_EQUAL_INT(((const uint8_t *)data.bytes)[0], 3);
    [server stop];
}

RT_TEST(test_server_forgets_removed_source) {
    RTHLSServer *server = [RTHLSServer new];
    [server start:NULL];
    StaticSource *source = [StaticSource new];
    NSURL *playlist = [server addSource:source];
    [server removeSource:source];
    NSInteger status = 0;
    Get(playlist, &status, NULL);
    RT_EQUAL_INT(status, 404);
    [server stop];
}
