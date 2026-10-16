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
static NSString *const RTVisionVersion = @"0.1";
static NSString *const RTVisionAgent =
    @"Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Safari/605.1.15";
static NSString *const RTVisitorDefaultsKey = @"RTVisitorData";

@interface RTInnerTube ()
@property (nonatomic, copy) NSString *language;
@property (nonatomic, copy) NSString *region;
@property (nonatomic, strong) NSOperationQueue *queue;
@end

@implementation RTInnerTube

@synthesize visitorData = _visitorData;

- (instancetype)initWithLanguage:(NSString *)language region:(NSString *)region {
    if ((self = [super init])) {
        _language = [language copy] ?: @"en";
        _region = [region copy] ?: @"US";
        _queue = [NSOperationQueue new];
        _queue.maxConcurrentOperationCount = 4;
        _visitorData = [[NSUserDefaults standardUserDefaults] stringForKey:RTVisitorDefaultsKey];
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

- (NSURLRequest *)visitorRequest {
    return [self requestTo:@"visitor_id" body:@{ @"context": [self mwebContext] } agent:RTMWEBAgent];
}

- (NSURLRequest *)playerRequest:(NSString *)videoId visitorData:(NSString *)visitorData {
    NSMutableDictionary *client = [@{ @"clientName": @"VISIONOS", @"clientVersion": RTVisionVersion,
                                      @"deviceMake": @"Apple", @"deviceModel": @"RealityDevice14,1",
                                      @"osName": @"visionOS", @"osVersion": @"1.3.21O771",
                                      @"hl": self.language, @"gl": self.region } mutableCopy];
    if (visitorData) client[@"visitorData"] = visitorData;
    NSDictionary *body = @{ @"context": @{ @"client": client }, @"videoId": videoId ?: @"",
                            @"contentCheckOk": @YES, @"racyCheckOk": @YES };
    NSMutableURLRequest *request = [self requestTo:@"player" body:body agent:RTVisionAgent];
    [request setValue:@"101" forHTTPHeaderField:@"X-YouTube-Client-Name"];
    [request setValue:RTVisionVersion forHTTPHeaderField:@"X-YouTube-Client-Version"];
    if (visitorData) [request setValue:visitorData forHTTPHeaderField:@"X-Goog-Visitor-Id"];
    return request;
}

- (void)setVisitorData:(NSString *)visitorData {
    @synchronized (self) {
        _visitorData = [visitorData copy];
    }
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    if (visitorData) [defaults setObject:visitorData forKey:RTVisitorDefaultsKey];
    else [defaults removeObjectForKey:RTVisitorDefaultsKey];
}

- (NSString *)visitorData {
    @synchronized (self) {
        return _visitorData;
    }
}

// Sends a request and gives the JSON answer. It blocks.
- (NSDictionary *)sendNow:(NSURLRequest *)request error:(NSError **)error {
    NSHTTPURLResponse *response = nil;
    NSData *data = [NSURLConnection sendSynchronousRequest:request returningResponse:(NSURLResponse **)&response
                                                     error:error];
    if (!data) return nil;
    id json = [NSJSONSerialization JSONObjectWithData:data options:0 error:error];
    if (response.statusCode == 200 && [json isKindOfClass:[NSDictionary class]]) return json;
    if (error) {
        NSString *text = [NSString stringWithFormat:@"YouTube answered with HTTP %ld.", (long)response.statusCode];
        *error = [NSError errorWithDomain:RTInnerTubeErrorDomain code:response.statusCode
                                 userInfo:@{ NSLocalizedDescriptionKey: text }];
    }
    return nil;
}

- (RTPlayerInfo *)loadPlayer:(NSString *)videoId error:(NSError **)error {
    RTPlayerInfo *info = nil;
    for (int attempt = 0; attempt < 2; attempt++) {
        if (!self.visitorData) {
            NSDictionary *json = [self sendNow:[self visitorRequest] error:error];
            id visitor = json[@"responseContext"][@"visitorData"];
            if (![visitor isKindOfClass:[NSString class]]) {
                if (error && !*error) {
                    *error = [NSError errorWithDomain:RTInnerTubeErrorDomain code:1
                                             userInfo:@{ NSLocalizedDescriptionKey: @"YouTube gave no visitor ID." }];
                }
                return nil;
            }
            self.visitorData = visitor;
        }
        NSDictionary *json = [self sendNow:[self playerRequest:videoId visitorData:self.visitorData] error:error];
        if (!json) return nil;
        info = RTParsePlayer(json);
        // YouTube refuses a visitor ID that it marks as a bot. Get a new one.
        if (![info.status isEqualToString:@"LOGIN_REQUIRED"] || info.videoFormats.count) break;
        self.visitorData = nil;
    }
    return info;
}

- (void)loadPlayer:(NSString *)videoId handler:(RTPlayerHandler)handler {
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^{
        NSError *error = nil;
        RTPlayerInfo *info = [self loadPlayer:videoId error:&error];
        dispatch_async(dispatch_get_main_queue(), ^{ handler(info, info ? nil : error); });
    });
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

@end
