// Makes one MPEG-TS segment from DASH fragments of video and audio.

#import <Foundation/Foundation.h>
#import "RTMP4.h"

// All timestamps get this offset, so that a decode time before the
// presentation time of the first frame stays positive. Units of 90 kHz.
extern const int64_t RTRemuxTimeOffset;

// videoData holds the moof and mdat boxes of the video. audioData holds the
// moof and mdat boxes of the audio that covers the same time, or nil.
// The segment gets the audio frames that start in [startSeconds, endSeconds).
// The times are presentation times, after the edit list of the video.
NSData *RTRemuxSegment(RTMP4Track *video, NSData *videoData, RTMP4Track *audio, NSData *audioData,
                       double startSeconds, double endSeconds, NSError **error);
