#import "RTBoxBuilder.h"

void Put8(NSMutableData *d, uint8_t v) {
    [d appendBytes:&v length:1];
}

void Put16(NSMutableData *d, uint16_t v) {
    Put8(d, v >> 8);
    Put8(d, v & 0xff);
}

void Put32(NSMutableData *d, uint32_t v) {
    Put16(d, v >> 16);
    Put16(d, v & 0xffff);
}

void Put64(NSMutableData *d, uint64_t v) {
    Put32(d, (uint32_t)(v >> 32));
    Put32(d, (uint32_t)v);
}

NSData *Box(const char *type, NSArray *parts) {
    NSMutableData *content = [NSMutableData data];
    for (NSData *part in parts) [content appendData:part];
    NSMutableData *box = [NSMutableData data];
    Put32(box, (uint32_t)(content.length + 8));
    [box appendBytes:type length:4];
    [box appendData:content];
    return box;
}

NSData *Bytes(void (^fill)(NSMutableData *d)) {
    NSMutableData *d = [NSMutableData data];
    fill(d);
    return d;
}

NSData *Zeros(NSUInteger count) {
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

NSData *Hdlr(const char *type) {
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

NSData *Init(NSData *handler, uint32_t timescale, NSData *sampleEntry, NSArray *extraTrak) {
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

NSData *VideoEntry(void) {
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

NSData *AudioEntry(void) {
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

NSData *Elst(int32_t mediaTime) {
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

NSData *Sidx(uint8_t version, uint32_t firstOffset) {
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

NSData *Fragment(uint64_t decodeTime, BOOL perSampleDuration) {
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

NSData *FragmentWithSamples(uint64_t decodeTime, NSArray *samples, uint32_t duration, int32_t compositionOffset) {
    __block NSUInteger dataOffsetPosition = 0;
    NSData *trun = Box("trun", @[ Bytes(^(NSMutableData *d) {
        Put32(d, 0x01000000 | 0x001 | 0x004 | 0x200 | 0x800);
        Put32(d, (uint32_t)samples.count);
        dataOffsetPosition = d.length;
        Put32(d, 0);
        Put32(d, 0x02000000);
        for (NSData *sample in samples) {
            Put32(d, (uint32_t)sample.length);
            Put32(d, (uint32_t)compositionOffset);
        }
    }) ]);
    NSData *tfhd = Box("tfhd", @[ Bytes(^(NSMutableData *d) {
        Put32(d, 0x020000 | 0x08 | 0x20);
        Put32(d, 1);
        Put32(d, duration);
        Put32(d, 0x00010000);
    }) ]);
    NSData *tfdt = Box("tfdt", @[ Bytes(^(NSMutableData *d) {
        Put32(d, 0x01000000);
        Put64(d, decodeTime);
    }) ]);
    NSData *moof = Box("moof", @[ Box("mfhd", @[ Zeros(8) ]), Box("traf", @[ tfhd, tfdt, trun ]) ]);
    NSMutableData *fragment = [moof mutableCopy];
    uint32_t offset = (uint32_t)(moof.length + 8);
    NSUInteger position = 8 + 16 + 8 + tfhd.length + tfdt.length + 8 + dataOffsetPosition;
    uint8_t be[4] = { offset >> 24, (offset >> 16) & 0xff, (offset >> 8) & 0xff, offset & 0xff };
    [fragment replaceBytesInRange:NSMakeRange(position, 4) withBytes:be];
    NSMutableData *mdat = [NSMutableData data];
    for (NSData *sample in samples) [mdat appendData:sample];
    [fragment appendData:Box("mdat", @[ mdat ])];
    return fragment;
}
