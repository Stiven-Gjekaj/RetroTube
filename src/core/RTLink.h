// Reads a link to a search, a video, or a channel.
// It accepts retrotube:// links and YouTube web links.

#import <Foundation/Foundation.h>

typedef NS_ENUM(NSInteger, RTLinkKind) {
    RTLinkNone,
    RTLinkSearch,
    RTLinkVideo,
    RTLinkChannel,
};

@interface RTLink : NSObject
@property (nonatomic) RTLinkKind kind;
@property (nonatomic, copy) NSString *value;  // The query, the video ID, or the channel ID
@end

// Returns a link of kind RTLinkNone if the URL is not one of these:
//   retrotube://search?q=QUERY
//   retrotube://watch?v=ID
//   retrotube://channel?id=UC...
//   https://www.youtube.com/watch?v=ID (also m.youtube.com and music.youtube.com)
//   https://youtu.be/ID
//   https://www.youtube.com/shorts/ID, /live/ID, /embed/ID
//   https://www.youtube.com/channel/UC...
RTLink *RTParseLink(NSURL *url);

// Reads text that the person typed or pasted. A YouTube link gives its kind.
// Other text gives a search. Text that is empty gives RTLinkNone.
RTLink *RTParseText(NSString *text);
