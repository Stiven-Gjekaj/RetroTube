#import "RTMP4.h"

NSString *const RTMP4ErrorDomain = @"RTMP4";

static NSError *RTMP4Error(NSString *text) {
    return [NSError errorWithDomain:RTMP4ErrorDomain code:1 userInfo:@{ NSLocalizedDescriptionKey: text }];
}

// A read position in a byte buffer. A read past the end sets failed and
// gives 0, so that a short box does not read memory outside the buffer.
typedef struct {
    const uint8_t *bytes;
    size_t length;
    size_t position;
    BOOL failed;
} RTReader;

static BOOL RTCan(RTReader *r, size_t count) {
    if (r->failed || r->position + count > r->length || r->position + count < r->position) {
        r->failed = YES;
        return NO;
    }
    return YES;
}

static uint8_t RTRead8(RTReader *r) {
    if (!RTCan(r, 1)) return 0;
    return r->bytes[r->position++];
}

static uint16_t RTRead16(RTReader *r) {
    if (!RTCan(r, 2)) return 0;
    const uint8_t *p = r->bytes + r->position;
    r->position += 2;
    return (uint16_t)((p[0] << 8) | p[1]);
}

static uint32_t RTRead24(RTReader *r) {
    if (!RTCan(r, 3)) return 0;
    const uint8_t *p = r->bytes + r->position;
    r->position += 3;
    return ((uint32_t)p[0] << 16) | ((uint32_t)p[1] << 8) | p[2];
}

static uint32_t RTRead32(RTReader *r) {
    if (!RTCan(r, 4)) return 0;
    const uint8_t *p = r->bytes + r->position;
    r->position += 4;
    return ((uint32_t)p[0] << 24) | ((uint32_t)p[1] << 16) | ((uint32_t)p[2] << 8) | p[3];
}

static uint64_t RTRead64(RTReader *r) {
    uint64_t high = RTRead32(r);
    return (high << 32) | RTRead32(r);
}

static void RTSkip(RTReader *r, size_t count) {
    if (RTCan(r, count)) r->position += count;
}

// A box in a buffer: its type and the range of its content.
typedef struct {
    uint32_t type;
    size_t start;  // The first byte of the content
    size_t end;    // The byte after the box
} RTBox;

#define RT_FOURCC(a, b, c, d) (((uint32_t)(a) << 24) | ((uint32_t)(b) << 16) | ((uint32_t)(c) << 8) | (uint32_t)(d))

// Reads the box header at the position. Moves the position to the content.
static BOOL RTReadBox(RTReader *r, size_t limit, RTBox *box) {
    size_t begin = r->position;
    if (begin + 8 > limit) return NO;
    uint64_t size = RTRead32(r);
    box->type = RTRead32(r);
    if (size == 1) size = RTRead64(r);
    else if (size == 0) size = limit - begin;
    if (r->failed || size < r->position - begin || begin + size > limit) {
        r->failed = YES;
        return NO;
    }
    box->start = r->position;
    box->end = begin + (size_t)size;
    return YES;
}

// Finds the first child box of the type in [start, end).
static BOOL RTFindBox(RTReader *r, size_t start, size_t end, uint32_t type, RTBox *found) {
    r->position = start;
    RTBox box;
    while (RTReadBox(r, end, &box)) {
        if (box.type == type) {
            *found = box;
            r->position = box.start;
            return YES;
        }
        r->position = box.end;
    }
    return NO;
}

// Follows a path of box types from [start, end).
static BOOL RTFindPath(RTReader *r, size_t start, size_t end, const uint32_t *types, int count, RTBox *found) {
    RTBox box = { 0, start, end };
    for (int i = 0; i < count; i++) {
        if (!RTFindBox(r, box.start, box.end, types[i], &box)) return NO;
    }
    *found = box;
    return YES;
}

@implementation RTMP4Track
@end

static void RTReadAVCC(RTReader *r, RTBox box, RTMP4Track *track) {
    r->position = box.start;
    RTSkip(r, 4);  // version, profile, compatibility, level
    track.nalLengthSize = (RTRead8(r) & 3) + 1;
    NSMutableArray *sps = [NSMutableArray array], *pps = [NSMutableArray array];
    int spsCount = RTRead8(r) & 0x1f;
    for (int i = 0; i < spsCount && !r->failed; i++) {
        uint16_t length = RTRead16(r);
        if (!RTCan(r, length)) break;
        [sps addObject:[NSData dataWithBytes:r->bytes + r->position length:length]];
        r->position += length;
    }
    int ppsCount = RTRead8(r);
    for (int i = 0; i < ppsCount && !r->failed; i++) {
        uint16_t length = RTRead16(r);
        if (!RTCan(r, length)) break;
        [pps addObject:[NSData dataWithBytes:r->bytes + r->position length:length]];
        r->position += length;
    }
    track.sps = sps;
    track.pps = pps;
}

// Reads the length of an MPEG-4 descriptor.
static uint32_t RTReadDescriptorLength(RTReader *r) {
    uint32_t length = 0;
    for (int i = 0; i < 4; i++) {
        uint8_t byte = RTRead8(r);
        length = (length << 7) | (byte & 0x7f);
        if (!(byte & 0x80)) break;
    }
    return length;
}

static void RTReadESDS(RTReader *r, RTBox box, RTMP4Track *track) {
    r->position = box.start + 4;  // version and flags
    // ES_Descriptor (3), DecoderConfigDescriptor (4), DecoderSpecificInfo (5).
    while (r->position < box.end && !r->failed) {
        uint8_t tag = RTRead8(r);
        uint32_t length = RTReadDescriptorLength(r);
        if (tag == 3) {
            RTSkip(r, 2);
            uint8_t flags = RTRead8(r);
            if (flags & 0x80) RTSkip(r, 2);
            if (flags & 0x40) RTSkip(r, RTRead8(r));
            if (flags & 0x20) RTSkip(r, 2);
        } else if (tag == 4) {
            RTSkip(r, 13);
        } else if (tag == 5) {
            uint8_t a = RTRead8(r), b = RTRead8(r);
            track.audioObjectType = a >> 3;
            track.sampleRateIndex = ((a & 7) << 1) | (b >> 7);
            track.channelConfig = (b >> 3) & 0xf;
            return;
        } else {
            RTSkip(r, length);
        }
    }
}

RTMP4Track *RTMP4ReadInit(NSData *data, NSError **error) {
    RTReader reader = { data.bytes, data.length, 0, NO };
    RTReader *r = &reader;
    RTBox moov, trak, box;
    if (!RTFindBox(r, 0, data.length, RT_FOURCC('m', 'o', 'o', 'v'), &moov) ||
        !RTFindBox(r, moov.start, moov.end, RT_FOURCC('t', 'r', 'a', 'k'), &trak)) {
        if (error) *error = RTMP4Error(@"The init segment has no track.");
        return nil;
    }
    RTMP4Track *track = [RTMP4Track new];

    const uint32_t hdlr[] = { RT_FOURCC('m', 'd', 'i', 'a'), RT_FOURCC('h', 'd', 'l', 'r') };
    if (RTFindPath(r, trak.start, trak.end, hdlr, 2, &box)) {
        RTSkip(r, 8);
        track.isVideo = RTRead32(r) == RT_FOURCC('v', 'i', 'd', 'e');
    }

    const uint32_t mdhd[] = { RT_FOURCC('m', 'd', 'i', 'a'), RT_FOURCC('m', 'd', 'h', 'd') };
    if (RTFindPath(r, trak.start, trak.end, mdhd, 2, &box)) {
        uint8_t version = RTRead8(r);
        RTSkip(r, 3 + (version == 1 ? 16 : 8));
        track.timescale = RTRead32(r);
    }

    const uint32_t elst[] = { RT_FOURCC('e', 'd', 't', 's'), RT_FOURCC('e', 'l', 's', 't') };
    if (RTFindPath(r, trak.start, trak.end, elst, 2, &box)) {
        uint8_t version = RTRead8(r);
        RTSkip(r, 3);
        uint32_t count = RTRead32(r);
        // An empty edit has a media time of -1. Use the first edit with media.
        for (uint32_t i = 0; i < count && !r->failed; i++) {
            int64_t mediaTime;
            if (version == 1) {
                RTSkip(r, 8);
                mediaTime = (int64_t)RTRead64(r);
            } else {
                RTSkip(r, 4);
                mediaTime = (int32_t)RTRead32(r);
            }
            RTSkip(r, 4);
            if (mediaTime >= 0) {
                track.editMediaTime = mediaTime;
                break;
            }
        }
    }

    const uint32_t trex[] = { RT_FOURCC('m', 'v', 'e', 'x'), RT_FOURCC('t', 'r', 'e', 'x') };
    if (RTFindPath(r, moov.start, moov.end, trex, 2, &box)) {
        RTSkip(r, 12);  // version, flags, track ID, sample description index
        track.defaultSampleDuration = RTRead32(r);
        track.defaultSampleSize = RTRead32(r);
        track.defaultSampleFlags = RTRead32(r);
    }

    const uint32_t stsd[] = { RT_FOURCC('m', 'd', 'i', 'a'), RT_FOURCC('m', 'i', 'n', 'f'),
                              RT_FOURCC('s', 't', 'b', 'l'), RT_FOURCC('s', 't', 's', 'd') };
    if (RTFindPath(r, trak.start, trak.end, stsd, 4, &box)) {
        RTBox entry;
        r->position = box.start + 8;  // version, flags, entry count
        if (RTReadBox(r, box.end, &entry)) {
            if (entry.type == RT_FOURCC('a', 'v', 'c', '1') || entry.type == RT_FOURCC('a', 'v', 'c', '3')) {
                RTBox avcC;
                if (RTFindBox(r, entry.start + 78, entry.end, RT_FOURCC('a', 'v', 'c', 'C'), &avcC)) {
                    RTReadAVCC(r, avcC, track);
                }
            } else if (entry.type == RT_FOURCC('m', 'p', '4', 'a')) {
                RTBox esds;
                if (RTFindBox(r, entry.start + 28, entry.end, RT_FOURCC('e', 's', 'd', 's'), &esds)) {
                    RTReadESDS(r, esds, track);
                }
            }
        }
    }

    if (r->failed || !track.timescale) {
        if (error) *error = RTMP4Error(@"The init segment is not complete.");
        return nil;
    }
    if (track.isVideo ? (!track.sps.count || !track.pps.count) : !track.audioObjectType) {
        if (error) *error = RTMP4Error(@"The codec of the track is not H.264 or AAC.");
        return nil;
    }
    return track;
}

@interface RTMP4Index ()
@property (nonatomic, strong) NSMutableData *entries;
@end

@implementation RTMP4Index

- (NSUInteger)count {
    return self.entries.length / sizeof(RTMP4IndexEntry);
}

- (RTMP4IndexEntry)entryAtIndex:(NSUInteger)index {
    return ((const RTMP4IndexEntry *)self.entries.bytes)[index];
}

@end

RTMP4Index *RTMP4ReadIndex(NSData *data, uint64_t fileOffset, NSError **error) {
    RTReader reader = { data.bytes, data.length, 0, NO };
    RTReader *r = &reader;
    RTBox sidx;
    if (!RTFindBox(r, 0, data.length, RT_FOURCC('s', 'i', 'd', 'x'), &sidx)) {
        if (error) *error = RTMP4Error(@"The stream has no segment index.");
        return nil;
    }
    uint8_t version = RTRead8(r);
    RTSkip(r, 3 + 4);  // flags, reference ID
    RTMP4Index *index = [RTMP4Index new];
    index.timescale = RTRead32(r);
    uint64_t time = version == 0 ? RTRead32(r) : RTRead64(r);
    uint64_t firstOffset = version == 0 ? RTRead32(r) : RTRead64(r);
    RTSkip(r, 2);
    uint16_t count = RTRead16(r);
    index.entries = [NSMutableData dataWithCapacity:count * sizeof(RTMP4IndexEntry)];
    // The first offset counts from the byte after the sidx box.
    uint64_t offset = fileOffset + sidx.end + firstOffset;
    for (uint16_t i = 0; i < count && !r->failed; i++) {
        uint32_t reference = RTRead32(r);
        RTMP4IndexEntry entry;
        entry.size = reference & 0x7fffffff;
        entry.duration = RTRead32(r);
        RTSkip(r, 4);  // SAP fields
        entry.offset = offset;
        entry.startTime = time;
        [index.entries appendBytes:&entry length:sizeof(entry)];
        offset += entry.size;
        time += entry.duration;
    }
    if (r->failed || !index.timescale) {
        if (error) *error = RTMP4Error(@"The segment index is not complete.");
        return nil;
    }
    return index;
}

// Reads one traf box into samples. moofStart is the offset of the moof box.
static BOOL RTReadTraf(RTReader *r, RTBox traf, size_t moofStart, RTMP4Track *track, NSMutableData *samples) {
    uint64_t baseOffset = moofStart;
    uint32_t defaultDuration = track.defaultSampleDuration;
    uint32_t defaultSize = track.defaultSampleSize;
    uint32_t defaultFlags = track.defaultSampleFlags;
    uint64_t decodeTime = 0;
    RTBox box;

    if (RTFindBox(r, traf.start, traf.end, RT_FOURCC('t', 'f', 'h', 'd'), &box)) {
        RTSkip(r, 1);
        uint32_t flags = RTRead24(r);
        RTSkip(r, 4);  // track ID
        if (flags & 0x01) baseOffset = RTRead64(r);
        if (flags & 0x02) RTSkip(r, 4);
        if (flags & 0x08) defaultDuration = RTRead32(r);
        if (flags & 0x10) defaultSize = RTRead32(r);
        if (flags & 0x20) defaultFlags = RTRead32(r);
    }
    if (RTFindBox(r, traf.start, traf.end, RT_FOURCC('t', 'f', 'd', 't'), &box)) {
        uint8_t version = RTRead8(r);
        RTSkip(r, 3);
        decodeTime = version == 1 ? RTRead64(r) : RTRead32(r);
    }

    // A traf can hold more than one trun. Read each one.
    r->position = traf.start;
    RTBox trun;
    while (RTReadBox(r, traf.end, &trun)) {
        size_t next = trun.end;
        if (trun.type != RT_FOURCC('t', 'r', 'u', 'n')) {
            r->position = next;
            continue;
        }
        uint8_t version = RTRead8(r);
        uint32_t flags = RTRead24(r);
        uint32_t count = RTRead32(r);
        uint64_t dataOffset = baseOffset;
        if (flags & 0x001) dataOffset = baseOffset + (int32_t)RTRead32(r);
        uint32_t firstFlags = (flags & 0x004) ? RTRead32(r) : defaultFlags;
        for (uint32_t i = 0; i < count && !r->failed; i++) {
            RTMP4Sample sample;
            sample.duration = (flags & 0x100) ? RTRead32(r) : defaultDuration;
            sample.size = (flags & 0x200) ? RTRead32(r) : defaultSize;
            uint32_t sampleFlags = (flags & 0x400) ? RTRead32(r) : (i == 0 ? firstFlags : defaultFlags);
            uint32_t cto = (flags & 0x800) ? RTRead32(r) : 0;
            sample.compositionOffset = version == 0 ? (int32_t)MIN(cto, (uint32_t)INT32_MAX) : (int32_t)cto;
            // sample_is_non_sync_sample is bit 16.
            sample.isSync = !(sampleFlags & 0x00010000);
            sample.decodeTime = decodeTime;
            if (dataOffset + sample.size > r->length) {
                r->failed = YES;
                return NO;
            }
            sample.dataOffset = (uint32_t)dataOffset;
            [samples appendBytes:&sample length:sizeof(sample)];
            decodeTime += sample.duration;
            dataOffset += sample.size;
        }
        if (r->failed) return NO;
        r->position = next;
    }
    return YES;
}

NSData *RTMP4ReadSamples(NSData *data, RTMP4Track *track, NSError **error) {
    RTReader reader = { data.bytes, data.length, 0, NO };
    RTReader *r = &reader;
    NSMutableData *samples = [NSMutableData data];
    RTBox box;
    size_t position = 0;
    while (position < data.length) {
        r->position = position;
        if (!RTReadBox(r, data.length, &box)) break;
        if (box.type == RT_FOURCC('m', 'o', 'o', 'f')) {
            size_t moofStart = position;
            RTBox traf;
            size_t search = box.start;
            while (RTFindBox(r, search, box.end, RT_FOURCC('t', 'r', 'a', 'f'), &traf)) {
                if (!RTReadTraf(r, traf, moofStart, track, samples)) break;
                search = traf.end;
            }
        }
        if (r->failed) break;
        position = box.end;
    }
    if (r->failed) {
        if (error) *error = RTMP4Error(@"A fragment is not complete.");
        return nil;
    }
    return samples;
}
