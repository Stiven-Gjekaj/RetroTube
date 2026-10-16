#import "RTStreamSession.h"
#import "RTMP4.h"
#import "RTRemux.h"

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
@property (nonatomic, strong) NSMutableSet *loading;
@property (nonatomic, strong) NSCondition *condition;
@property (nonatomic, strong) dispatch_queue_t prefetchQueue;
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
        _segments.countLimit = 3;
        _loading = [NSMutableSet set];
        _condition = [NSCondition new];
        _prefetchQueue = dispatch_queue_create("RTStreamSession.prefetch", DISPATCH_QUEUE_SERIAL);
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

// Reads the audio entries that overlap [start, end) seconds, as one range.
- (NSData *)audioFrom:(double)start to:(double)end error:(NSError **)error {
    RTMP4Index *index = self.audioIndex;
    NSUInteger first = NSNotFound, last = 0;
    for (NSUInteger i = 0; i < index.count; i++) {
        RTMP4IndexEntry entry = [index entryAtIndex:i];
        double entryStart = (double)entry.startTime / index.timescale;
        double entryEnd = (double)(entry.startTime + entry.duration) / index.timescale;
        if (entryEnd > start && entryStart < end) {
            if (first == NSNotFound) first = i;
            last = i;
        }
    }
    if (first == NSNotFound) return [NSData data];
    RTMP4IndexEntry a = [index entryAtIndex:first], b = [index entryAtIndex:last];
    return self.reader(self.audioFormat.url, a.offset, b.offset + b.size - 1, error);
}

- (NSData *)buildSegment:(NSUInteger)index error:(NSError **)error {
    RTMP4IndexEntry entry = [self.videoIndex entryAtIndex:index];
    NSData *video = self.reader(self.videoFormat.url, entry.offset, entry.offset + entry.size - 1, error);
    if (!video) return nil;
    // The first segment takes the audio from 0. The last takes the rest.
    double start = index == 0 ? 0 : [self startOfSegment:index];
    double end = index + 1 == self.segmentCount ? 1e9 : [self startOfSegment:index + 1];
    NSData *audio = nil;
    if (self.audioTrack) {
        audio = [self audioFrom:start to:end error:error];
        if (!audio) return nil;
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
        data = [self buildSegment:index error:error];
        [self.condition lock];
        if (data) [self.segments setObject:data forKey:key];
        [self.loading removeObject:key];
        [self.condition broadcast];
        [self.condition unlock];
    }
    if (data) [self prefetch:index + 1];
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
        [session.condition lock];
        BOOL stillNeeded = ![session.segments objectForKey:k] && ![session.loading containsObject:k];
        if (stillNeeded) [session.loading addObject:k];
        [session.condition unlock];
        if (!stillNeeded) return;
        NSData *data = [session buildSegment:index error:NULL];
        [session.condition lock];
        if (data) [session.segments setObject:data forKey:k];
        [session.loading removeObject:k];
        [session.condition broadcast];
        [session.condition unlock];
    });
}

@end
