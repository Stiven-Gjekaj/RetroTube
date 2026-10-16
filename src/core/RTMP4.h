// Reads fragmented MP4 (DASH) streams: the init segment, the segment index
// (sidx), and the samples of the fragments (moof and mdat).
// The reader keeps only what the MPEG-TS writer needs.

#import <Foundation/Foundation.h>

extern NSString *const RTMP4ErrorDomain;

// The track of an init segment.
@interface RTMP4Track : NSObject
@property (nonatomic) BOOL isVideo;
@property (nonatomic) uint32_t timescale;
@property (nonatomic) int64_t editMediaTime;  // The first media time to show, from elst. 0 if none.
@property (nonatomic) uint32_t defaultSampleDuration;
@property (nonatomic) uint32_t defaultSampleSize;
@property (nonatomic) uint32_t defaultSampleFlags;
// H.264 only.
@property (nonatomic) int nalLengthSize;
@property (nonatomic, copy) NSArray *sps;  // NSData objects, with no start code
@property (nonatomic, copy) NSArray *pps;
// AAC only. These are the fields of the AudioSpecificConfig.
@property (nonatomic) int audioObjectType;
@property (nonatomic) int sampleRateIndex;
@property (nonatomic) int channelConfig;
@end

// Reads the first track of an init segment (ftyp and moov).
RTMP4Track *RTMP4ReadInit(NSData *data, NSError **error);

// One entry of a segment index. The offset is from the start of the file.
typedef struct {
    uint64_t offset;
    uint32_t size;
    uint64_t startTime;  // In the timescale of the index
    uint32_t duration;
} RTMP4IndexEntry;

@interface RTMP4Index : NSObject
@property (nonatomic) uint32_t timescale;
@property (nonatomic, readonly) NSUInteger count;
- (RTMP4IndexEntry)entryAtIndex:(NSUInteger)index;
@end

// Reads a sidx box. data starts with the sidx box. fileOffset is the offset
// of data in the file.
RTMP4Index *RTMP4ReadIndex(NSData *data, uint64_t fileOffset, NSError **error);

// One sample of a fragment.
typedef struct {
    uint64_t decodeTime;   // In the timescale of the track
    int32_t compositionOffset;
    uint32_t duration;
    uint32_t size;
    uint32_t dataOffset;   // The offset of the sample in the data that RTMP4ReadSamples read
    BOOL isSync;
} RTMP4Sample;

// Reads the samples of all the moof boxes in data. data holds one or more
// complete moof and mdat pairs. Returns an NSData that holds RTMP4Sample
// structs, or nil.
NSData *RTMP4ReadSamples(NSData *data, RTMP4Track *track, NSError **error);
