// Reads the answer of the InnerTube /player API: the details of a video and
// the streams that the iPhone 4S can play.

#import <Foundation/Foundation.h>

// One stream of a video. A DASH stream has an init range and an index range.
@interface RTFormat : NSObject
@property (nonatomic) NSInteger itag;
@property (nonatomic, copy) NSURL *url;
@property (nonatomic, copy) NSString *mimeType;  // "video/mp4; codecs=\"avc1.4D401F\""
@property (nonatomic) NSInteger width;
@property (nonatomic) NSInteger height;
@property (nonatomic) NSInteger fps;
@property (nonatomic) NSInteger bitrate;
@property (nonatomic) long long contentLength;
@property (nonatomic) NSRange initRange;   // NSNotFound location if not known
@property (nonatomic) NSRange indexRange;  // NSNotFound location if not known
@end

@interface RTPlayerInfo : NSObject
@property (nonatomic, copy) NSString *videoId;
@property (nonatomic, copy) NSString *status;        // "OK", "LOGIN_REQUIRED", "UNPLAYABLE", ...
@property (nonatomic, copy) NSString *reason;        // The text that tells why it does not play
@property (nonatomic, copy) NSString *title;
@property (nonatomic, copy) NSString *author;
@property (nonatomic, copy) NSString *channelId;
@property (nonatomic, copy) NSString *shortDescription;
@property (nonatomic) NSInteger lengthSeconds;
@property (nonatomic) long long viewCount;
@property (nonatomic) BOOL isLive;
@property (nonatomic, copy) NSURL *hlsManifestURL;
@property (nonatomic, copy) NSArray *videoFormats;   // H.264 MP4 streams, highest first
@property (nonatomic, copy) NSArray *audioFormats;   // AAC MP4 streams, best first

// Returns the highest H.264 stream that is not taller than maxHeight and not
// faster than 30 frames each second. Returns nil if there is none.
- (RTFormat *)videoFormatForMaxHeight:(NSInteger)maxHeight;

// Returns the best AAC stream, or nil.
- (RTFormat *)audioFormat;
@end

RTPlayerInfo *RTParsePlayer(NSDictionary *json);
