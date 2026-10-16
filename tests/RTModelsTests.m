#import "RTTest.h"
#import "RTModels.h"

RT_TEST(test_video_survives_archiving) {
    RTVideo *video = [RTVideo new];
    video.videoId = @"abc";
    video.title = @"A title";
    video.thumbnailURL = [NSURL URLWithString:@"https://i.ytimg.com/vi/abc/mqdefault.jpg"];
    RTVideo *copy = [NSKeyedUnarchiver unarchiveObjectWithData:[NSKeyedArchiver archivedDataWithRootObject:video]];
    RT_EQUAL(copy.videoId, @"abc");
    RT_EQUAL(copy.title, @"A title");
    RT_EQUAL(copy.thumbnailURL, video.thumbnailURL);
    RT_EXPECT(copy.channelName == nil);
    RT_EXPECT(!copy.isLive);
}

RT_TEST(test_video_keeps_date_and_live_flag) {
    RTVideo *video = [RTVideo new];
    video.videoId = @"abc";
    video.publishedDate = [NSDate dateWithTimeIntervalSince1970:1000];
    video.isLive = YES;
    RTVideo *copy = [NSKeyedUnarchiver unarchiveObjectWithData:[NSKeyedArchiver archivedDataWithRootObject:video]];
    RT_EQUAL(copy.publishedDate, video.publishedDate);
    RT_EXPECT(copy.isLive);
}

RT_TEST(test_channel_survives_archiving) {
    RTChannel *channel = [RTChannel new];
    channel.channelId = @"UC1";
    channel.handle = @"@one";
    RTChannel *copy = [NSKeyedUnarchiver unarchiveObjectWithData:[NSKeyedArchiver archivedDataWithRootObject:channel]];
    RT_EQUAL(copy.channelId, @"UC1");
    RT_EQUAL(copy.handle, @"@one");
}

RT_TEST(test_items_are_equal_by_id) {
    RTVideo *a = [RTVideo new], *b = [RTVideo new];
    a.videoId = b.videoId = @"same";
    a.title = @"one";
    b.title = @"two";
    RT_EQUAL(a, b);
    RT_EQUAL_INT(([[NSSet setWithObjects:a, b, nil] count]), 1);
}
