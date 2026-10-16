#import "RTInnerTube.h"
#import "RTParse.h"

NSString *const RTInnerTubeErrorDomain = @"RTInnerTube";
NSString *const RTSearchParamsChannels = @"EgIQAg==";
NSString *const RTBrowseParamsChannelVideos = @"EgZ2aWRlb3PyBgQKAjoA";

static NSString *const RTBaseURL = @"https://www.youtube.com/youtubei/v1/";
static NSString *const RTMWEBVersion = @"2.20240101.00.00";
static NSString *const RTMWEBAgent =
    @"Mozilla/5.0 (iPhone; CPU iPhone OS 6_1_3 like Mac OS X) AppleWebKit/536.26 (KHTML, like Gecko) "
    @"Version/6.0 Mobile/10B329 Safari/8536.25";
static NSString *const RTIOSVersion = @"20.10.4";
static NSString *const RTIOSAgent = @"com.google.ios.youtube/20.10.4 (iPhone16,2; U; CPU iOS 18_3_2 like Mac OS X;)";

@interface RTInnerTube ()
@property (nonatomic, copy) NSString *language;
@property (nonatomic, copy) NSString *region;
@property (nonatomic, strong) NSOperationQueue *queue;
@end

@implementation RTInnerTube

- (instancetype)initWithLanguage:(NSString *)language region:(NSString *)region {
    if ((self = [super init])) {
        _language = [language copy] ?: @"en";
        _region = [region copy] ?: @"US";
        _queue = [NSOperationQueue new];
        _queue.maxConcurrentOperationCount = 4;
    }
    return self;
}

+ (instancetype)shared {
    static RTInnerTube *shared;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        NSString *language = [[NSLocale preferredLanguages] firstObject];
        // "pt-BR" becomes "pt", because InnerTube accepts a short code.
        language = [[language componentsSeparatedByString:@"-"] firstObject];
        NSString *region = [[NSLocale currentLocale] objectForKey:NSLocaleCountryCode];
        shared = [[RTInnerTube alloc] initWithLanguage:language region:region];
    });
    return shared;
}

- (NSDictionary *)mwebContext {
    return @{ @"client": @{ @"clientName": @"MWEB", @"clientVersion": RTMWEBVersion,
                            @"hl": self.language, @"gl": self.region } };
}

- (NSMutableURLRequest *)requestTo:(NSString *)endpoint body:(NSDictionary *)body agent:(NSString *)agent {
    NSString *url = [NSString stringWithFormat:@"%@%@?prettyPrint=false", RTBaseURL, endpoint];
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:url]];
    request.HTTPMethod = @"POST";
    request.HTTPBody = [NSJSONSerialization dataWithJSONObject:body options:0 error:NULL];
    request.timeoutInterval = 20;
    [request setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
    [request setValue:agent forHTTPHeaderField:@"User-Agent"];
    return request;
}

- (NSURLRequest *)searchRequest:(NSString *)query params:(NSString *)params {
    NSMutableDictionary *body = [@{ @"context": [self mwebContext], @"query": query ?: @"" } mutableCopy];
    if (params) body[@"params"] = params;
    return [self requestTo:@"search" body:body agent:RTMWEBAgent];
}

- (NSURLRequest *)browseRequest:(NSString *)browseId params:(NSString *)params {
    NSMutableDictionary *body = [@{ @"context": [self mwebContext], @"browseId": browseId ?: @"" } mutableCopy];
    if (params) body[@"params"] = params;
    return [self requestTo:@"browse" body:body agent:RTMWEBAgent];
}

- (NSURLRequest *)nextRequest:(NSString *)videoId {
    return [self requestTo:@"next" body:@{ @"context": [self mwebContext], @"videoId": videoId ?: @"" } agent:RTMWEBAgent];
}

- (NSURLRequest *)continuationRequest:(NSString *)token endpoint:(NSString *)endpoint {
    return [self requestTo:endpoint body:@{ @"context": [self mwebContext], @"continuation": token ?: @"" }
                     agent:RTMWEBAgent];
}

- (NSURLRequest *)playerRequest:(NSString *)videoId {
    NSDictionary *client = @{ @"clientName": @"IOS", @"clientVersion": RTIOSVersion,
                              @"deviceMake": @"Apple", @"deviceModel": @"iPhone16,2",
                              @"osName": @"iPhone", @"osVersion": @"18.3.2.22D82",
                              @"hl": self.language, @"gl": self.region };
    NSDictionary *body = @{ @"context": @{ @"client": client }, @"videoId": videoId ?: @"",
                            @"contentCheckOk": @YES, @"racyCheckOk": @YES };
    NSMutableURLRequest *request = [self requestTo:@"player" body:body agent:RTIOSAgent];
    [request setValue:@"5" forHTTPHeaderField:@"X-YouTube-Client-Name"];
    [request setValue:RTIOSVersion forHTTPHeaderField:@"X-YouTube-Client-Version"];
    return request;
}

// Sends the request. On the background queue, it parses the JSON and gives it
// to transform. The handler gets the result of transform on the main queue.
- (void)send:(NSURLRequest *)request transform:(id (^)(NSDictionary *json))transform
     handler:(void (^)(id result, NSError *error))handler {
    [NSURLConnection sendAsynchronousRequest:request queue:self.queue
                           completionHandler:^(NSURLResponse *response, NSData *data, NSError *error) {
        id result = nil;
        if (!error) {
            NSInteger status = [(NSHTTPURLResponse *)response statusCode];
            id parsed = data ? [NSJSONSerialization JSONObjectWithData:data options:0 error:&error] : nil;
            if ([parsed isKindOfClass:[NSDictionary class]] && status == 200) {
                result = transform(parsed);
            } else if (!error) {
                NSString *text = [NSString stringWithFormat:@"YouTube answered with HTTP %ld.", (long)status];
                error = [NSError errorWithDomain:RTInnerTubeErrorDomain code:status
                                        userInfo:@{ NSLocalizedDescriptionKey: text }];
            }
        }
        dispatch_async(dispatch_get_main_queue(), ^{ handler(result, error); });
    }];
}

- (void)send:(NSURLRequest *)request handler:(RTJSONHandler)handler {
    [self send:request transform:^id(NSDictionary *json) { return json; } handler:handler];
}

- (void)sendPage:(NSURLRequest *)request handler:(RTPageHandler)handler {
    [self send:request transform:^id(NSDictionary *json) { return RTParsePage(json); } handler:handler];
}

- (void)sendPlayer:(NSURLRequest *)request handler:(RTPlayerHandler)handler {
    [self send:request transform:^id(NSDictionary *json) { return RTParsePlayer(json); } handler:handler];
}

@end
