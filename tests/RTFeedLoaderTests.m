#import "RTTest.h"
#import "RTFeedLoader.h"
#import "RTModels.h"

RT_TEST(test_feeds_of_no_channels_are_empty) {
    __block NSArray *result = nil;
    BOOL done = NO;
    BOOL *donePointer = &done;
    RTLoadFeeds(@[], ^(NSArray *videos, NSUInteger failures) {
        result = videos;
        *donePointer = YES;
    });
    RT_EXPECT(RTTestWait(&done, 5));
    RT_EQUAL_INT(result.count, 0);
}

RT_TEST(test_live_feeds_join_channels_newest_first) {
    RT_LIVE_ONLY();
    __block NSArray *result = nil;
    __block NSUInteger failed = 99;
    BOOL done = NO;
    BOOL *donePointer = &done;
    // Two real channels and one that does not exist.
    RTLoadFeeds(@[ @"UCuAXFkgsw1L7xaCfnd5JJOw", @"UC_kRDKYrUlrbtrSiyu5Tflg", @"UCxxxxxxxxxxxxxxxxxxxxxx" ],
                ^(NSArray *videos, NSUInteger failures) {
        result = videos;
        failed = failures;
        *donePointer = YES;
    });
    RT_EXPECT(RTTestWait(&done, 40));
    RT_EQUAL_INT(failed, 1);
    RT_EQUAL_INT(result.count, 30);
    NSSet *channels = [NSSet setWithArray:[result valueForKey:@"channelId"]];
    RT_EQUAL_INT(channels.count, 2);
    for (NSUInteger i = 1; i < result.count; i++) {
        RT_EXPECT([[result[i - 1] publishedDate] compare:[result[i] publishedDate]] != NSOrderedAscending);
    }
}
