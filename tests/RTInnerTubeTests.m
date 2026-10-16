#import "RTTest.h"
#import "RTInnerTube.h"

static NSDictionary *Body(NSURLRequest *request) {
    return [NSJSONSerialization JSONObjectWithData:request.HTTPBody options:0 error:NULL];
}

static RTInnerTube *Client(void) {
    return [[RTInnerTube alloc] initWithLanguage:@"sq" region:@"AL"];
}

RT_TEST(test_search_request_uses_mweb) {
    NSURLRequest *request = [Client() searchRequest:@"daft punk" params:nil];
    RT_EQUAL(request.HTTPMethod, @"POST");
    RT_EQUAL(request.URL.absoluteString, @"https://www.youtube.com/youtubei/v1/search?prettyPrint=false");
    RT_EQUAL([request valueForHTTPHeaderField:@"Content-Type"], @"application/json");
    NSDictionary *body = Body(request);
    RT_EQUAL(body[@"query"], @"daft punk");
    RT_EQUAL(body[@"context"][@"client"][@"clientName"], @"MWEB");
    RT_EQUAL(body[@"context"][@"client"][@"hl"], @"sq");
    RT_EQUAL(body[@"context"][@"client"][@"gl"], @"AL");
    RT_EXPECT(body[@"params"] == nil);
}

RT_TEST(test_search_request_sends_filter) {
    RT_EQUAL(Body([Client() searchRequest:@"x" params:RTSearchParamsChannels])[@"params"], @"EgIQAg==");
}

RT_TEST(test_browse_request_sends_id_and_params) {
    NSURLRequest *request = [Client() browseRequest:@"UC1" params:RTBrowseParamsChannelVideos];
    RT_EXPECT([request.URL.path hasSuffix:@"/browse"]);
    RT_EQUAL(Body(request)[@"browseId"], @"UC1");
    RT_EQUAL(Body(request)[@"params"], RTBrowseParamsChannelVideos);
}

RT_TEST(test_continuation_request_goes_to_the_endpoint) {
    NSURLRequest *request = [Client() continuationRequest:@"TOKEN" endpoint:@"next"];
    RT_EXPECT([request.URL.path hasSuffix:@"/next"]);
    RT_EQUAL(Body(request)[@"continuation"], @"TOKEN");
    RT_EQUAL(Body(request)[@"context"][@"client"][@"clientName"], @"MWEB");
}

RT_TEST(test_player_request_uses_ios_client) {
    NSURLRequest *request = [Client() playerRequest:@"abc"];
    RT_EXPECT([request.URL.path hasSuffix:@"/player"]);
    NSDictionary *body = Body(request);
    RT_EQUAL(body[@"videoId"], @"abc");
    RT_EQUAL(body[@"context"][@"client"][@"clientName"], @"IOS");
    RT_EQUAL([request valueForHTTPHeaderField:@"X-YouTube-Client-Name"], @"5");
    RT_EXPECT([[request valueForHTTPHeaderField:@"User-Agent"] hasPrefix:@"com.google.ios.youtube/"]);
}

RT_TEST(test_live_search_gives_videos) {
    RT_LIVE_ONLY();
    __block RTPage *result = nil;
    __block NSError *failure = nil;
    BOOL done = NO;
    BOOL *donePointer = &done;
    RTInnerTube *client = [[RTInnerTube alloc] initWithLanguage:@"en" region:@"US"];
    [client sendPage:[client searchRequest:@"daft punk" params:nil] handler:^(RTPage *page, NSError *error) {
        result = page;
        failure = error;
        *donePointer = YES;
    }];
    RT_EXPECT(RTTestWait(&done, 30));
    RT_EXPECT(failure == nil);
    RT_EXPECT(result.items.count >= 10);
    RT_EXPECT(result.continuation.length > 0);
}

RT_TEST(test_live_player_gives_h264_and_aac) {
    RT_LIVE_ONLY();
    __block RTPlayerInfo *result = nil;
    BOOL done = NO;
    BOOL *donePointer = &done;
    RTInnerTube *client = [[RTInnerTube alloc] initWithLanguage:@"en" region:@"US"];
    [client sendPlayer:[client playerRequest:@"jNQXAC9IVRw"] handler:^(RTPlayerInfo *info, NSError *error) {
        result = info;
        *donePointer = YES;
    }];
    RT_EXPECT(RTTestWait(&done, 30));
    RT_EQUAL(result.status, @"OK");
    RT_EXPECT([result videoFormatForMaxHeight:720] != nil);
    RT_EXPECT(result.audioFormat != nil);
}
