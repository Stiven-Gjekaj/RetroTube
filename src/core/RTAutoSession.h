// An HLS stream with more than one video quality. The main playlist lists
// each quality, and the player of iOS picks one by the speed of the network.
// It can change the quality between segments, because YouTube gives all
// the qualities of a video the same segment times (tested on 2026-10-17).

#import <Foundation/Foundation.h>
#import "RTStreamSession.h"

@interface RTAutoSession : NSObject <RTHLSSource>

// The qualities that Auto uses: the H.264 streams at these heights.
+ (NSArray *)autoHeights;

// videoFormats are the qualities. The player starts with the one that is
// nearest to 360p. audio can be nil.
- (instancetype)initWithVideos:(NSArray *)videoFormats audio:(RTFormat *)audio;
- (instancetype)initWithVideos:(NSArray *)videoFormats audio:(RTFormat *)audio reader:(RTRangeReader)reader;

// Reads the heads of all the qualities at the same time. It keeps the
// qualities with the same segments as the first one that loaded. Returns NO
// if no quality loaded. It blocks.
- (BOOL)prepare:(NSError **)error;

// The sessions that prepare kept, in the order of the main playlist.
@property (nonatomic, readonly) NSArray *sessions;

// The main playlist, "index.m3u8".
- (NSData *)masterPlaylist;

@end

// Picks one H.264 stream for each height of +[RTAutoSession autoHeights] that
// is not taller than maxHeight. Highest first.
NSArray *RTAutoFormats(RTPlayerInfo *info, NSInteger maxHeight);
