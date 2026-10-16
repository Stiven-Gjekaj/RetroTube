#import "RTPlayer.h"

static NSDictionary *RTDict(id object) {
    return [object isKindOfClass:[NSDictionary class]] ? object : nil;
}

static NSString *RTString(id object) {
    return [object isKindOfClass:[NSString class]] ? object : nil;
}

// InnerTube writes many numbers as strings. Accept both.
static long long RTNumber(id object) {
    if ([object isKindOfClass:[NSNumber class]] || [object isKindOfClass:[NSString class]]) return [object longLongValue];
    return 0;
}

static NSRange RTByteRange(id object) {
    NSDictionary *dict = RTDict(object);
    if (!dict[@"start"] || !dict[@"end"]) return NSMakeRange(NSNotFound, 0);
    long long start = RTNumber(dict[@"start"]), end = RTNumber(dict[@"end"]);
    if (end < start) return NSMakeRange(NSNotFound, 0);
    return NSMakeRange((NSUInteger)start, (NSUInteger)(end - start + 1));
}

@implementation RTFormat

- (NSString *)description {
    return [NSString stringWithFormat:@"<RTFormat %ld %ldp %@>", (long)self.itag, (long)self.height, self.mimeType];
}

@end

@implementation RTPlayerInfo

- (RTFormat *)videoFormatForMaxHeight:(NSInteger)maxHeight {
    for (RTFormat *format in self.videoFormats) {
        if (format.height <= maxHeight && format.fps <= 30) return format;
    }
    return nil;
}

- (RTFormat *)audioFormat {
    return self.audioFormats.firstObject;
}

@end

static RTFormat *RTParseFormat(NSDictionary *f) {
    NSString *url = RTString(f[@"url"]);
    if (!url) return nil;  // A ciphered stream needs the web player. Skip it.
    RTFormat *format = [RTFormat new];
    format.itag = (NSInteger)RTNumber(f[@"itag"]);
    format.url = [NSURL URLWithString:url];
    format.mimeType = RTString(f[@"mimeType"]);
    format.width = (NSInteger)RTNumber(f[@"width"]);
    format.height = (NSInteger)RTNumber(f[@"height"]);
    format.fps = (NSInteger)RTNumber(f[@"fps"]);
    format.bitrate = (NSInteger)RTNumber(f[@"bitrate"]);
    format.contentLength = RTNumber(f[@"contentLength"]);
    format.initRange = RTByteRange(f[@"initRange"]);
    format.indexRange = RTByteRange(f[@"indexRange"]);
    return format.url ? format : nil;
}

// A dubbed or a DRC audio stream is not the first choice.
static BOOL RTIsOriginalAudio(NSDictionary *f) {
    if ([f[@"isDrc"] boolValue]) return NO;
    NSDictionary *track = RTDict(f[@"audioTrack"]);
    return !track || [track[@"audioIsDefault"] boolValue];
}

RTPlayerInfo *RTParsePlayer(NSDictionary *json) {
    RTPlayerInfo *info = [RTPlayerInfo new];
    NSDictionary *playability = RTDict(json[@"playabilityStatus"]);
    info.status = RTString(playability[@"status"]) ?: @"ERROR";
    info.reason = RTString(playability[@"reason"]);

    NSDictionary *details = RTDict(json[@"videoDetails"]);
    info.videoId = RTString(details[@"videoId"]);
    info.title = RTString(details[@"title"]);
    info.author = RTString(details[@"author"]);
    info.channelId = RTString(details[@"channelId"]);
    info.shortDescription = RTString(details[@"shortDescription"]);
    info.lengthSeconds = (NSInteger)RTNumber(details[@"lengthSeconds"]);
    info.viewCount = RTNumber(details[@"viewCount"]);
    info.isLive = [details[@"isLive"] boolValue];

    NSDictionary *streaming = RTDict(json[@"streamingData"]);
    NSString *hls = RTString(streaming[@"hlsManifestUrl"]);
    if (hls) info.hlsManifestURL = [NSURL URLWithString:hls];

    NSMutableArray *videos = [NSMutableArray array];
    NSMutableArray *original = [NSMutableArray array];
    NSMutableArray *otherAudio = [NSMutableArray array];
    id adaptive = streaming[@"adaptiveFormats"];
    for (id item in ([adaptive isKindOfClass:[NSArray class]] ? adaptive : nil)) {
        NSDictionary *f = RTDict(item);
        RTFormat *format = f ? RTParseFormat(f) : nil;
        if (!format) continue;
        if ([format.mimeType hasPrefix:@"video/mp4"] && [format.mimeType rangeOfString:@"avc1"].location != NSNotFound) {
            [videos addObject:format];
        } else if ([format.mimeType hasPrefix:@"audio/mp4"] &&
                   [format.mimeType rangeOfString:@"mp4a.40.2"].location != NSNotFound) {
            [(RTIsOriginalAudio(f) ? original : otherAudio) addObject:format];
        }
    }
    [videos sortUsingComparator:^NSComparisonResult(RTFormat *a, RTFormat *b) {
        if (a.height != b.height) return a.height > b.height ? NSOrderedAscending : NSOrderedDescending;
        if (a.bitrate != b.bitrate) return a.bitrate > b.bitrate ? NSOrderedAscending : NSOrderedDescending;
        return NSOrderedSame;
    }];
    info.videoFormats = videos;
    info.audioFormats = [original arrayByAddingObjectsFromArray:otherAudio];
    return info;
}
