#import "RTTest.h"
#import "RTMP4.h"
#import "RTBoxBuilder.h"

RT_TEST(test_mp4_reads_video_init) {
    NSError *error = nil;
    RTMP4Track *track = RTMP4ReadInit(Init(Hdlr("vide"), 15360, VideoEntry(), @[ Elst(1024) ]), &error);
    RT_EXPECT(error == nil);
    RT_EXPECT(track.isVideo);
    RT_EQUAL_INT(track.timescale, 15360);
    RT_EQUAL_INT(track.editMediaTime, 1024);
    RT_EQUAL_INT(track.nalLengthSize, 4);
    RT_EQUAL_INT(track.defaultSampleDuration, 512);
    RT_EQUAL_INT(track.sps.count, 1);
    RT_EQUAL_INT([track.sps[0] length], 3);
    RT_EQUAL_INT(((const uint8_t *)[track.pps[0] bytes])[1], 0xee);
}

RT_TEST(test_mp4_reads_audio_init) {
    RTMP4Track *track = RTMP4ReadInit(Init(Hdlr("soun"), 44100, AudioEntry(), @[]), NULL);
    RT_EXPECT(!track.isVideo);
    RT_EQUAL_INT(track.timescale, 44100);
    RT_EQUAL_INT(track.audioObjectType, 2);
    RT_EQUAL_INT(track.sampleRateIndex, 4);
    RT_EQUAL_INT(track.channelConfig, 2);
    RT_EQUAL_INT(track.editMediaTime, 0);
}

RT_TEST(test_mp4_refuses_other_codec) {
    NSError *error = nil;
    NSData *vp9 = Box("vp09", @[ Zeros(90) ]);
    RT_EXPECT(RTMP4ReadInit(Init(Hdlr("vide"), 1000, vp9, @[]), &error) == nil);
    RT_EXPECT(error != nil);
}

RT_TEST(test_mp4_refuses_cut_init) {
    NSData *full = Init(Hdlr("vide"), 15360, VideoEntry(), @[]);
    for (NSUInteger length = 0; length < full.length; length += 7) {
        RT_EXPECT(RTMP4ReadInit([full subdataWithRange:NSMakeRange(0, length)], NULL) == nil);
    }
}

RT_TEST(test_mp4_reads_index) {
    for (uint8_t version = 0; version <= 1; version++) {
        NSData *sidx = Sidx(version, 10);
        RTMP4Index *index = RTMP4ReadIndex(sidx, 739, NULL);
        RT_EQUAL_INT(index.timescale, 1000);
        RT_EQUAL_INT(index.count, 2);
        RTMP4IndexEntry first = [index entryAtIndex:0], second = [index entryAtIndex:1];
        RT_EQUAL_INT(first.offset, 739 + sidx.length + 10);
        RT_EQUAL_INT(first.size, 3000);
        RT_EQUAL_INT(first.startTime, 500);
        RT_EQUAL_INT(first.duration, 5000);
        RT_EQUAL_INT(second.offset, first.offset + 3000);
        RT_EQUAL_INT(second.startTime, 5500);
        RT_EQUAL_INT(second.size, 2500);
    }
}

RT_TEST(test_mp4_refuses_cut_index) {
    NSData *sidx = Sidx(0, 0);
    RT_EXPECT(RTMP4ReadIndex([sidx subdataWithRange:NSMakeRange(0, sidx.length - 4)], 0, NULL) == nil);
}

RT_TEST(test_mp4_reads_samples) {
    RTMP4Track *track = [RTMP4Track new];
    NSData *fragment = Fragment(9000, NO);
    NSError *error = nil;
    NSData *samples = RTMP4ReadSamples(fragment, track, &error);
    RT_EXPECT(error == nil);
    RT_EQUAL_INT(samples.length / sizeof(RTMP4Sample), 3);
    const RTMP4Sample *s = samples.bytes;
    const uint8_t *bytes = fragment.bytes;
    RT_EQUAL_INT(s[0].decodeTime, 9000);
    RT_EQUAL_INT(s[1].decodeTime, 9400);
    RT_EQUAL_INT(s[2].decodeTime, 9800);
    RT_EQUAL_INT(s[0].duration, 400);
    RT_EQUAL_INT(s[2].size, 3);
    RT_EQUAL_INT(s[0].compositionOffset, 200);
    RT_EQUAL_INT(s[1].compositionOffset, -50);
    RT_EXPECT(s[0].isSync);
    RT_EXPECT(!s[1].isSync);
    RT_EQUAL_INT(bytes[s[0].dataOffset], 0xA1);
    RT_EQUAL_INT(bytes[s[1].dataOffset + 1], 0xB2);
    RT_EQUAL_INT(bytes[s[2].dataOffset + 2], 0xC3);
}

RT_TEST(test_mp4_reads_per_sample_durations) {
    NSData *samples = RTMP4ReadSamples(Fragment(0, YES), [RTMP4Track new], NULL);
    const RTMP4Sample *s = samples.bytes;
    RT_EQUAL_INT(s[1].duration, 101);
    RT_EQUAL_INT(s[2].decodeTime, 201);
}

RT_TEST(test_mp4_reads_two_fragments) {
    NSMutableData *two = [Fragment(0, NO) mutableCopy];
    [two appendData:Fragment(1200, NO)];
    NSData *samples = RTMP4ReadSamples(two, [RTMP4Track new], NULL);
    RT_EQUAL_INT(samples.length / sizeof(RTMP4Sample), 6);
    const RTMP4Sample *s = samples.bytes;
    RT_EQUAL_INT(s[3].decodeTime, 1200);
    RT_EQUAL_INT(((const uint8_t *)two.bytes)[s[5].dataOffset], 0xC1);
}

RT_TEST(test_mp4_refuses_samples_past_the_end) {
    NSData *fragment = Fragment(0, NO);
    RT_EXPECT(RTMP4ReadSamples([fragment subdataWithRange:NSMakeRange(0, fragment.length - 2)], [RTMP4Track new], NULL) == nil);
}
