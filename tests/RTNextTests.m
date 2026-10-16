#import "RTTest.h"
#import "RTNext.h"

static NSDictionary *Runs(NSString *text) {
    return @{ @"runs": @[ @{ @"text": text } ] };
}

// The shape of an MWEB /next answer, with only the parts that the app reads.
static NSDictionary *Answer(void) {
    NSDictionary *owner = @{ @"slimOwnerRenderer": @{
        @"title": @{ @"runs": @[ @{ @"text": @"Daft Punk",
            @"navigationEndpoint": @{ @"browseEndpoint": @{ @"browseId": @"UC_kRDKYrUlrbtrSiyu5Tflg" } } } ] },
        @"channelName": @"Daft Punk",
        @"expandedSubtitle": Runs(@"7.2M"),
        @"thumbnail": @{ @"thumbnails": @[ @{ @"url": @"https://yt3.ggpht.com/s48", @"width": @48 },
                                           @{ @"url": @"https://yt3.ggpht.com/s88", @"width": @88 } ] } } };
    NSDictionary *related = @{ @"videoWithContextRenderer": @{ @"videoId": @"5NV6Rdv1a3I",
                                                               @"headline": Runs(@"Get Lucky") } };
    NSDictionary *channelItem = @{ @"compactChannelRenderer": @{ @"channelId": @"UCother", @"title": Runs(@"Other") } };
    return @{
        @"contents": @{ @"singleColumnWatchNextResults": @{ @"results": @{ @"results": @{ @"contents": @[
            @{ @"slimVideoMetadataSectionRenderer": @{ @"contents": @[
                @{ @"slimVideoInformationRenderer": @{ @"title": Runs(@"Instant Crush (slim)") } }, owner ] } },
            @{ @"itemSectionRenderer": @{ @"contents": @[ related, channelItem,
                @{ @"continuationItemRenderer": @{ @"continuationEndpoint": @{
                    @"continuationCommand": @{ @"token": @"NEXT" } } } } ] } } ] } } } },
        @"engagementPanels": @[ @{ @"engagementPanelSectionListRenderer": @{ @"content": @{
            @"structuredDescriptionContentRenderer": @{ @"items": @[
                @{ @"videoDescriptionHeaderRenderer": @{
                    @"title": Runs(@"Instant Crush"),
                    @"views": Runs(@"904,270,011 views"),
                    @"publishDate": Runs(@"Dec 6, 2013"),
                    @"factoid": @[ @{ @"sentimentFactoidRenderer": @{ @"factoidIfLiked": @{
                        @"factoidRenderer": @{ @"value": Runs(@"4M"), @"label": Runs(@"Likes") } } } } ] } },
                @{ @"expandableVideoDescriptionBodyRenderer": @{
                    @"attributedDescriptionBodyText": @{ @"content": @"Official video" } } } ] } } } } ] };
}

RT_TEST(test_next_reads_details) {
    RTNextInfo *info = RTParseNext(Answer());
    RT_EQUAL(info.title, @"Instant Crush");
    RT_EQUAL(info.viewsText, @"904,270,011 views");
    RT_EQUAL(info.publishDateText, @"Dec 6, 2013");
    RT_EQUAL(info.likesText, @"4M");
    RT_EQUAL(info.descriptionText, @"Official video");
}

RT_TEST(test_next_reads_channel) {
    RTChannel *channel = RTParseNext(Answer()).channel;
    RT_EQUAL(channel.channelId, @"UC_kRDKYrUlrbtrSiyu5Tflg");
    RT_EQUAL(channel.title, @"Daft Punk");
    RT_EQUAL(channel.subscribersText, @"7.2M subscribers");
    RT_EQUAL(channel.avatarURL.absoluteString, @"https://yt3.ggpht.com/s88");
}

RT_TEST(test_next_related_has_only_videos) {
    RTPage *related = RTParseNext(Answer()).related;
    RT_EQUAL([related.items valueForKey:@"videoId"], @[ @"5NV6Rdv1a3I" ]);
    RT_EQUAL(related.continuation, @"NEXT");
}

RT_TEST(test_next_of_empty_answer_has_no_details) {
    RTNextInfo *info = RTParseNext(@{});
    RT_EXPECT(info.title == nil);
    RT_EXPECT(info.channel == nil);
    RT_EQUAL_INT(info.related.items.count, 0);
}

RT_TEST(test_next_title_falls_back_to_slim_title) {
    NSMutableDictionary *answer = [Answer() mutableCopy];
    [answer removeObjectForKey:@"engagementPanels"];
    RT_EQUAL(RTParseNext(answer).title, @"Instant Crush (slim)");
}
