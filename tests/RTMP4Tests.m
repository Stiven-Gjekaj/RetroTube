#import "RTTest.h"
#import "RTMP4.h"

// Helpers that build MP4 boxes in big-endian order.

static void Put8(NSMutableData *d, uint8_t v) {
    [d appendBytes:&v length:1];
}

static void Put16(NSMutableData *d, uint16_t v) {
    Put8(d, v >> 8);
    Put8(d, v & 0xff);
}

static void Put32(NSMutableData *d, uint32_t v) {
    Put16(d, v >> 16);
    Put16(d, v & 0xffff);
}

static void Put64(NSMutableData *d, uint64_t v) {
    Put32(d, (uint32_t)(v >> 32));
    Put32(d, (uint32_t)v);
}

static NSData *Box(const char *type, NSArray *parts) {
    NSMutableData *content = [NSMutableData data];
    for (NSData *part in parts) [content appendData:part];
    NSMutableData *box = [NSMutableData data];
    Put32(box, (uint32_t)(content.length + 8));
    [box appendBytes:type length:4];
    [box appendData:content];
    return box;
}

static NSData *Bytes(void (^fill)(NSMutableData *d)) {
    NSMutableData *d = [NSMutableData data];
    fill(d);
    return d;
}

static NSData *Zeros(NSUInteger count) {
    return [NSMutableData dataWithLength:count];
}

static NSData *Mdhd(uint32_t timescale) {
    return Box("mdhd", @[ Bytes(^(NSMutableData *d) {
        Put32(d, 0);
        Put32(d, 0);
        Put32(d, 0);
        Put32(d, timescale);
        Put32(d, 0);
        Put32(d, 0);
    }) ]);
}

static NSData *Hdlr(const char *type) {
    return Box("hdlr", @[ Bytes(^(NSMutableData *d) {
        Put32(d, 0);
        Put32(d, 0);
        [d appendBytes:type length:4];
        [d appendData:Zeros(13)];
    }) ]);
}

static NSData *Trex(uint32_t duration) {
    return Box("trex", @[ Bytes(^(NSMutableData *d) {
        Put32(d, 0);
        Put32(d, 1);
        Put32(d, 1);
        Put32(d, duration);
        Put32(d, 0);
        Put32(d, 0x00010000);
    }) ]);
}

static NSData *Init(NSData *handler, uint32_t timescale, NSData *sampleEntry, NSArray *extraTrak) {
    NSData *stsd = Box("stsd", @[ Bytes(^(NSMutableData *d) {
        Put32(d, 0);
        Put32(d, 1);
    }), sampleEntry ]);
    NSData *stbl = Box("stbl", @[ stsd ]);
    NSData *minf = Box("minf", @[ stbl ]);
    NSData *mdia = Box("mdia", @[ Mdhd(timescale), handler, minf ]);
    NSData *trak = Box("trak", [extraTrak arrayByAddingObject:mdia]);
    NSData *moov = Box("moov", @[ Box("mvex", @[ Trex(512) ]), trak ]);
    return Bytes(^(NSMutableData *d) {
        [d appendData:Box("ftyp", @[ Zeros(8) ])];
        [d appendData:moov];
    });
}

static NSData *VideoEntry(void) {
    NSData *avcC = Box("avcC", @[ Bytes(^(NSMutableData *d) {
        Put8(d, 1);
        Put8(d, 0x4d);
        Put8(d, 0x40);
        Put8(d, 0x1f);
        Put8(d, 0xff);  // length size 4
        Put8(d, 0xe1);  // 1 SPS
        Put16(d, 3);
        Put8(d, 0x67);
        Put8(d, 0x4d);
        Put8(d, 0x40);
        Put8(d, 1);     // 1 PPS
        Put16(d, 2);
        Put8(d, 0x68);
        Put8(d, 0xee);
    }) ]);
    return Box("avc1", @[ Zeros(78), avcC ]);
}

static NSData *AudioEntry(void) {
    // ES_Descriptor > DecoderConfigDescriptor > DecoderSpecificInfo (AAC LC, 44100 Hz, 2 channels)
    NSData *esds = Box("esds", @[ Bytes(^(NSMutableData *d) {
        Put32(d, 0);
        Put8(d, 3);
        Put8(d, 0x80);  // a length in two bytes
        Put8(d, 25);
        Put16(d, 1);
        Put8(d, 0);
        Put8(d, 4);
        Put8(d, 17);
        [d appendData:Zeros(13)];
        Put8(d, 5);
        Put8(d, 2);
        Put8(d, 0x12);
        Put8(d, 0x10);
    }) ]);
    return Box("mp4a", @[ Zeros(28), esds ]);
}

static NSData *Elst(int32_t mediaTime) {
    return Box("edts", @[ Box("elst", @[ Bytes(^(NSMutableData *d) {
        Put32(d, 0);
        Put32(d, 2);
        Put32(d, 100);
        Put32(d, (uint32_t)-1);  // an empty edit
        Put32(d, 0x00010000);
        Put32(d, 1000);
        Put32(d, (uint32_t)mediaTime);
        Put32(d, 0x00010000);
    }) ]) ]);
}

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

static NSData *Sidx(uint8_t version, uint32_t firstOffset) {
    return Box("sidx", @[ Bytes(^(NSMutableData *d) {
        Put32(d, (uint32_t)version << 24);
        Put32(d, 1);
        Put32(d, 1000);
        if (version == 0) {
            Put32(d, 500);
            Put32(d, firstOffset);
        } else {
            Put64(d, 500);
            Put64(d, firstOffset);
        }
        Put16(d, 0);
        Put16(d, 2);
        Put32(d, 3000);
        Put32(d, 5000);
        Put32(d, 0x90000000);
        Put32(d, 2500);
        Put32(d, 4000);
        Put32(d, 0x90000000);
    }) ]);
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

// A moof with one traf and one trun, and an mdat with the sample bytes.
// The samples are 1, 2, and 3 bytes long, with the bytes 0xA1, 0xB1 0xB2, 0xC1 0xC2 0xC3.
static NSData *Fragment(uint64_t decodeTime, BOOL perSampleDuration) {
    uint32_t trunFlags = 0x001 | 0x004 | 0x200 | 0x800 | (perSampleDuration ? 0x100 : 0);
    __block NSUInteger dataOffsetPosition = 0;
    NSData *trun = Box("trun", @[ Bytes(^(NSMutableData *d) {
        Put32(d, 0x01000000 | trunFlags);  // version 1: signed offsets
        Put32(d, 3);
        dataOffsetPosition = d.length;
        Put32(d, 0);                       // data offset, set below
        Put32(d, 0x02000000);              // first sample flags: a sync sample
        for (int i = 0; i < 3; i++) {
            if (perSampleDuration) Put32(d, 100 + i);
            Put32(d, (uint32_t)(i + 1));
            Put32(d, i == 1 ? (uint32_t)-50 : 200);
        }
    }) ]);
    NSData *tfhd = Box("tfhd", @[ Bytes(^(NSMutableData *d) {
        Put32(d, 0x020000 | 0x08 | 0x20);  // base is moof, default duration, default flags
        Put32(d, 1);
        Put32(d, 400);
        Put32(d, 0x00010000);              // the default: not a sync sample
    }) ]);
    NSData *tfdt = Box("tfdt", @[ Bytes(^(NSMutableData *d) {
        Put32(d, 0x01000000);
        Put64(d, decodeTime);
    }) ]);
    NSData *moof = Box("moof", @[ Box("mfhd", @[ Zeros(8) ]), Box("traf", @[ tfhd, tfdt, trun ]) ]);
    NSMutableData *fragment = [moof mutableCopy];
    // The data offset counts from the start of the moof to the first sample.
    uint32_t offset = (uint32_t)(moof.length + 8);
    NSUInteger position = 8 + 16 + 8 + tfhd.length + tfdt.length + 8 + dataOffsetPosition;
    uint8_t be[4] = { offset >> 24, (offset >> 16) & 0xff, (offset >> 8) & 0xff, offset & 0xff };
    [fragment replaceBytesInRange:NSMakeRange(position, 4) withBytes:be];
    const uint8_t sampleBytes[] = { 0xA1, 0xB1, 0xB2, 0xC1, 0xC2, 0xC3 };
    [fragment appendData:Box("mdat", @[ [NSData dataWithBytes:sampleBytes length:6] ])];
    return fragment;
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
