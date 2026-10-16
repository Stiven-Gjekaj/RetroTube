// Reads the RSS feed of a channel:
// https://www.youtube.com/feeds/videos.xml?channel_id=UC...
// The feed is small XML with the 15 newest videos. It has no durations.

#import <Foundation/Foundation.h>
#import "RTModels.h"

NSURL *RTFeedURL(NSString *channelId);

// Returns the videos of the feed, newest first, or nil if the data is not a
// feed. viewsText and publishedText use now.
NSArray *RTParseFeed(NSData *data, NSDate *now);

// Reads an ISO 8601 time such as "2026-09-20T08:52:27+00:00".
NSDate *RTParseISODate(NSString *text);
