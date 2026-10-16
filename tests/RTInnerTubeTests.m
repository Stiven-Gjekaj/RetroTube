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

RT_TEST(test_player_request_uses_visionos_client_with_visitor) {
    NSURLRequest *request = [Client() playerRequest:@"abc" visitorData:@"VISITOR"];
    RT_EXPECT([request.URL.path hasSuffix:@"/player"]);
    NSDictionary *body = Body(request);
    RT_EQUAL(body[@"videoId"], @"abc");
    RT_EQUAL(body[@"context"][@"client"][@"clientName"], @"VISIONOS");
    RT_EQUAL(body[@"context"][@"client"][@"visitorData"], @"VISITOR");
    RT_EQUAL([request valueForHTTPHeaderField:@"X-Goog-Visitor-Id"], @"VISITOR");
    RT_EQUAL([request valueForHTTPHeaderField:@"X-YouTube-Client-Name"], @"101");
}

RT_TEST(test_player_request_without_visitor_has_no_visitor_header) {
    NSURLRequest *request = [Client() playerRequest:@"abc" visitorData:nil];
    RT_EXPECT([request valueForHTTPHeaderField:@"X-Goog-Visitor-Id"] == nil);
    RT_EXPECT(Body(request)[@"context"][@"client"][@"visitorData"] == nil);
}

RT_TEST(test_visitor_request_goes_to_visitor_id) {
    RT_EXPECT([[Client() visitorRequest].URL.path hasSuffix:@"/visitor_id"]);
}

RT_TEST(test_request_with_region_changes_only_the_region) {
    NSURLRequest *request = [Client() searchRequest:@"x" params:nil];
    NSURLRequest *copy = [RTInnerTube request:request withRegion:@"US"];
    RT_EQUAL(Body(copy)[@"context"][@"client"][@"gl"], @"US");
    RT_EQUAL(Body(copy)[@"context"][@"client"][@"hl"], @"sq");
    RT_EQUAL(Body(copy)[@"query"], @"x");
    RT_EQUAL(copy.URL, request.URL);
    RT_EQUAL([copy valueForHTTPHeaderField:@"User-Agent"], [request valueForHTTPHeaderField:@"User-Agent"]);
    RT_EQUAL(Body(request)[@"context"][@"client"][@"gl"], @"AL");
}

RT_TEST(test_live_refused_region_changes_to_us) {
    RT_LIVE_ONLY();
    RTInnerTube *client = [[RTInnerTube alloc] initWithLanguage:@"sq" region:@"AL"];
    __block RTPage *result = nil;
    BOOL done = NO;
    BOOL *donePointer = &done;
    [client sendPage:[client searchRequest:@"daft punk" params:nil] handler:^(RTPage *page, NSError *error) {
        result = page;
        *donePointer = YES;
    }];
    RT_EXPECT(RTTestWait(&done, 30));
    RT_EXPECT(result.items.count >= 10);
    RT_EQUAL(client.region, @"US");
}

RT_TEST(test_live_two_requests_with_refused_region_both_succeed) {
    RT_LIVE_ONLY();
    RTInnerTube *client = [[RTInnerTube alloc] initWithLanguage:@"en" region:@"AL"];
    // Both requests have the region AL. The first answer changes the region
    // of the client. The second request must still try again with US.
    NSURLRequest *first = [client searchRequest:@"retro tv" params:nil];
    NSURLRequest *second = [client searchRequest:@"retro tv" params:nil];
    __block int count = 0, failures = 0;
    BOOL done = NO;
    BOOL *donePointer = &done;
    void (^handler)(RTPage *, NSError *) = ^(RTPage *page, NSError *error) {
        if (error || !page.items.count) failures++;
        if (++count == 2) *donePointer = YES;
    };
    [client sendPage:first handler:handler];
    [client sendPage:second handler:handler];
    RT_EXPECT(RTTestWait(&done, 30));
    RT_EQUAL_INT(failures, 0);
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

RT_TEST(test_live_player_gives_full_h264_and_aac) {
    RT_LIVE_ONLY();
    RTInnerTube *client = [[RTInnerTube alloc] initWithLanguage:@"en" region:@"US"];
    NSError *error = nil;
    RTPlayerInfo *info = [client loadPlayer:@"a5uQMwRMHcs" error:&error];
    RT_EQUAL(info.status, @"OK");
    RT_EXPECT(client.visitorData.length > 0);
    RTFormat *video = [info videoFormatForMaxHeight:720];
    RT_EXPECT(video != nil);
    RT_EXPECT(info.audioFormat != nil);
    // The URL must serve the end of the file. The IOS client stopped at the
    // first minute without a PO token.
    for (RTFormat *format in @[ video, info.audioFormat ]) {
        NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:format.url
            cachePolicy:NSURLRequestReloadIgnoringLocalCacheData timeoutInterval:20];
        long long end = format.contentLength - 1;
        [request setValue:[NSString stringWithFormat:@"bytes=%lld-%lld", end - 999, end] forHTTPHeaderField:@"Range"];
        NSHTTPURLResponse *response = nil;
        NSData *data = [NSURLConnection sendSynchronousRequest:request returningResponse:(NSURLResponse **)&response error:NULL];
        RT_EQUAL_INT(response.statusCode, 206);
        RT_EQUAL_INT(data.length, 1000);
    }
}
