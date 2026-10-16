// Makes the requests of the InnerTube API and sends them.
// Lists use the MWEB client, because its answers are small.
// The player uses the VISIONOS client with a visitor ID. It gives H.264 and
// AAC stream URLs with no cipher, and the URLs serve the full file.
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

// The region of the requests. YouTube does not accept all regions, for
// example "AL". It answers a search with HTTP 400, and other pages with no
// items. Before the first request, the client checks the region one time
// with a search, and changes it to "US" if YouTube refuses it. The result
// stays in the user defaults.
@property (nonatomic, readonly, copy) NSString *region;

// Returns a copy of the request with the region in its body changed.
+ (NSURLRequest *)request:(NSURLRequest *)request withRegion:(NSString *)region;

- (NSURLRequest *)searchRequest:(NSString *)query params:(NSString *)params;
- (NSURLRequest *)browseRequest:(NSString *)browseId params:(NSString *)params;
- (NSURLRequest *)nextRequest:(NSString *)videoId;
// endpoint is "search", "browse", or "next": the endpoint of the first page.
- (NSURLRequest *)continuationRequest:(NSString *)token endpoint:(NSString *)endpoint;
- (NSURLRequest *)visitorRequest;
- (NSURLRequest *)playerRequest:(NSString *)videoId visitorData:(NSString *)visitorData;

// The visitor ID that the player requests use. It persists in the user
// defaults. Set it to nil to get a new one.
@property (nonatomic, copy) NSString *visitorData;

// Gets a visitor ID if there is none, then sends the player request. If
// YouTube asks for a sign-in, it gets a new visitor ID and tries one more
// time. It blocks.
- (RTPlayerInfo *)loadPlayer:(NSString *)videoId error:(NSError **)error;

// Sends the request and parses the JSON on a background queue.
// The handler runs on the main queue.
- (void)send:(NSURLRequest *)request handler:(RTJSONHandler)handler;
- (void)sendPage:(NSURLRequest *)request handler:(RTPageHandler)handler;
// Sends the request. transform runs on a background queue with the JSON
// answer. The handler gets its result on the main queue.
- (void)send:(NSURLRequest *)request transform:(id (^)(NSDictionary *json))transform
     handler:(void (^)(id result, NSError *error))handler;
// Runs loadPlayer:error: on a background queue. The handler runs on the main queue.
- (void)loadPlayer:(NSString *)videoId handler:(RTPlayerHandler)handler;

@end
