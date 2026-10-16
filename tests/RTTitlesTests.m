#import "RTTest.h"
#import "RTTitles.h"

RT_TEST(test_oembed_url_has_encoded_watch_url) {
    RT_EQUAL(RTOEmbedURL(@"DJnUfRX5Hf4").absoluteString,
             @"https://www.youtube.com/oembed?format=json&url=https%3A%2F%2Fwww.youtube.com%2Fwatch%3Fv%3DDJnUfRX5Hf4");
}

RT_TEST(test_oembed_title) {
    NSData *data = [@"{\"title\":\"NEW ANIMATRONICS!!!\",\"author_name\":\"VenturianTale\"}"
        dataUsingEncoding:NSUTF8StringEncoding];
    RT_EQUAL(RTParseOEmbedTitle(data), @"NEW ANIMATRONICS!!!");
    RT_EXPECT(RTParseOEmbedTitle([@"Not Found" dataUsingEncoding:NSUTF8StringEncoding]) == nil);
    RT_EXPECT(RTParseOEmbedTitle([@"{\"title\":7}" dataUsingEncoding:NSUTF8StringEncoding]) == nil);
    RT_EXPECT(RTParseOEmbedTitle(nil) == nil);
}

RT_TEST(test_live_original_title_replaces_translation) {
    RT_LIVE_ONLY();
    // YouTube search gave this video an Italian title on 2026-10-16:
    // "NUOVI ANIMATRONICI!!! Mod di Five Nights at Freddy's 2 per Gmod".
    __block NSDictionary *result = nil;
    BOOL done = NO;
    BOOL *donePointer = &done;
    RTLoadOriginalTitles(@[ @"DJnUfRX5Hf4", @"xxxxxxxxxxx" ], ^(NSDictionary *titles) {
        result = titles;
        *donePointer = YES;
    });
    RT_EXPECT(RTTestWait(&done, 30));
    RT_EQUAL(result[@"DJnUfRX5Hf4"], @"NEW ANIMATRONICS!!! Gmod Five Nights At Freddy's 2 Mod (Garry's Mod)");
    RT_EXPECT(result[@"xxxxxxxxxxx"] == nil);
}
