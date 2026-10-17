#import "RTTest.h"
#import "RTFeedCache.h"
#import "RTModels.h"

static NSString *TempPath(void) {
    NSString *name = [NSString stringWithFormat:@"rtfeed-%@/feed.archive", [[NSProcessInfo processInfo] globallyUniqueString]];
    return [NSTemporaryDirectory() stringByAppendingPathComponent:name];
}

static RTVideo *Video(NSString *videoId, NSDate *published) {
    RTVideo *video = [RTVideo new];
    video.videoId = videoId;
    video.publishedDate = published;
    video.publishedText = @"old text";
    return video;
}

RT_TEST(test_feed_cache_gives_saved_feed_with_new_ages) {
    NSString *path = TempPath();
    NSDate *published = [NSDate dateWithTimeIntervalSince1970:1000000];
    RTSaveFeed(path, @[ @"UC2", @"UC1" ], @[ Video(@"a", published), Video(@"b", nil) ]);
    NSArray *videos = RTLoadFeed(path, @[ @"UC1", @"UC2" ], [published dateByAddingTimeInterval:3 * 86400]);
    RT_EQUAL([videos valueForKey:@"videoId"], (@[ @"a", @"b" ]));
    RT_EQUAL([videos[0] publishedText], @"3 days ago");
    RT_EQUAL([videos[1] publishedText], @"old text");
}

RT_TEST(test_feed_cache_refuses_other_subscriptions) {
    NSString *path = TempPath();
    RTSaveFeed(path, @[ @"UC1" ], @[ Video(@"a", nil) ]);
    RT_EXPECT(RTLoadFeed(path, @[ @"UC1", @"UC2" ], [NSDate date]) == nil);
    RT_EXPECT(RTLoadFeed(path, @[], [NSDate date]) == nil);
}

RT_TEST(test_feed_cache_with_no_file_is_nil) {
    RT_EXPECT(RTLoadFeed(TempPath(), @[ @"UC1" ], [NSDate date]) == nil);
}
