// Plays one video as HLS: it reads the DASH streams of the video and the
// audio with range requests, and it gives the playlist and the segments.
// Each segment is one entry of the segment index of the video.

#import <Foundation/Foundation.h>
#import "RTPlayer.h"

// The source of an HLS stream for RTHLSServer.
@protocol RTHLSSource <NSObject>
// Gives a file of the stream. path is the part of the URL after the
// session, for example "index.m3u8" or "v1/4.ts". status gets 200, 404 for
// a path that does not exist, or 502 for a file that did not load. It can
// block.
- (NSData *)dataForPath:(NSString *)path contentType:(NSString **)contentType status:(NSInteger *)status;
@end

// Reads a range of bytes of a URL. It blocks. The range is [start, end].
typedef NSData *(^RTRangeReader)(NSURL *url, uint64_t start, uint64_t end, NSError **error);

@interface RTStreamSession : NSObject <RTHLSSource>

@property (nonatomic, readonly) RTFormat *videoFormat;
@property (nonatomic, readonly) RTFormat *audioFormat;
@property (nonatomic, readonly) NSUInteger segmentCount;

// audio can be nil. Then the stream has no sound.
- (instancetype)initWithVideo:(RTFormat *)video audio:(RTFormat *)audio;

// Tests give their own reader. The default reader uses NSURLConnection.
- (instancetype)initWithVideo:(RTFormat *)video audio:(RTFormat *)audio reader:(RTRangeReader)reader;

// Reads the init segments and the indexes. It blocks. Call it before the
// other methods.
- (BOOL)prepare:(NSError **)error;

// The number of segments that load before the player asks for them. The
// default is 2. Set it before the first segment.
@property (nonatomic) NSUInteger prefetchDepth;

// Another session of the same video, from which this session takes its
// sound blocks. The qualities of an Auto stream share one sound cache.
@property (nonatomic, strong) RTStreamSession *audioOwner;

// The duration of the segment in seconds.
- (double)durationOfSegment:(NSUInteger)index;

// The playlist of the segments, "index.m3u8".
- (NSData *)playlist;

// Returns the TS data of the segment, or nil. It can block.
- (NSData *)segmentAtIndex:(NSUInteger)index error:(NSError **)error;

@end

// The default range reader. It sends a Range header and tries 3 times.
NSData *RTReadRange(NSURL *url, uint64_t start, uint64_t end, NSError **error);
