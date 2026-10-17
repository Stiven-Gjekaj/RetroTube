#import "RTStreamSession.h"
#import "RTMP4.h"
#import "RTRemux.h"

// The number of segments that load before the player asks for them, by
// default. The network of the phone changes speed a lot, and two segments
// hide a slow moment. Each 720p segment is about 0.5 MB.
static const NSUInteger RTPrefetchDepth = 2;

static NSError *RTSessionError(NSString *text) {
    return [NSError errorWithDomain:@"RTStreamSession" code:1 userInfo:@{ NSLocalizedDescriptionKey: text }];
}

NSData *RTReadRange(NSURL *url, uint64_t start, uint64_t end, NSError **error) {
    NSError *last = nil;
    for (int attempt = 0; attempt < 3; attempt++) {
        // iOS 6 can give a cached answer for another range of the same URL.
        // So a range request does not use the cache.
        NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url
                                                               cachePolicy:NSURLRequestReloadIgnoringLocalCacheData
                                                           timeoutInterval:20];
        [request setValue:[NSString stringWithFormat:@"bytes=%llu-%llu", start, end] forHTTPHeaderField:@"Range"];
        NSHTTPURLResponse *response = nil;
        NSData *data = [NSURLConnection sendSynchronousRequest:request returningResponse:(NSURLResponse **)&response
                                                         error:&last];
        NSInteger status = response.statusCode;
        if (data && (status == 206 || status == 200)) {
            // A server that ignores the range gives the full file with 200.
            if (status == 200 && data.length > end) data = [data subdataWithRange:NSMakeRange((NSUInteger)start, (NSUInteger)(end - start + 1))];
            if (data.length == end - start + 1) return data;
            last = RTSessionError(@"The server gave fewer bytes than the range.");
        } else if (!last) {
            last = RTSessionError([NSString stringWithFormat:@"The video server answered with HTTP %ld.", (long)status]);
        }
        // A 403 does not change on a new attempt.
        if (status == 403 || status == 404) break;
    }
    if (error) *error = last;
    return nil;
}

@interface RTStreamSession ()
@property (nonatomic, strong) RTFormat *videoFormat;
@property (nonatomic, strong) RTFormat *audioFormat;
@property (nonatomic, copy) RTRangeReader reader;
@property (nonatomic, strong) RTMP4Track *videoTrack;
@property (nonatomic, strong) RTMP4Track *audioTrack;
@property (nonatomic, strong) RTMP4Index *videoIndex;
@property (nonatomic, strong) RTMP4Index *audioIndex;
@property (nonatomic, strong) NSCache *segments;
@property (nonatomic, strong) NSCache *audioBlocks;
@property (nonatomic, strong) NSMutableSet *audioLoading;
@property (nonatomic, strong) NSMutableSet *loading;
@property (nonatomic, strong) NSCondition *condition;
@property (nonatomic, strong) dispatch_queue_t prefetchQueue;
// Only one segment downloads at a time. On a slow network, two downloads
// share the bandwidth, and the segment that the player waits for comes later.
@property (nonatomic, strong) dispatch_semaphore_t buildSlot;
@property (nonatomic) NSUInteger waitingRequests;  // Requests of the player that wait for the slot
@end

@implementation RTStreamSession

- (instancetype)initWithVideo:(RTFormat *)video audio:(RTFormat *)audio {
    return [self initWithVideo:video audio:audio reader:^NSData *(NSURL *url, uint64_t start, uint64_t end, NSError **error) {
        return RTReadRange(url, start, end, error);
    }];
}

- (instancetype)initWithVideo:(RTFormat *)video audio:(RTFormat *)audio reader:(RTRangeReader)reader {
    if ((self = [super init])) {
        _videoFormat = video;
        _audioFormat = audio;
        _reader = [reader copy];
        _segments = [NSCache new];
        _segments.countLimit = RTPrefetchDepth + 3;  // The segments ahead, this one, and two behind
        _loading = [NSMutableSet set];
        // A sound block of YouTube is about 10 seconds, and a segment is 3 to
        // 7 seconds. Keep the blocks, so that the next segment does not read
        // the same block again.
        _audioBlocks = [NSCache new];
        _audioBlocks.countLimit = 6;
        _audioLoading = [NSMutableSet set];
        _condition = [NSCondition new];
        _prefetchQueue = dispatch_queue_create("RTStreamSession.prefetch", DISPATCH_QUEUE_SERIAL);
        _buildSlot = dispatch_semaphore_create(1);
        _prefetchDepth = RTPrefetchDepth;
    }
    return self;
}

// Reads the init segment and the index of a stream. They are at the start of
// the file. The index ends at the end of indexRange.
- (BOOL)readHeadOf:(RTFormat *)format track:(RTMP4Track **)track index:(RTMP4Index **)index error:(NSError **)error {
    if (format.indexRange.location == NSNotFound) {
        if (error) *error = RTSessionError(@"The stream has no index range.");
        return NO;
    }
    uint64_t end = NSMaxRange(format.indexRange) - 1;
    NSData *head = self.reader(format.url, 0, end, error);
    if (!head) return NO;
    *track = RTMP4ReadInit(head, error);
    if (!*track) return NO;
    NSUInteger at = format.indexRange.location;
    *index = RTMP4ReadIndex([head subdataWithRange:NSMakeRange(at, head.length - at)], at, error);
    return *index != nil && (*index).count > 0;
}

- (BOOL)prepare:(NSError **)error {
    RTMP4Track *track = nil;
    RTMP4Index *index = nil;
    if (![self readHeadOf:self.videoFormat track:&track index:&index error:error]) return NO;
    if (!track.isVideo) {
        if (error) *error = RTSessionError(@"The video stream has no video track.");
        return NO;
    }
    self.videoTrack = track;
    self.videoIndex = index;
    if (self.audioFormat) {
        if (![self readHeadOf:self.audioFormat track:&track index:&index error:error]) return NO;
        self.audioTrack = track;
        self.audioIndex = index;
    }
    return YES;
}

- (NSUInteger)segmentCount {
    return self.videoIndex.count;
}

- (NSData *)dataForPath:(NSString *)path contentType:(NSString **)contentType status:(NSInteger *)status {
    if ([path isEqualToString:@"index.m3u8"]) {
        *contentType = @"application/vnd.apple.mpegurl";
        *status = 200;
        return [self playlist];
    }
    // A segment is "<number>.ts", with no sign and no leading text.
    NSString *number = [path hasSuffix:@".ts"] ? [path stringByDeletingPathExtension] : nil;
    NSInteger index = number.integerValue;
    if (!number.length || index < 0 || ![[NSString stringWithFormat:@"%ld", (long)index] isEqualToString:number] ||
        (NSUInteger)index >= self.segmentCount) {
        *status = 404;
        return nil;
    }
    NSData *segment = [self segmentAtIndex:(NSUInteger)index error:NULL];
    *contentType = @"video/mp2t";
    *status = segment ? 200 : 502;
    return segment;
}

- (double)startOfSegment:(NSUInteger)index {
    return (double)[self.videoIndex entryAtIndex:index].startTime / self.videoIndex.timescale;
}

- (double)durationOfSegment:(NSUInteger)index {
    return (double)[self.videoIndex entryAtIndex:index].duration / self.videoIndex.timescale;
}

- (NSData *)playlist {
    double longest = 0;
    for (NSUInteger i = 0; i < self.segmentCount; i++) longest = MAX(longest, [self durationOfSegment:i]);
    NSMutableString *text = [NSMutableString stringWithString:@"#EXTM3U\n#EXT-X-VERSION:3\n"];
    [text appendFormat:@"#EXT-X-TARGETDURATION:%d\n", (int)ceil(longest)];
    [text appendString:@"#EXT-X-MEDIA-SEQUENCE:0\n#EXT-X-PLAYLIST-TYPE:VOD\n"];
    for (NSUInteger i = 0; i < self.segmentCount; i++) {
        [text appendFormat:@"#EXTINF:%.3f,\n%lu.ts\n", [self durationOfSegment:i], (unsigned long)i];
    }
    [text appendString:@"#EXT-X-ENDLIST\n"];
    return [text dataUsingEncoding:NSUTF8StringEncoding];
}

// Gives one sound block from the cache, or reads it. Two requests for the
// same block read it one time: the second waits for the first.
- (NSData *)audioBlock:(NSUInteger)index error:(NSError **)error {
    NSNumber *key = @(index);
    [self.condition lock];
    NSData *data = [self.audioBlocks objectForKey:key];
    while (!data && [self.audioLoading containsObject:key]) {
        [self.condition wait];
        data = [self.audioBlocks objectForKey:key];
    }
    if (!data) [self.audioLoading addObject:key];
    [self.condition unlock];
    if (data) return data;

    RTMP4IndexEntry entry = [self.audioIndex entryAtIndex:index];
    data = self.reader(self.audioFormat.url, entry.offset, entry.offset + entry.size - 1, error);
    [self.condition lock];
    if (data) [self.audioBlocks setObject:data forKey:key];
    [self.audioLoading removeObject:key];
    [self.condition broadcast];
    [self.condition unlock];
    return data;
}

// Gives the sound blocks that overlap [start, end) seconds, joined.
- (NSData *)audioFrom:(double)start to:(double)end error:(NSError **)error {
    RTMP4Index *index = self.audioIndex;
    NSMutableData *joined = [NSMutableData data];
    for (NSUInteger i = 0; i < index.count; i++) {
        RTMP4IndexEntry entry = [index entryAtIndex:i];
        double entryStart = (double)entry.startTime / index.timescale;
        double entryEnd = (double)(entry.startTime + entry.duration) / index.timescale;
        if (entryEnd > start && entryStart < end) {
            NSData *block = [(self.audioOwner ?: self) audioBlock:i error:error];
            if (!block) return nil;
            [joined appendData:block];
        }
    }
    return joined;
}

- (NSData *)buildSegment:(NSUInteger)index error:(NSError **)error {
    // The first segment takes the audio from 0. The last takes the rest.
    double start = index == 0 ? 0 : [self startOfSegment:index];
    double end = index + 1 == self.segmentCount ? 1e9 : [self startOfSegment:index + 1];

    // Read the sound on another thread while this thread reads the video.
    __block NSData *audio = nil;
    __block NSError *audioError = nil;
    dispatch_group_t group = dispatch_group_create();
    if (self.audioTrack) {
        dispatch_group_async(group, dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^{
            NSError *readError = nil;
            audio = [self audioFrom:start to:end error:&readError];
            audioError = readError;
        });
    }
    RTMP4IndexEntry entry = [self.videoIndex entryAtIndex:index];
    NSData *video = self.reader(self.videoFormat.url, entry.offset, entry.offset + entry.size - 1, error);
    dispatch_group_wait(group, DISPATCH_TIME_FOREVER);
    if (!video) return nil;
    if (self.audioTrack && !audio) {
        if (error) *error = audioError;
        return nil;
    }
    return RTRemuxSegment(self.videoTrack, video, self.audioTrack, audio, start, end, error);
}

// Gives the segment from the cache, or builds it. Two requests for the same
// segment build it one time: the second waits for the first.
- (NSData *)segmentAtIndex:(NSUInteger)index error:(NSError **)error {
    if (index >= self.segmentCount) {
        if (error) *error = RTSessionError(@"The segment does not exist.");
        return nil;
    }
    NSNumber *key = @(index);
    [self.condition lock];
    NSData *data = [self.segments objectForKey:key];
    while (!data && [self.loading containsObject:key]) {
        [self.condition wait];
        data = [self.segments objectForKey:key];
    }
    if (!data) [self.loading addObject:key];
    [self.condition unlock];

    if (!data) {
        [self.condition lock];
        self.waitingRequests++;
        [self.condition unlock];
        dispatch_semaphore_wait(self.buildSlot, DISPATCH_TIME_FOREVER);
        [self.condition lock];
        self.waitingRequests--;
        [self.condition unlock];
        data = [self buildSegment:index error:error];
        dispatch_semaphore_signal(self.buildSlot);
        [self.condition lock];
        if (data) [self.segments setObject:data forKey:key];
        [self.loading removeObject:key];
        [self.condition broadcast];
        [self.condition unlock];
    }
    if (data) {
        for (NSUInteger next = index + 1; next <= index + self.prefetchDepth; next++) [self prefetch:next];
    }
    return data;
}

- (void)prefetch:(NSUInteger)index {
    if (index >= self.segmentCount) return;
    NSNumber *key = @(index);
    [self.condition lock];
    BOOL needed = ![self.segments objectForKey:key] && ![self.loading containsObject:key];
    [self.condition unlock];
    if (!needed) return;
    __weak RTStreamSession *weakSelf = self;
    dispatch_async(self.prefetchQueue, ^{
        RTStreamSession *session = weakSelf;
        if (!session) return;
        NSNumber *k = @(index);
        // A request of the player goes first. The next request of the player
        // starts the prefetch again.
        dispatch_semaphore_wait(session.buildSlot, DISPATCH_TIME_FOREVER);
        [session.condition lock];
        BOOL stillNeeded = ![session.segments objectForKey:k] && ![session.loading containsObject:k] &&
                           session.waitingRequests == 0;
        if (stillNeeded) [session.loading addObject:k];
        [session.condition unlock];
        if (!stillNeeded) {
            dispatch_semaphore_signal(session.buildSlot);
            return;
        }
        NSData *data = [session buildSegment:index error:NULL];
        dispatch_semaphore_signal(session.buildSlot);
        [session.condition lock];
        if (data) [session.segments setObject:data forKey:k];
        [session.loading removeObject:k];
        [session.condition broadcast];
        [session.condition unlock];
    });
}

@end
