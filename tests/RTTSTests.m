#import "RTTest.h"
#import "RTTS.h"

// Returns the payload of each packet of the PID, joined. Fails the test if
// a packet does not start with the sync byte.
static NSData *PayloadOfPid(NSData *stream, uint16_t pid, int *packets) {
    NSMutableData *payload = [NSMutableData data];
    const uint8_t *b = stream.bytes;
    *packets = 0;
    for (NSUInteger i = 0; i + RTTSPacketSize <= stream.length; i += RTTSPacketSize) {
        const uint8_t *p = b + i;
        RT_EQUAL_INT(p[0], 0x47);
        if ((((p[1] & 0x1f) << 8) | p[2]) != pid) continue;
        (*packets)++;
        NSUInteger start = 4;
        if (p[3] & 0x20) start = 5 + p[4];
        if (p[3] & 0x10) [payload appendBytes:p + start length:RTTSPacketSize - start];
    }
    return payload;
}

static int64_t ReadTimestamp(const uint8_t *p) {
    return ((int64_t)((p[0] >> 1) & 7) << 30) | ((int64_t)p[1] << 22) | ((int64_t)(p[2] >> 1) << 15) |
           ((int64_t)p[3] << 7) | (p[4] >> 1);
}

RT_TEST(test_ts_crc_of_standard_pat) {
    // The PAT of one program with the PMT on PID 0x1000. ffmpeg writes the
    // same section, with the CRC 0x2AB104B2.
    const uint8_t pat[] = { 0x00, 0xb0, 0x0d, 0x00, 0x01, 0xc1, 0x00, 0x00, 0x00, 0x01, 0xf0, 0x00 };
    RT_EQUAL_INT(RTTSCRC32(pat, sizeof(pat)), 0x2ab104b2);
}

RT_TEST(test_ts_tables_have_valid_crc) {
    RTTSWriter *writer = [RTTSWriter new];
    [writer writeTables];
    RT_EQUAL_INT(writer.output.length, 2 * RTTSPacketSize);
    for (int i = 0; i < 2; i++) {
        const uint8_t *section = (const uint8_t *)writer.output.bytes + i * RTTSPacketSize + 5;
        size_t length = 3 + (((section[1] & 0x0f) << 8) | section[2]);
        // The CRC of a section with its own CRC at the end is 0.
        RT_EQUAL_INT(RTTSCRC32(section, length), 0);
    }
}

RT_TEST(test_ts_pmt_lists_streams) {
    RTTSWriter *writer = [RTTSWriter new];
    [writer writeTables];
    const uint8_t *pmt = (const uint8_t *)writer.output.bytes + RTTSPacketSize + 5;
    RT_EQUAL_INT(pmt[0], 0x02);
    RT_EQUAL_INT(pmt[12], 0x1b);
    RT_EQUAL_INT(((pmt[13] & 0x1f) << 8) | pmt[14], RTTSPidVideo);
    RT_EQUAL_INT(pmt[17], 0x0f);
    RT_EQUAL_INT(((pmt[18] & 0x1f) << 8) | pmt[19], RTTSPidAudio);

    RTTSWriter *videoOnly = [RTTSWriter new];
    videoOnly.hasAudio = NO;
    [videoOnly writeTables];
    const uint8_t *short_ = (const uint8_t *)videoOnly.output.bytes + RTTSPacketSize + 5;
    RT_EQUAL_INT(((short_[1] & 0x0f) << 8) | short_[2], 18);
}

RT_TEST(test_ts_annexb_adds_delimiter_and_parameter_sets) {
    const uint8_t sample[] = { 0, 0, 0, 2, 0x65, 0x88,   // IDR slice
                               0, 0, 0, 1, 0x09 };       // a delimiter, dropped
    NSArray *sps = @[ [NSData dataWithBytes:"\x67\x4d" length:2] ];
    NSArray *pps = @[ [NSData dataWithBytes:"\x68" length:1] ];
    NSData *out = RTTSAnnexB(sample, sizeof(sample), 4, sps, pps, YES);
    const uint8_t expected[] = { 0, 0, 0, 1, 0x09, 0xf0, 0, 0, 0, 1, 0x67, 0x4d, 0, 0, 0, 1, 0x68,
                                 0, 0, 0, 1, 0x65, 0x88 };
    RT_EQUAL(out, [NSData dataWithBytes:expected length:sizeof(expected)]);
}

RT_TEST(test_ts_annexb_of_other_sample_has_no_parameter_sets) {
    const uint8_t sample[] = { 0, 2, 0x41, 0x9a };  // a 2-byte length
    NSData *out = RTTSAnnexB(sample, sizeof(sample), 2, @[ [NSData dataWithBytes:"\x67" length:1] ], @[], NO);
    const uint8_t expected[] = { 0, 0, 0, 1, 0x09, 0xf0, 0, 0, 0, 1, 0x41, 0x9a };
    RT_EQUAL(out, [NSData dataWithBytes:expected length:sizeof(expected)]);
}

RT_TEST(test_ts_annexb_refuses_wrong_length) {
    const uint8_t sample[] = { 0, 0, 0, 9, 0x41 };
    RT_EXPECT(RTTSAnnexB(sample, sizeof(sample), 4, @[], @[], NO) == nil);
    const uint8_t zero[] = { 0, 0, 0, 0 };
    RT_EXPECT(RTTSAnnexB(zero, sizeof(zero), 4, @[], @[], NO) == nil);
}

RT_TEST(test_ts_adts_header) {
    uint8_t header[7];
    RTTSWriteADTSHeader(header, 2, 4, 2, 371);  // AAC LC, 44100 Hz, stereo
    // ffmpeg writes this header for a frame of 371 bytes: ff f1 50 80 2f 5f fc
    const uint8_t expected[] = { 0xff, 0xf1, 0x50, 0x80, 0x2f, 0x5f, 0xfc };
    RT_EQUAL([NSData dataWithBytes:header length:7], [NSData dataWithBytes:expected length:7]);
}

RT_TEST(test_ts_video_pes_round_trips) {
    for (NSUInteger size = 1; size < 1200; size += 37) {
        NSMutableData *frame = [NSMutableData dataWithLength:size];
        for (NSUInteger i = 0; i < size; i++) ((uint8_t *)frame.mutableBytes)[i] = (uint8_t)(i * 7 + size);
        RTTSWriter *writer = [RTTSWriter new];
        [writer writeVideo:frame pts:93003 dts:90000 isSync:YES];
        RT_EQUAL_INT(writer.output.length % RTTSPacketSize, 0);
        int packets = 0;
        NSData *payload = PayloadOfPid(writer.output, RTTSPidVideo, &packets);
        const uint8_t *p = payload.bytes;
        RT_EQUAL_INT(p[0] << 16 | p[1] << 8 | p[2], 1);
        RT_EQUAL_INT(p[3], 0xe0);
        RT_EQUAL_INT(p[7], 0xc0);
        RT_EQUAL_INT(ReadTimestamp(p + 9), 93003);
        RT_EQUAL_INT(ReadTimestamp(p + 14), 90000);
        RT_EQUAL([payload subdataWithRange:NSMakeRange(19, payload.length - 19)], frame);
        // The first packet holds the PCR and the random access flag.
        const uint8_t *first = writer.output.bytes;
        RT_EXPECT(first[1] & 0x40);
        RT_EXPECT(first[3] & 0x20);
        RT_EQUAL_INT(first[5] & 0x50, 0x50);
    }
}

RT_TEST(test_ts_audio_pes_has_length_and_pts) {
    NSData *frames = [NSMutableData dataWithLength:500];
    RTTSWriter *writer = [RTTSWriter new];
    [writer writeAudio:frames pts:123456];
    int packets = 0;
    NSData *payload = PayloadOfPid(writer.output, RTTSPidAudio, &packets);
    const uint8_t *p = payload.bytes;
    RT_EQUAL_INT(p[3], 0xc0);
    RT_EQUAL_INT((p[4] << 8) | p[5], 500 + 8);
    RT_EQUAL_INT(p[7], 0x80);
    RT_EQUAL_INT(ReadTimestamp(p + 9), 123456);
    RT_EQUAL_INT(payload.length, 14 + 500);
    RT_EQUAL_INT(packets, 3);
}

RT_TEST(test_ts_continuity_counts_up_for_each_pid) {
    RTTSWriter *writer = [RTTSWriter new];
    for (int i = 0; i < 20; i++) [writer writeAudio:[NSMutableData dataWithLength:100] pts:i];
    const uint8_t *b = writer.output.bytes;
    for (int i = 0; i < 20; i++) RT_EQUAL_INT(b[i * RTTSPacketSize + 3] & 0x0f, i % 16);
}
