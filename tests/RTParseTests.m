#import "RTTest.h"
#import "RTParse.h"

// Makes an InnerTube text object with one run for each argument.
static NSDictionary *Runs(NSArray *texts) {
    NSMutableArray *runs = [NSMutableArray array];
    for (NSString *text in texts) [runs addObject:@{ @"text": text }];
    return @{ @"runs": runs };
}

static NSDictionary *Video(NSString *videoId, NSString *title) {
    return @{ @"videoWithContextRenderer": @{
        @"videoId": videoId,
        @"headline": Runs(@[ title ]),
        @"shortBylineText": @{ @"runs": @[ @{ @"text": @"Maker",
            @"navigationEndpoint": @{ @"browseEndpoint": @{ @"browseId": @"UCmaker" } } } ] },
        @"lengthText": Runs(@[ @"5:40" ]),
        @"shortViewCountText": Runs(@[ @"904M views" ]),
        @"publishedTimeText": Runs(@[ @"12 years ago" ]),
        @"thumbnail": @{ @"thumbnails": @[
            @{ @"url": @"https://i.ytimg.com/a.jpg", @"width": @120, @"height": @90 },
            @{ @"url": @"https://i.ytimg.com/b.jpg", @"width": @320, @"height": @180 },
            @{ @"url": @"https://i.ytimg.com/c.jpg", @"width": @480, @"height": @360 } ] } } };
}

static NSDictionary *Continuation(NSString *token) {
    return @{ @"continuationItemRenderer": @{ @"continuationEndpoint": @{
        @"continuationCommand": @{ @"token": token } } } };
}

RT_TEST(test_text_joins_runs) {
    RT_EQUAL(RTText(Runs(@[ @"Daft ", @"Punk" ])), @"Daft Punk");
}

RT_TEST(test_text_reads_simple_text) {
    RT_EQUAL(RTText(@{ @"simpleText": @"4:09" }), @"4:09");
}

RT_TEST(test_text_of_other_values_is_nil) {
    RT_EXPECT(RTText(nil) == nil);
    RT_EXPECT(RTText(@"plain") == nil);
    RT_EXPECT(RTText(@{ @"runs": @[] }) == nil);
}

RT_TEST(test_thumbnail_is_widest_that_fits) {
    NSDictionary *thumb = Video(@"a", @"t")[@"videoWithContextRenderer"][@"thumbnail"];
    RT_EQUAL(RTThumbnailURL(thumb, 320).absoluteString, @"https://i.ytimg.com/b.jpg");
    RT_EQUAL(RTThumbnailURL(thumb, 400).absoluteString, @"https://i.ytimg.com/b.jpg");
    RT_EQUAL(RTThumbnailURL(thumb, 1000).absoluteString, @"https://i.ytimg.com/c.jpg");
}

RT_TEST(test_thumbnail_falls_back_to_narrowest) {
    NSDictionary *thumb = Video(@"a", @"t")[@"videoWithContextRenderer"][@"thumbnail"];
    RT_EQUAL(RTThumbnailURL(thumb, 50).absoluteString, @"https://i.ytimg.com/a.jpg");
}

RT_TEST(test_thumbnail_adds_scheme_to_protocol_relative_url) {
    NSDictionary *thumb = @{ @"thumbnails": @[ @{ @"url": @"//yt3.ggpht.com/x", @"width": @88 } ] };
    RT_EQUAL(RTThumbnailURL(thumb, 88).absoluteString, @"https://yt3.ggpht.com/x");
}

RT_TEST(test_page_reads_video_fields) {
    RTPage *page = RTParsePage(@{ @"contents": @[ Video(@"v1", @"First") ] });
    RT_EQUAL_INT(page.items.count, 1);
    RTVideo *video = page.items[0];
    RT_EQUAL(video.videoId, @"v1");
    RT_EQUAL(video.title, @"First");
    RT_EQUAL(video.channelName, @"Maker");
    RT_EQUAL(video.channelId, @"UCmaker");
    RT_EQUAL(video.lengthText, @"5:40");
    RT_EQUAL(video.viewsText, @"904M views");
    RT_EQUAL(video.publishedText, @"12 years ago");
    RT_EQUAL(video.thumbnailURL.absoluteString, @"https://i.ytimg.com/b.jpg");
}

RT_TEST(test_page_marks_video_with_no_length_as_live) {
    NSMutableDictionary *renderer = [Video(@"v1", @"Live")[@"videoWithContextRenderer"] mutableCopy];
    [renderer removeObjectForKey:@"lengthText"];
    RTVideo *live = RTParsePage(@{ @"contents": @[ @{ @"videoWithContextRenderer": renderer } ] }).items[0];
    RTVideo *normal = RTParsePage(@{ @"contents": @[ Video(@"v2", @"Normal") ] }).items[0];
    RT_EXPECT(live.isLive);
    RT_EXPECT(!normal.isLive);
}

RT_TEST(test_page_keeps_order_and_drops_duplicates) {
    NSDictionary *json = @{ @"a": @{ @"contents": @[
        Video(@"v1", @"1"), @{ @"shelf": @[ Video(@"v2", @"2"), Video(@"v1", @"again") ] }, Video(@"v3", @"3") ] } };
    NSArray *ids = [RTParsePage(json).items valueForKey:@"videoId"];
    RT_EQUAL(ids, (@[ @"v1", @"v2", @"v3" ]));
}

RT_TEST(test_page_reads_mweb_channel) {
    NSDictionary *json = @{ @"contents": @[ @{ @"compactChannelRenderer": @{
        @"channelId": @"UC1",
        @"title": Runs(@[ @"Daft Punk" ]),
        @"subscriberCountText": Runs(@[ @"@daftpunk" ]),
        @"videoCountText": Runs(@[ @"7.2M subscribers" ]),
        @"thumbnail": @{ @"thumbnails": @[ @{ @"url": @"https://yt3.ggpht.com/s88", @"width": @88 } ] } } } ] };
    RTChannel *channel = RTParsePage(json).items[0];
    RT_EXPECT([channel isKindOfClass:[RTChannel class]]);
    RT_EQUAL(channel.title, @"Daft Punk");
    RT_EQUAL(channel.handle, @"@daftpunk");
    RT_EQUAL(channel.subscribersText, @"7.2M subscribers");
    RT_EQUAL(channel.avatarURL.absoluteString, @"https://yt3.ggpht.com/s88");
}

RT_TEST(test_page_continuation_is_in_the_list_with_most_items) {
    NSDictionary *json = @{
        @"panel": @[ Video(@"p1", @"panel"), Continuation(@"panel-token") ],
        @"main": @[ Video(@"m1", @"1"), Video(@"m2", @"2"), Video(@"m3", @"3"), Continuation(@"main-token") ] };
    RT_EQUAL(RTParsePage(json).continuation, @"main-token");
}

RT_TEST(test_page_with_no_continuation_has_nil_token) {
    RT_EXPECT(RTParsePage(@{ @"contents": @[ Video(@"v1", @"1") ] }).continuation == nil);
}

RT_TEST(test_page_ignores_values_of_wrong_type) {
    NSDictionary *json = @{ @"contents": @[ @{ @"videoWithContextRenderer": @"text" },
                                            @{ @"videoWithContextRenderer": @{ @"videoId": @7 } },
                                            @{ @"compactChannelRenderer": @[] } ] };
    RT_EQUAL_INT(RTParsePage(json).items.count, 0);
}
