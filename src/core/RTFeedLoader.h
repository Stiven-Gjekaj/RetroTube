// Loads the RSS feeds of many channels and joins them into one feed.

#import <Foundation/Foundation.h>

// The longest feed.
extern const NSUInteger RTFeedLimit;

// Loads the feed of each channel ID at the same time, at most 4 at a time.
// The handler runs on the main queue with the videos, newest first, and the
// number of channels that did not load.
void RTLoadFeeds(NSArray *channelIds, void (^handler)(NSArray *videos, NSUInteger failures));
