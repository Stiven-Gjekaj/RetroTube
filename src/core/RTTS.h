// Writes MPEG transport streams for HLS: one H.264 video stream and one AAC
// audio stream. The times are in units of 90 kHz.

#import <Foundation/Foundation.h>

enum {
    RTTSPacketSize = 188,
    RTTSPidPMT = 0x1000,
    RTTSPidVideo = 0x100,
    RTTSPidAudio = 0x101,
};

// The CRC-32 of MPEG-2 sections (polynomial 0x04C11DB7, no reflection).
uint32_t RTTSCRC32(const uint8_t *bytes, size_t length);

// Converts one H.264 sample with length-prefixed NAL units to Annex B form.
// It puts an access unit delimiter first. For a sync sample it puts the SPS
// and the PPS before the first slice. It drops the access unit delimiters,
// the SPS units, and the PPS units of the sample. Returns nil if a length is
// wrong.
NSData *RTTSAnnexB(const uint8_t *sample, size_t length, int nalLengthSize, NSArray *sps, NSArray *pps, BOOL isSync);

// Writes the 7-byte ADTS header of an AAC frame with frameLength bytes of
// raw data.
void RTTSWriteADTSHeader(uint8_t header[7], int audioObjectType, int sampleRateIndex, int channelConfig,
                         size_t frameLength);

@interface RTTSWriter : NSObject
@property (nonatomic, readonly) NSMutableData *output;
@property (nonatomic) BOOL hasAudio;  // YES puts the audio stream in the PMT. The default is YES.
- (void)writeTables;  // The PAT and the PMT
- (void)writeVideo:(NSData *)annexB pts:(int64_t)pts dts:(int64_t)dts isSync:(BOOL)isSync;
- (void)writeAudio:(NSData *)adtsFrames pts:(int64_t)pts;
@end
