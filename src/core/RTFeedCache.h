// Keeps the last feed on disk, so that the Feed tab shows it at once at the
// next launch while the new feed loads.

#import <Foundation/Foundation.h>

// Writes the videos of the feed of these channel IDs.
void RTSaveFeed(NSString *path, NSArray *channelIds, NSArray *videos);

// Reads the saved videos if they are the feed of these channel IDs, or nil.
// The ages, such as "2 days ago", are made again for now.
NSArray *RTLoadFeed(NSString *path, NSArray *channelIds, NSDate *now);

// The path in the caches directory of the app.
NSString *RTFeedCachePath(void);
