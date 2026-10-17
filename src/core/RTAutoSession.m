#import "RTAutoSession.h"

@interface RTAutoSession ()
@property (nonatomic, copy) NSArray *candidates;
@property (nonatomic, strong) NSArray *sessions;
@end

@implementation RTAutoSession

+ (NSArray *)autoHeights {
    return @[ @720, @480, @360, @240 ];
}

- (instancetype)initWithVideos:(NSArray *)videoFormats audio:(RTFormat *)audio {
    return [self initWithVideos:videoFormats audio:audio reader:^NSData *(NSURL *url, uint64_t start, uint64_t end,
                                                                          NSError **error) {
        return RTReadRange(url, start, end, error);
    }];
}

- (instancetype)initWithVideos:(NSArray *)videoFormats audio:(RTFormat *)audio reader:(RTRangeReader)reader {
    if ((self = [super init])) {
        // The player starts with the first quality of the main playlist.
        // 360p starts fast and looks good on the screen of the iPhone 4S.
        NSArray *sorted = [videoFormats sortedArrayUsingComparator:^NSComparisonResult(RTFormat *a, RTFormat *b) {
            NSInteger da = labs(a.height - 360), db = labs(b.height - 360);
            if (da != db) return da < db ? NSOrderedAscending : NSOrderedDescending;
            return a.height > b.height ? NSOrderedAscending : NSOrderedDescending;
        }];
        NSMutableArray *candidates = [NSMutableArray array];
        for (RTFormat *format in sorted) {
            RTStreamSession *session = [[RTStreamSession alloc] initWithVideo:format audio:audio reader:reader];
            // The player measures the speed of the network by the time that
            // a segment takes. A segment that loaded before the request
            // looks like a very fast network. So Auto loads no segment early.
            session.prefetchDepth = 0;
            [candidates addObject:session];
        }
        _candidates = candidates;
    }
    return self;
}

static NSArray *RTSegmentTimes(RTStreamSession *session) {
    NSMutableArray *times = [NSMutableArray arrayWithCapacity:session.segmentCount];
    for (NSUInteger i = 0; i < session.segmentCount; i++) {
        [times addObject:@((long long)llround([session durationOfSegment:i] * 1000))];
    }
    return times;
}

- (BOOL)prepare:(NSError **)error {
    NSUInteger count = self.candidates.count;
    __block BOOL *ready = calloc(count, sizeof(BOOL));
    __block NSError *firstError = nil;
    NSObject *lock = [NSObject new];
    dispatch_apply(count, dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^(size_t i) {
        NSError *prepareError = nil;
        ready[i] = [self.candidates[i] prepare:&prepareError];
        if (!ready[i]) {
            @synchronized (lock) {
                if (!firstError) firstError = prepareError;
            }
        }
    });
    NSMutableArray *kept = [NSMutableArray array];
    NSArray *times = nil;
    for (NSUInteger i = 0; i < count; i++) {
        if (!ready[i]) continue;
        RTStreamSession *session = self.candidates[i];
        NSArray *sessionTimes = RTSegmentTimes(session);
        if (!times) times = sessionTimes;
        // A quality with other segment times cannot change with the others.
        if (![sessionTimes isEqualToArray:times]) continue;
        if (kept.count) session.audioOwner = kept[0];
        [kept addObject:session];
    }
    free(ready);
    self.sessions = kept;
    if (!kept.count && error) *error = firstError;
    return kept.count > 0;
}

// The CODECS value of HLS, for example "avc1.4D401F,mp4a.40.2".
static NSString *RTCodecs(RTFormat *video, RTFormat *audio) {
    NSString *codec = nil;
    NSRange start = [video.mimeType rangeOfString:@"codecs=\""];
    if (start.location != NSNotFound) {
        NSString *rest = [video.mimeType substringFromIndex:NSMaxRange(start)];
        codec = [[rest componentsSeparatedByString:@"\""] firstObject];
    }
    if (!codec.length) codec = @"avc1.4D401F";
    return audio ? [codec stringByAppendingString:@",mp4a.40.2"] : codec;
}

- (NSData *)masterPlaylist {
    NSMutableString *text = [NSMutableString stringWithString:@"#EXTM3U\n#EXT-X-VERSION:3\n"];
    [self.sessions enumerateObjectsUsingBlock:^(RTStreamSession *session, NSUInteger index, BOOL *stop) {
        RTFormat *video = session.videoFormat, *audio = session.audioFormat;
        NSInteger bandwidth = video.bitrate + audio.bitrate;
        if (bandwidth <= 0) bandwidth = 500000;
        [text appendFormat:@"#EXT-X-STREAM-INF:BANDWIDTH=%ld,RESOLUTION=%ldx%ld,CODECS=\"%@\"\nv%lu/index.m3u8\n",
                           (long)bandwidth, (long)video.width, (long)video.height, RTCodecs(video, audio),
                           (unsigned long)index];
    }];
    return [text dataUsingEncoding:NSUTF8StringEncoding];
}

- (NSData *)dataForPath:(NSString *)path contentType:(NSString **)contentType status:(NSInteger *)status {
    if ([path isEqualToString:@"index.m3u8"]) {
        *contentType = @"application/vnd.apple.mpegurl";
        *status = 200;
        return [self masterPlaylist];
    }
    // "v<n>/<file>" goes to the session of quality n.
    NSRange slash = [path rangeOfString:@"/"];
    NSString *name = slash.location != NSNotFound ? [path substringToIndex:slash.location] : nil;
    NSString *number = [name hasPrefix:@"v"] ? [name substringFromIndex:1] : nil;
    NSInteger index = number.integerValue;
    if (!number.length || ![[NSString stringWithFormat:@"%ld", (long)index] isEqualToString:number] || index < 0 ||
        (NSUInteger)index >= self.sessions.count) {
        *status = 404;
        return nil;
    }
    return [self.sessions[(NSUInteger)index] dataForPath:[path substringFromIndex:NSMaxRange(slash)]
                                             contentType:contentType status:status];
}

@end

NSArray *RTAutoFormats(RTPlayerInfo *info, NSInteger maxHeight) {
    NSMutableArray *formats = [NSMutableArray array];
    for (NSNumber *height in [RTAutoSession autoHeights]) {
        if (height.integerValue > maxHeight) continue;
        // videoFormats is highest first, then highest bitrate first.
        for (RTFormat *format in info.videoFormats) {
            if (format.height == height.integerValue && format.fps <= 30) {
                [formats addObject:format];
                break;
            }
        }
    }
    return formats;
}
