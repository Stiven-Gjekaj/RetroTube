// Reads the JSON answers of the InnerTube API into RTModels objects.
// The functions do not use the network. They accept the parsed JSON.

#import <Foundation/Foundation.h>
#import "RTModels.h"

// Returns the text of an InnerTube text object.
// It accepts {"simpleText": "..."} and {"runs": [{"text": "..."}, ...]}.
NSString *RTText(id textObject);

// Returns the URL of the widest thumbnail that is not wider than maxWidth.
// If all thumbnails are wider, it returns the narrowest one.
NSURL *RTThumbnailURL(id thumbnailObject, NSInteger maxWidth);

// Reads the videos, the channels, and the continuation token of an answer of
// /search, /browse, or /next, and of their continuation answers.
// The items are in the order of the answer, with no duplicates.
RTPage *RTParsePage(NSDictionary *json);

// Reads the channel of a /browse answer of a channel page: its ID, title,
// handle, subscribers, and a small picture. Returns nil if there is none.
RTChannel *RTParseChannelHeader(NSDictionary *json);
