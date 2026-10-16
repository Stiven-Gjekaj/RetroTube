// Builds MP4 boxes for the tests, in big-endian byte order.

#import <Foundation/Foundation.h>

void Put8(NSMutableData *d, uint8_t v);
void Put16(NSMutableData *d, uint16_t v);
void Put32(NSMutableData *d, uint32_t v);
void Put64(NSMutableData *d, uint64_t v);
NSData *Box(const char *type, NSArray *parts);
NSData *Bytes(void (^fill)(NSMutableData *d));
NSData *Zeros(NSUInteger count);
NSData *Hdlr(const char *type);
NSData *Init(NSData *handler, uint32_t timescale, NSData *sampleEntry, NSArray *extraTrak);
NSData *VideoEntry(void);
NSData *AudioEntry(void);
NSData *Elst(int32_t mediaTime);
NSData *Sidx(uint8_t version, uint32_t firstOffset);

// A moof with one traf and one trun, and an mdat with the sample bytes.
// The samples are 1, 2, and 3 bytes long, with the bytes 0xA1, 0xB1 0xB2,
// 0xC1 0xC2 0xC3. The default sample duration is 400.
NSData *Fragment(uint64_t decodeTime, BOOL perSampleDuration);

// A moof and an mdat with the given samples. Each sample is an NSData.
// Each sample has the duration and the composition offset that are given.
// Only the first sample is a sync sample.
NSData *FragmentWithSamples(uint64_t decodeTime, NSArray *samples, uint32_t duration, int32_t compositionOffset);
