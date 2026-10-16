#import "RTTest.h"
#import "RTStore.h"

static NSString *TempDirectory(void) {
    NSString *name = [NSString stringWithFormat:@"rtstore-%@", [[NSProcessInfo processInfo] globallyUniqueString]];
    return [NSTemporaryDirectory() stringByAppendingPathComponent:name];
}

static RTChannel *Channel(NSString *channelId, NSString *title) {
    RTChannel *channel = [RTChannel new];
    channel.channelId = channelId;
    channel.title = title;
    return channel;
}

static RTVideo *Video(NSString *videoId) {
    RTVideo *video = [RTVideo new];
    video.videoId = videoId;
    video.title = [@"Title " stringByAppendingString:videoId];
    return video;
}

RT_TEST(test_store_starts_empty) {
    RTStore *store = [[RTStore alloc] initWithDirectory:TempDirectory()];
    RT_EQUAL_INT(store.subscriptions.count, 0);
    RT_EQUAL_INT(store.history.count, 0);
}

RT_TEST(test_store_sorts_subscriptions_and_keeps_them) {
    NSString *directory = TempDirectory();
    RTStore *store = [[RTStore alloc] initWithDirectory:directory];
    [store subscribe:Channel(@"UC2", @"beta")];
    [store subscribe:Channel(@"UC1", @"Alpha")];
    [store subscribe:Channel(@"UC3", @"gamma")];
    RT_EQUAL([store.subscriptions valueForKey:@"title"], (@[ @"Alpha", @"beta", @"gamma" ]));
    RT_EXPECT([store isSubscribed:@"UC2"]);
    RT_EXPECT(![store isSubscribed:@"UC9"]);

    RTStore *again = [[RTStore alloc] initWithDirectory:directory];
    RT_EQUAL([again.subscriptions valueForKey:@"channelId"], (@[ @"UC1", @"UC2", @"UC3" ]));
}

RT_TEST(test_store_subscribe_again_updates_channel) {
    RTStore *store = [[RTStore alloc] initWithDirectory:TempDirectory()];
    [store subscribe:Channel(@"UC1", @"Old name")];
    [store subscribe:Channel(@"UC1", @"New name")];
    RT_EQUAL([store.subscriptions valueForKey:@"title"], @[ @"New name" ]);
}

RT_TEST(test_store_unsubscribe) {
    NSString *directory = TempDirectory();
    RTStore *store = [[RTStore alloc] initWithDirectory:directory];
    [store subscribe:Channel(@"UC1", @"One")];
    [store subscribe:Channel(@"UC2", @"Two")];
    [store unsubscribe:@"UC1"];
    [store unsubscribe:@"UC9"];
    RT_EQUAL([[[RTStore alloc] initWithDirectory:directory].subscriptions valueForKey:@"channelId"], @[ @"UC2" ]);
}

RT_TEST(test_store_history_moves_video_to_top) {
    NSString *directory = TempDirectory();
    RTStore *store = [[RTStore alloc] initWithDirectory:directory];
    [store addToHistory:Video(@"a")];
    [store addToHistory:Video(@"b")];
    [store addToHistory:Video(@"a")];
    RT_EQUAL([store.history valueForKey:@"videoId"], (@[ @"a", @"b" ]));
    RT_EQUAL([[[RTStore alloc] initWithDirectory:directory].history valueForKey:@"videoId"], (@[ @"a", @"b" ]));
}

RT_TEST(test_store_history_has_a_limit) {
    RTStore *store = [[RTStore alloc] initWithDirectory:TempDirectory()];
    for (NSUInteger i = 0; i < RTHistoryLimit + 5; i++) [store addToHistory:Video([NSString stringWithFormat:@"v%lu", (unsigned long)i])];
    RT_EQUAL_INT(store.history.count, RTHistoryLimit);
    RT_EQUAL([store.history[0] videoId], ([NSString stringWithFormat:@"v%lu", (unsigned long)(RTHistoryLimit + 4)]));
    RT_EQUAL([store.history.lastObject videoId], @"v5");
}

RT_TEST(test_store_remove_and_clear_history) {
    NSString *directory = TempDirectory();
    RTStore *store = [[RTStore alloc] initWithDirectory:directory];
    [store addToHistory:Video(@"a")];
    [store addToHistory:Video(@"b")];
    [store removeFromHistory:@"a"];
    RT_EQUAL([store.history valueForKey:@"videoId"], @[ @"b" ]);
    [store clearHistory];
    RT_EQUAL_INT([[RTStore alloc] initWithDirectory:directory].history.count, 0);
}

RT_TEST(test_store_reads_damaged_file_as_empty) {
    NSString *directory = TempDirectory();
    [[NSFileManager defaultManager] createDirectoryAtPath:directory withIntermediateDirectories:YES attributes:nil error:NULL];
    [[@"not an archive" dataUsingEncoding:NSUTF8StringEncoding]
        writeToFile:[directory stringByAppendingPathComponent:@"history.archive"] atomically:YES];
    RT_EQUAL_INT([[RTStore alloc] initWithDirectory:directory].history.count, 0);
}

RT_TEST(test_store_posts_change) {
    RTStore *store = [[RTStore alloc] initWithDirectory:TempDirectory()];
    __block int count = 0;
    id observer = [[NSNotificationCenter defaultCenter] addObserverForName:RTStoreDidChangeNotification object:store
                                                                     queue:nil usingBlock:^(NSNotification *n) { count++; }];
    [store subscribe:Channel(@"UC1", @"One")];
    [store addToHistory:Video(@"a")];
    [[NSNotificationCenter defaultCenter] removeObserver:observer];
    RT_EQUAL_INT(count, 2);
}
