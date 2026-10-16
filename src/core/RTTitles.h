// Gets the original titles of videos.
// YouTube search can give the title that a creator translated into another
// language, chosen by its own rules. The oEmbed endpoint of YouTube gives the
// original title of a video in a small JSON answer.

#import <Foundation/Foundation.h>

NSURL *RTOEmbedURL(NSString *videoId);

// Reads the title of an oEmbed answer, or nil.
NSString *RTParseOEmbedTitle(NSData *data);

// Gets the original title of each video ID, at most 4 at a time. The
// handler runs on the main queue one time, with a dictionary from video ID
// to title. A video that did not load is not in it.
void RTLoadOriginalTitles(NSArray *videoIds, void (^handler)(NSDictionary *titles));
