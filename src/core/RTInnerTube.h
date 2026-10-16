// Makes the requests of the InnerTube API and sends them.
// Lists use the MWEB client, because its answers are small.
// The player uses the IOS client, because it gives stream URLs with no cipher.
// docs/decisions.md gives the measurements.

#import <Foundation/Foundation.h>
#import "RTModels.h"
#import "RTPlayer.h"

typedef void (^RTJSONHandler)(NSDictionary *json, NSError *error);
typedef void (^RTPageHandler)(RTPage *page, NSError *error);
typedef void (^RTPlayerHandler)(RTPlayerInfo *info, NSError *error);

extern NSString *const RTInnerTubeErrorDomain;

// The search filter that gives only channels.
extern NSString *const RTSearchParamsChannels;
// The channel tab that gives the videos, newest first.
extern NSString *const RTBrowseParamsChannelVideos;

@interface RTInnerTube : NSObject

// language is the "hl" value, for example "en". region is the "gl" value,
// for example "US".
- (instancetype)initWithLanguage:(NSString *)language region:(NSString *)region;

// Uses the language and the region of the phone.
+ (instancetype)shared;

- (NSURLRequest *)searchRequest:(NSString *)query params:(NSString *)params;
- (NSURLRequest *)browseRequest:(NSString *)browseId params:(NSString *)params;
- (NSURLRequest *)nextRequest:(NSString *)videoId;
// endpoint is "search", "browse", or "next": the endpoint of the first page.
- (NSURLRequest *)continuationRequest:(NSString *)token endpoint:(NSString *)endpoint;
- (NSURLRequest *)playerRequest:(NSString *)videoId;

// Sends the request and parses the JSON on a background queue.
// The handler runs on the main queue.
- (void)send:(NSURLRequest *)request handler:(RTJSONHandler)handler;
- (void)sendPage:(NSURLRequest *)request handler:(RTPageHandler)handler;
- (void)sendPlayer:(NSURLRequest *)request handler:(RTPlayerHandler)handler;

@end
