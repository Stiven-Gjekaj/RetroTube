#import "RTTest.h"
#import "RTRemux.h"
#import "RTTS.h"
#import "RTBoxBuilder.h"

static NSData *Slice(uint8_t type, uint8_t fill) {
    NSMutableData *d = [NSMutableData data];
    Put32(d, 3);
    Put8(d, type);
    Put8(d, fill);
    Put8(d, fill);
    return d;
}

static NSData *AACFrame(uint8_t fill) {
    NSMutableData *d = [NSMutableData dataWithLength:10];
    memset(d.mutableBytes, fill, 10);
    return d;
}

// Returns the PTS of each PES of the PID, in order.
static NSArray *PESTimes(NSData *stream, uint16_t pid) {
    NSMutableArray *times = [NSMutableArray array];
    const uint8_t *b = stream.bytes;
    for (NSUInteger i = 0; i + RTTSPacketSize <= stream.length; i += RTTSPacketSize) {
        const uint8_t *p = b + i;
        if ((((p[1] & 0x1f) << 8) | p[2]) != pid || !(p[1] & 0x40)) continue;
        const uint8_t *pes = p + ((p[3] & 0x20) ? 5 + p[4] : 4);
        int64_t pts = ((int64_t)((pes[9] >> 1) & 7) << 30) | ((int64_t)pes[10] << 22) | ((int64_t)(pes[11] >> 1) << 15) |
                      ((int64_t)pes[12] << 7) | (pes[13] >> 1);
        [times addObject:@(pts)];
    }
    return times;
}

static RTMP4Track *VideoTrack(void) {
    return RTMP4ReadInit(Init(Hdlr("vide"), 90000, VideoEntry(), @[ Elst(3000) ]), NULL);
}

static RTMP4Track *AudioTrack(void) {
    return RTMP4ReadInit(Init(Hdlr("soun"), 1000, AudioEntry(), @[]), NULL);
}

RT_TEST(test_remux_writes_whole_packets) {
    NSData *video = FragmentWithSamples(0, @[ Slice(0x65, 1), Slice(0x41, 2) ], 3000, 3000);
    NSData *audio = FragmentWithSamples(0, @[ AACFrame(1), AACFrame(2) ], 20, 0);
    NSError *error = nil;
    NSData *ts = RTRemuxSegment(VideoTrack(), video, AudioTrack(), audio, 0, 1, &error);
    RT_EXPECT(error == nil);
    RT_EXPECT(ts.length > 0);
    RT_EQUAL_INT(ts.length % RTTSPacketSize, 0);
    const uint8_t *b = ts.bytes;
    RT_EQUAL_INT((b[1] << 8 | b[2]) & 0x1fff, 0);  // the PAT first
    RT_EQUAL_INT((b[RTTSPacketSize + 1] << 8 | b[RTTSPacketSize + 2]) & 0x1fff, RTTSPidPMT);
}

RT_TEST(test_remux_applies_edit_and_offset_to_video) {
    // Two frames of 3000 units at 90 kHz with a composition offset of 3000.
    // The edit list removes the first 3000 units, so the first frame shows at 0.
    NSData *video = FragmentWithSamples(0, @[ Slice(0x65, 1), Slice(0x41, 2) ], 3000, 3000);
    NSData *ts = RTRemuxSegment(VideoTrack(), video, nil, nil, 0, 1, NULL);
    RT_EQUAL(PESTimes(ts, RTTSPidVideo), (@[ @(RTRemuxTimeOffset), @(RTRemuxTimeOffset + 3000) ]));
}

RT_TEST(test_remux_keeps_audio_in_time_range) {
    // Audio frames at 0, 400, 800, ... ms. The range [1.0 s, 2.0 s) keeps
    // the frames at 1200, 1600 ms.
    NSMutableArray *frames = [NSMutableArray array];
    for (int i = 0; i < 8; i++) [frames addObject:AACFrame((uint8_t)i)];
    NSData *audio = FragmentWithSamples(0, frames, 400, 0);
    NSData *video = FragmentWithSamples(90000, @[ Slice(0x65, 1) ], 90000, 3000);
    NSData *ts = RTRemuxSegment(VideoTrack(), video, AudioTrack(), audio, 1.0, 2.0, NULL);
    RT_EQUAL(PESTimes(ts, RTTSPidAudio), (@[ @(RTRemuxTimeOffset + 108000) ]));
}

RT_TEST(test_remux_groups_audio_frames_in_pes) {
    NSMutableArray *frames = [NSMutableArray array];
    for (int i = 0; i < 20; i++) [frames addObject:AACFrame((uint8_t)i)];
    NSData *audio = FragmentWithSamples(0, frames, 10, 0);
    NSData *video = FragmentWithSamples(0, @[ Slice(0x65, 1) ], 90000, 3000);
    NSData *ts = RTRemuxSegment(VideoTrack(), video, AudioTrack(), audio, 0, 100, NULL);
    // 20 frames of 10 ms: groups of 8, 8, and 4 frames.
    RT_EQUAL(PESTimes(ts, RTTSPidAudio), (@[ @(RTRemuxTimeOffset), @(RTRemuxTimeOffset + 7200),
                                             @(RTRemuxTimeOffset + 14400) ]));
}

RT_TEST(test_remux_puts_packets_in_time_order) {
    NSMutableArray *frames = [NSMutableArray array];
    for (int i = 0; i < 16; i++) [frames addObject:AACFrame((uint8_t)i)];
    NSData *audio = FragmentWithSamples(0, frames, 100, 0);  // a PES each 0.8 s
    NSMutableArray *slices = [NSMutableArray array];
    for (int i = 0; i < 4; i++) [slices addObject:Slice(i ? 0x41 : 0x65, (uint8_t)i)];
    NSData *video = FragmentWithSamples(3000, slices, 45000, 0);  // a frame each 0.5 s
    NSData *ts = RTRemuxSegment(VideoTrack(), video, AudioTrack(), audio, 0, 10, NULL);
    // Read the start time of each PES in stream order. It must not go down by
    // more than one frame.
    const uint8_t *b = ts.bytes;
    int64_t last = 0;
    for (NSUInteger i = 0; i + RTTSPacketSize <= ts.length; i += RTTSPacketSize) {
        const uint8_t *p = b + i;
        uint16_t pid = ((p[1] & 0x1f) << 8) | p[2];
        if ((pid != RTTSPidVideo && pid != RTTSPidAudio) || !(p[1] & 0x40)) continue;
        NSData *packet = [NSData dataWithBytes:p length:RTTSPacketSize];
        int64_t time = [PESTimes(packet, pid)[0] longLongValue];
        RT_EXPECT(time + 45000 >= last);
        last = time;
    }
}

RT_TEST(test_remux_reports_bad_video) {
    NSMutableData *bad = [NSMutableData data];
    Put32(bad, 99);
    Put8(bad, 0x65);
    NSData *video = FragmentWithSamples(0, @[ bad ], 3000, 0);
    NSError *error = nil;
    RT_EXPECT(RTRemuxSegment(VideoTrack(), video, nil, nil, 0, 1, &error) == nil);
    RT_EXPECT(error != nil);
}
