#import "RTTest.h"
#import "RTStreamSession.h"
#import "RTAutoSession.h"
#import "RTTS.h"
#import "RTBoxBuilder.h"
#import "RTInnerTube.h"
#import "RTPlayer.h"

// A DASH file in memory: init, sidx, and the fragments.
@interface FakeFile : NSObject
@property (nonatomic, strong) NSData *data;
@property (nonatomic) NSRange indexRange;
@end

@implementation FakeFile
@end

static NSData *IndexBox(uint32_t timescale, NSArray *fragments, NSArray *durations) {
    return Box("sidx", @[ Bytes(^(NSMutableData *d) {
        Put32(d, 0);
        Put32(d, 1);
        Put32(d, timescale);
        Put32(d, 0);
        Put32(d, 0);
        Put16(d, 0);
        Put16(d, (uint16_t)fragments.count);
        for (NSUInteger i = 0; i < fragments.count; i++) {
            Put32(d, (uint32_t)[fragments[i] length]);
            Put32(d, [durations[i] unsignedIntValue]);
            Put32(d, 0x90000000);
        }
    }) ]);
}

static FakeFile *MakeFile(NSData *init, uint32_t timescale, NSArray *fragments, NSArray *durations) {
    NSData *sidx = IndexBox(timescale, fragments, durations);
    NSMutableData *data = [init mutableCopy];
    FakeFile *file = [FakeFile new];
    file.indexRange = NSMakeRange(data.length, sidx.length);
    [data appendData:sidx];
    for (NSData *fragment in fragments) [data appendData:fragment];
    file.data = data;
    return file;
}

static NSData *Slice(uint8_t fill) {
    NSMutableData *d = [NSMutableData data];
    Put32(d, 2);
    Put8(d, 0x65);
    Put8(d, fill);
    return d;
}

// Video: 3 segments of 2 s at 1000 units each second, one frame each second.
static FakeFile *VideoFile(void) {
    NSMutableArray *fragments = [NSMutableArray array];
    for (int i = 0; i < 3; i++) {
        [fragments addObject:FragmentWithSamples((uint64_t)i * 2000, @[ Slice((uint8_t)i), Slice((uint8_t)i) ], 1000, 0)];
    }
    return MakeFile(Init(Hdlr("vide"), 1000, VideoEntry(), @[]), 1000, fragments, @[ @2000, @2000, @2000 ]);
}

// Audio: 2 entries of 3 s, one frame each 0.5 s.
static FakeFile *AudioFile(void) {
    NSMutableArray *fragments = [NSMutableArray array];
    for (int i = 0; i < 2; i++) {
        NSMutableArray *frames = [NSMutableArray array];
        for (int f = 0; f < 6; f++) [frames addObject:[NSMutableData dataWithLength:4]];
        [fragments addObject:FragmentWithSamples((uint64_t)i * 3000, frames, 500, 0)];
    }
    return MakeFile(Init(Hdlr("soun"), 1000, AudioEntry(), @[]), 1000, fragments, @[ @3000, @3000 ]);
}

static RTFormat *Format(FakeFile *file, NSString *name) {
    RTFormat *format = [RTFormat new];
    format.url = [NSURL URLWithString:[@"https://example.com/" stringByAppendingString:name]];
    format.indexRange = file.indexRange;
    format.initRange = NSMakeRange(0, file.indexRange.location);
    return format;
}

@interface Reads : NSObject
@property (nonatomic, strong) NSMutableArray *list;
@end

@implementation Reads
@end

static RTStreamSession *Session(Reads *reads) {
    FakeFile *video = VideoFile(), *audio = AudioFile();
    reads.list = [NSMutableArray array];
    NSMutableArray *list = reads.list;
    return [[RTStreamSession alloc] initWithVideo:Format(video, @"video") audio:Format(audio, @"audio")
        reader:^NSData *(NSURL *url, uint64_t start, uint64_t end, NSError **error) {
            @synchronized (list) {
                [list addObject:[NSString stringWithFormat:@"%@ %llu-%llu", url.lastPathComponent, start, end]];
            }
            NSData *data = [url.lastPathComponent isEqualToString:@"video"] ? video.data : audio.data;
            return [data subdataWithRange:NSMakeRange((NSUInteger)start, (NSUInteger)(end - start + 1))];
        }];
}

RT_TEST(test_session_prepare_reads_the_heads) {
    Reads *reads = [Reads new];
    RTStreamSession *session = Session(reads);
    NSError *error = nil;
    RT_EXPECT([session prepare:&error]);
    RT_EXPECT(error == nil);
    RT_EQUAL_INT(session.segmentCount, 3);
    RT_EQUAL_INT(reads.list.count, 2);
    RT_EXPECT([reads.list[0] hasPrefix:@"video 0-"]);
    RT_EXPECT([reads.list[1] hasPrefix:@"audio 0-"]);
}

RT_TEST(test_session_playlist_lists_segments) {
    RTStreamSession *session = Session([Reads new]);
    [session prepare:NULL];
    NSString *text = [[NSString alloc] initWithData:session.playlist encoding:NSUTF8StringEncoding];
    RT_EXPECT([text hasPrefix:@"#EXTM3U\n"]);
    RT_EXPECT([text rangeOfString:@"#EXT-X-TARGETDURATION:2\n"].location != NSNotFound);
    RT_EXPECT([text rangeOfString:@"#EXTINF:2.000,\n0.ts\n#EXTINF:2.000,\n1.ts\n#EXTINF:2.000,\n2.ts\n"].location != NSNotFound);
    RT_EXPECT([text hasSuffix:@"#EXT-X-ENDLIST\n"]);
}

static int CountPES(NSData *ts, uint16_t pid) {
    int count = 0;
    const uint8_t *b = ts.bytes;
    for (NSUInteger i = 0; i + RTTSPacketSize <= ts.length; i += RTTSPacketSize) {
        if ((((b[i + 1] & 0x1f) << 8) | b[i + 2]) == pid && (b[i + 1] & 0x40)) count++;
    }
    return count;
}

RT_TEST(test_session_segment_reads_only_the_audio_it_needs) {
    Reads *reads = [Reads new];
    RTStreamSession *session = Session(reads);
    [session prepare:NULL];
    [reads.list removeAllObjects];
    NSError *error = nil;
    // Segment 0 is [0 s, 2 s). Only the first audio entry overlaps it.
    NSData *ts = [session segmentAtIndex:0 error:&error];
    RT_EXPECT(error == nil);
    RT_EQUAL_INT(CountPES(ts, RTTSPidVideo), 2);
    RT_EQUAL_INT(CountPES(ts, RTTSPidAudio), 1);  // 4 frames in one PES
    // The video and the sound are read at the same time, in any order.
    NSArray *firstTwo = [[reads.list subarrayWithRange:NSMakeRange(0, 2)] sortedArrayUsingSelector:@selector(compare:)];
    RT_EXPECT([firstTwo[0] hasPrefix:@"audio "]);
    RT_EXPECT([firstTwo[1] hasPrefix:@"video "]);
    NSString *audioRange = firstTwo[0];
    NSString *expectedStart = [NSString stringWithFormat:@"audio %lu-",
                               (unsigned long)NSMaxRange(AudioFile().indexRange)];
    RT_EXPECT([audioRange hasPrefix:expectedStart]);
}

RT_TEST(test_session_segment_across_audio_entries) {
    RTStreamSession *session = Session([Reads new]);
    [session prepare:NULL];
    // Segment 1 is [2 s, 4 s). It needs both audio entries: 4 frames.
    NSData *ts = [session segmentAtIndex:1 error:NULL];
    RT_EQUAL_INT(CountPES(ts, RTTSPidAudio), 1);
    // The last segment takes the rest of the audio: [4 s, end) = 4 frames.
    NSData *last = [session segmentAtIndex:2 error:NULL];
    RT_EQUAL_INT(CountPES(last, RTTSPidAudio), 1);
}

static NSUInteger CountReads(Reads *reads, NSString *prefix) {
    NSUInteger count = 0;
    @synchronized (reads.list) {
        for (NSString *read in reads.list) {
            if ([read hasPrefix:prefix]) count++;
        }
    }
    return count;
}

RT_TEST(test_session_reads_each_sound_block_one_time) {
    Reads *reads = [Reads new];
    RTStreamSession *session = Session(reads);
    [session prepare:NULL];
    // Segments 0, 1, and 2 need the sound blocks 0, 0 and 1, and 1.
    for (NSUInteger i = 0; i < 3; i++) RT_EXPECT([session segmentAtIndex:i error:NULL] != nil);
    // The prefetch can still run. Wait for it.
    [NSThread sleepForTimeInterval:0.3];
    RT_EQUAL_INT(CountReads(reads, @"audio "), 1 + 2);  // the head, then each block one time
}

RT_TEST(test_session_loads_two_segments_ahead) {
    Reads *reads = [Reads new];
    RTStreamSession *session = Session(reads);
    [session prepare:NULL];
    [session segmentAtIndex:0 error:NULL];
    [NSThread sleepForTimeInterval:0.3];  // The prefetch runs.
    NSUInteger count = reads.list.count;
    RT_EXPECT([session segmentAtIndex:1 error:NULL] != nil);
    RT_EXPECT([session segmentAtIndex:2 error:NULL] != nil);
    // Segments 1 and 2 were ready. Only the prefetch of segment 3 and 4 can
    // read more, and the test file has no segment 3.
    RT_EQUAL_INT(CountReads(reads, @"video "), 1 + 3);  // the head, then segments 0, 1, and 2
    RT_EXPECT(reads.list.count == count);
}

RT_TEST(test_session_caches_segments) {
    Reads *reads = [Reads new];
    RTStreamSession *session = Session(reads);
    [session prepare:NULL];
    NSData *first = [session segmentAtIndex:2 error:NULL];
    NSUInteger count = reads.list.count;
    NSData *second = [session segmentAtIndex:2 error:NULL];
    RT_EQUAL(first, second);
    RT_EQUAL_INT(reads.list.count, count);
}

RT_TEST(test_session_gives_files_by_path) {
    RTStreamSession *session = Session([Reads new]);
    [session prepare:NULL];
    NSString *type = nil;
    NSInteger status = 0;
    NSData *playlist = [session dataForPath:@"index.m3u8" contentType:&type status:&status];
    RT_EQUAL_INT(status, 200);
    RT_EQUAL(type, @"application/vnd.apple.mpegurl");
    RT_EQUAL(playlist, session.playlist);
    NSData *segment = [session dataForPath:@"2.ts" contentType:&type status:&status];
    RT_EQUAL_INT(status, 200);
    RT_EQUAL(type, @"video/mp2t");
    RT_EXPECT(segment.length > 0);
    for (NSString *path in @[ @"3.ts", @"-1.ts", @"x1.ts", @"01.ts", @"2", @"other.txt", @"" ]) {
        status = 0;
        RT_EXPECT([session dataForPath:path contentType:&type status:&status] == nil);
        RT_EQUAL_INT(status, 404);
    }
}

RT_TEST(test_session_refuses_segment_past_the_end) {
    RTStreamSession *session = Session([Reads new]);
    [session prepare:NULL];
    NSError *error = nil;
    RT_EXPECT([session segmentAtIndex:3 error:&error] == nil);
    RT_EXPECT(error != nil);
}

RT_TEST(test_session_reads_video_and_sound_at_the_same_time) {
    FakeFile *video = VideoFile(), *audio = AudioFile();
    __block int active = 0, most = 0;
    NSObject *lock = [NSObject new];
    RTStreamSession *session = [[RTStreamSession alloc] initWithVideo:Format(video, @"video") audio:Format(audio, @"audio")
        reader:^NSData *(NSURL *url, uint64_t start, uint64_t end, NSError **error) {
            @synchronized (lock) {
                active++;
                most = MAX(most, active);
            }
            [NSThread sleepForTimeInterval:0.2];  // A slow network
            @synchronized (lock) {
                active--;
            }
            NSData *data = [url.lastPathComponent isEqualToString:@"video"] ? video.data : audio.data;
            return [data subdataWithRange:NSMakeRange((NSUInteger)start, (NSUInteger)(end - start + 1))];
        }];
    [session prepare:NULL];
    most = 0;
    NSDate *began = [NSDate date];
    RT_EXPECT([session segmentAtIndex:0 error:NULL] != nil);
    RT_EQUAL_INT(most, 2);
    RT_EXPECT([[NSDate date] timeIntervalSinceDate:began] < 0.35);
}

RT_TEST(test_session_downloads_one_segment_at_a_time) {
    FakeFile *video = VideoFile(), *audio = AudioFile();
    __block int active = 0, most = 0;
    NSObject *lock = [NSObject new];
    RTStreamSession *session = [[RTStreamSession alloc] initWithVideo:Format(video, @"video") audio:Format(audio, @"audio")
        reader:^NSData *(NSURL *url, uint64_t start, uint64_t end, NSError **error) {
            BOOL isVideo = [url.lastPathComponent isEqualToString:@"video"];
            if (isVideo) {
                @synchronized (lock) {
                    active++;
                    most = MAX(most, active);
                }
                [NSThread sleepForTimeInterval:0.1];
                @synchronized (lock) {
                    active--;
                }
            }
            NSData *data = isVideo ? video.data : audio.data;
            return [data subdataWithRange:NSMakeRange((NSUInteger)start, (NSUInteger)(end - start + 1))];
        }];
    [session prepare:NULL];
    most = 0;
    // The player asks for each segment as soon as it has the one before.
    for (NSUInteger i = 0; i < 3; i++) RT_EXPECT([session segmentAtIndex:i error:NULL] != nil);
    [NSThread sleepForTimeInterval:0.3];
    RT_EQUAL_INT(most, 1);
}

RT_TEST(test_session_segment_fails_when_sound_fails) {
    FakeFile *video = VideoFile(), *audio = AudioFile();
    RTStreamSession *session = [[RTStreamSession alloc] initWithVideo:Format(video, @"video") audio:Format(audio, @"audio")
        reader:^NSData *(NSURL *url, uint64_t start, uint64_t end, NSError **error) {
            BOOL isAudio = [url.lastPathComponent isEqualToString:@"audio"];
            if (isAudio && start > 0) {
                *error = [NSError errorWithDomain:@"test" code:403 userInfo:nil];
                return nil;
            }
            NSData *data = isAudio ? audio.data : video.data;
            return [data subdataWithRange:NSMakeRange((NSUInteger)start, (NSUInteger)(end - start + 1))];
        }];
    [session prepare:NULL];
    NSError *error = nil;
    RT_EXPECT([session segmentAtIndex:0 error:&error] == nil);
    RT_EQUAL_INT(error.code, 403);
}

RT_TEST(test_session_prepare_fails_with_reader_error) {
    RTFormat *format = Format(VideoFile(), @"video");
    RTStreamSession *session = [[RTStreamSession alloc] initWithVideo:format audio:nil
        reader:^NSData *(NSURL *url, uint64_t start, uint64_t end, NSError **error) {
            *error = [NSError errorWithDomain:@"test" code:403 userInfo:nil];
            return nil;
        }];
    NSError *error = nil;
    RT_EXPECT(![session prepare:&error]);
    RT_EQUAL_INT(error.code, 403);
}

RT_TEST(test_live_session_remuxes_a_real_video) {
    RT_LIVE_ONLY();
    RTPlayerInfo *info = [[[RTInnerTube alloc] initWithLanguage:@"en" region:@"US"] loadPlayer:@"a5uQMwRMHcs" error:NULL];
    RTStreamSession *session = [[RTStreamSession alloc] initWithVideo:[info videoFormatForMaxHeight:360]
                                                                audio:info.audioFormat];
    NSError *error = nil;
    RT_EXPECT([session prepare:&error]);
    RT_EXPECT(session.segmentCount >= 2);
    // The last segment is past the first minute of the file.
    NSData *ts = [session segmentAtIndex:session.segmentCount - 1 error:&error];
    if (error) RTTestFail(__FILE__, __LINE__, error.description);
    RT_EXPECT(ts.length > 10000);
    RT_EQUAL_INT(ts.length % RTTSPacketSize, 0);
    const uint8_t *b = ts.bytes;
    for (NSUInteger i = 0; i < ts.length; i += RTTSPacketSize) {
        if (b[i] != 0x47) {
            RT_EXPECT(b[i] == 0x47);
            break;
        }
    }
}

static RTFormat *Quality(FakeFile *file, NSString *name, NSInteger height, NSInteger bitrate) {
    RTFormat *format = Format(file, name);
    format.height = height;
    format.width = height * 16 / 9;
    format.bitrate = bitrate;
    format.mimeType = @"video/mp4; codecs=\"avc1.4D401E\"";
    return format;
}

// An Auto session over the fake files. Each quality reads the same video
// file under its own URL name.
static RTAutoSession *Auto(Reads *reads, NSArray *heights, FakeFile *odd) {
    FakeFile *video = VideoFile(), *audio = AudioFile();
    reads.list = [NSMutableArray array];
    NSMutableArray *list = reads.list;
    NSMutableArray *formats = [NSMutableArray array];
    for (NSNumber *height in heights) {
        [formats addObject:Quality(video, [NSString stringWithFormat:@"v%@", height], height.integerValue,
                                   height.integerValue * 1000)];
    }
    if (odd) [formats addObject:Quality(odd, @"odd", 144, 100)];
    RTFormat *sound = Format(audio, @"audio");
    sound.bitrate = 130000;
    return [[RTAutoSession alloc] initWithVideos:formats audio:sound
        reader:^NSData *(NSURL *url, uint64_t start, uint64_t end, NSError **error) {
            @synchronized (list) {
                [list addObject:[NSString stringWithFormat:@"%@ %llu-%llu", url.lastPathComponent, start, end]];
            }
            NSString *name = url.lastPathComponent;
            NSData *data = [name isEqualToString:@"audio"] ? audio.data : [name isEqualToString:@"odd"] ? odd.data : video.data;
            return [data subdataWithRange:NSMakeRange((NSUInteger)start, (NSUInteger)(end - start + 1))];
        }];
}

RT_TEST(test_auto_master_playlist_starts_near_360p) {
    RTAutoSession *session = Auto([Reads new], @[ @720, @480, @360, @240 ], nil);
    RT_EXPECT([session prepare:NULL]);
    NSString *text = [[NSString alloc] initWithData:session.masterPlaylist encoding:NSUTF8StringEncoding];
    NSArray *lines = [text componentsSeparatedByString:@"\n"];
    RT_EQUAL(lines[0], @"#EXTM3U");
    RT_EQUAL(lines[2], @"#EXT-X-STREAM-INF:BANDWIDTH=490000,RESOLUTION=640x360,CODECS=\"avc1.4D401E,mp4a.40.2\"");
    RT_EQUAL(lines[3], @"v0/index.m3u8");
    RT_EXPECT([text rangeOfString:@"RESOLUTION=1280x720"].location != NSNotFound);
    RT_EXPECT([text rangeOfString:@"v3/index.m3u8"].location != NSNotFound);
    RT_EQUAL([[session.sessions valueForKey:@"videoFormat"] valueForKey:@"height"], (@[ @360, @480, @240, @720 ]));
}

RT_TEST(test_auto_passes_paths_to_each_quality) {
    Reads *reads = [Reads new];
    RTAutoSession *session = Auto(reads, @[ @720, @360 ], nil);
    [session prepare:NULL];
    NSString *type = nil;
    NSInteger status = 0;
    NSData *playlist = [session dataForPath:@"v1/index.m3u8" contentType:&type status:&status];
    RT_EQUAL_INT(status, 200);
    RT_EQUAL(playlist, [session.sessions[1] playlist]);
    [reads.list removeAllObjects];
    NSData *segment = [session dataForPath:@"v1/0.ts" contentType:&type status:&status];
    RT_EQUAL_INT(status, 200);
    RT_EQUAL(type, @"video/mp2t");
    RT_EXPECT(segment.length > 0);
    RT_EXPECT([[reads.list componentsJoinedByString:@" "] rangeOfString:@"v720 "].location != NSNotFound);
    for (NSString *path in @[ @"v2/index.m3u8", @"x0/index.m3u8", @"v0", @"v01/0.ts", @"v0/9.ts", @"other" ]) {
        status = 0;
        RT_EXPECT([session dataForPath:path contentType:&type status:&status] == nil);
        RT_EQUAL_INT(status, 404);
    }
}

RT_TEST(test_auto_qualities_share_sound_and_load_nothing_early) {
    Reads *reads = [Reads new];
    RTAutoSession *session = Auto(reads, @[ @720, @360 ], nil);
    [session prepare:NULL];
    [reads.list removeAllObjects];
    NSString *type = nil;
    NSInteger status = 0;
    // The player changes from 360p to 720p after segment 0.
    [session dataForPath:@"v0/0.ts" contentType:&type status:&status];
    [session dataForPath:@"v1/1.ts" contentType:&type status:&status];
    [NSThread sleepForTimeInterval:0.3];
    NSUInteger video = 0, sound = 0;
    for (NSString *read in reads.list) {
        if ([read hasPrefix:@"audio "]) sound++;
        else video++;
    }
    RT_EQUAL_INT(video, 2);  // One for each segment, and no prefetch
    RT_EQUAL_INT(sound, 2);  // Sound blocks 0 and 1, each one time
}

RT_TEST(test_auto_drops_quality_with_other_segments) {
    // A file with two segments of 3 s, not three of 2 s.
    NSArray *fragments = @[ FragmentWithSamples(0, @[ Slice(1) ], 3000, 0), FragmentWithSamples(3000, @[ Slice(2) ], 3000, 0) ];
    FakeFile *odd = MakeFile(Init(Hdlr("vide"), 1000, VideoEntry(), @[]), 1000, fragments, @[ @3000, @3000 ]);
    RTAutoSession *session = Auto([Reads new], @[ @360, @240 ], odd);
    RT_EXPECT([session prepare:NULL]);
    RT_EQUAL([[session.sessions valueForKey:@"videoFormat"] valueForKey:@"height"], (@[ @360, @240 ]));
}

RT_TEST(test_auto_formats_pick_one_stream_for_each_height) {
    NSMutableArray *list = [NSMutableArray array];
    for (NSArray *spec in @[ @[ @1080, @30, @3000 ], @[ @720, @60, @2500 ], @[ @720, @30, @1200 ], @[ @720, @30, @1000 ],
                             @[ @480, @30, @600 ], @[ @240, @30, @200 ], @[ @144, @30, @100 ] ]) {
        RTFormat *format = [RTFormat new];
        format.height = [spec[0] integerValue];
        format.fps = [spec[1] integerValue];
        format.bitrate = [spec[2] integerValue];
        [list addObject:format];
    }
    RTPlayerInfo *info = [RTPlayerInfo new];
    info.videoFormats = list;
    NSArray *formats = RTAutoFormats(info, 720);
    RT_EQUAL([formats valueForKey:@"height"], (@[ @720, @480, @240 ]));
    RT_EQUAL_INT([formats[0] bitrate], 1200);
    RT_EQUAL([RTAutoFormats(info, 480) valueForKey:@"height"], (@[ @480, @240 ]));
}
