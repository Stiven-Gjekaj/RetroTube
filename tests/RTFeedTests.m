#import "RTTest.h"
#import "RTFeed.h"

static NSString *Entry(NSString *videoId, NSString *title, NSString *published, NSString *views) {
    return [NSString stringWithFormat:
        @"<entry><id>yt:video:%1$@</id><yt:videoId>%1$@</yt:videoId><yt:channelId>UCabc</yt:channelId>"
        @"<title>%2$@</title><author><name>Maker</name></author><published>%3$@</published>"
        @"<media:group><media:title>media %2$@</media:title>"
        @"<media:community><media:statistics views=\"%4$@\"/></media:community></media:group></entry>",
        videoId, title, published, views];
}

static NSData *Feed(NSArray *entries) {
    NSString *xml = [NSString stringWithFormat:
        @"<?xml version=\"1.0\" encoding=\"UTF-8\"?><feed xmlns:yt=\"http://www.youtube.com/xml/schemas/2015\" "
        @"xmlns:media=\"http://search.yahoo.com/mrss/\" xmlns=\"http://www.w3.org/2005/Atom\">"
        @"<title>Channel</title><author><name>Feed Maker</name></author>%@</feed>",
        [entries componentsJoinedByString:@""]];
    return [xml dataUsingEncoding:NSUTF8StringEncoding];
}

RT_TEST(test_feed_reads_entries_newest_first) {
    NSDate *now = RTParseISODate(@"2026-10-16T12:00:00+00:00");
    NSArray *videos = RTParseFeed(Feed(@[ Entry(@"old00000000", @"Old", @"2026-09-01T10:00:00+00:00", @"950"),
                                          Entry(@"new00000000", @"New &amp; fresh", @"2026-10-15T12:00:00+00:00", @"44811") ]),
                                  now);
    RT_EQUAL([videos valueForKey:@"videoId"], (@[ @"new00000000", @"old00000000" ]));
    RTVideo *first = videos[0];
    RT_EQUAL(first.title, @"New & fresh");
    RT_EQUAL(first.channelName, @"Maker");
    RT_EQUAL(first.channelId, @"UCabc");
    RT_EQUAL(first.viewsText, @"44K views");
    RT_EQUAL(first.publishedText, @"1 day ago");
    RT_EQUAL(first.thumbnailURL.absoluteString, @"https://i.ytimg.com/vi/new00000000/mqdefault.jpg");
    RT_EXPECT(!first.isLive);
    RT_EXPECT(first.lengthText == nil);
}

RT_TEST(test_feed_adds_uc_to_short_channel_id) {
    NSString *entry = [Entry(@"a0000000000", @"A", @"2026-10-15T12:00:00+00:00", @"1")
        stringByReplacingOccurrencesOfString:@"<yt:channelId>UCabc</yt:channelId>"
                                  withString:@"<yt:channelId>xyz</yt:channelId>"];
    RTVideo *video = RTParseFeed(Feed(@[ entry ]), [NSDate date])[0];
    RT_EQUAL(video.channelId, @"UCxyz");
}

RT_TEST(test_feed_of_other_data_is_nil) {
    RT_EXPECT(RTParseFeed([@"<html><body>no</body></html>" dataUsingEncoding:NSUTF8StringEncoding], [NSDate date]) == nil);
    RT_EXPECT(RTParseFeed([@"not xml <" dataUsingEncoding:NSUTF8StringEncoding], [NSDate date]) == nil);
    RT_EXPECT(RTParseFeed(nil, [NSDate date]) == nil);
}

RT_TEST(test_feed_with_no_entries_is_empty) {
    NSArray *videos = RTParseFeed(Feed(@[]), [NSDate date]);
    RT_EXPECT(videos != nil);
    RT_EQUAL_INT(videos.count, 0);
}

RT_TEST(test_iso_date_forms) {
    NSDate *utc = RTParseISODate(@"2026-09-20T08:52:27+00:00");
    RT_EQUAL_INT([utc timeIntervalSince1970], 1789894347);
    RT_EQUAL(RTParseISODate(@"2026-09-20T08:52:27Z"), utc);
    RT_EQUAL(RTParseISODate(@"2026-09-20T10:52:27+02:00"), utc);
    RT_EXPECT(RTParseISODate(@"yesterday") == nil);
}
