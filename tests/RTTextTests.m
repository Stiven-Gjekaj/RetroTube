#import "RTTest.h"
#import "RTText.h"

RT_TEST(test_short_count) {
    RT_EQUAL(RTShortCount(0), @"0");
    RT_EQUAL(RTShortCount(950), @"950");
    RT_EQUAL(RTShortCount(1000), @"1K");
    RT_EQUAL(RTShortCount(1250), @"1.2K");
    RT_EQUAL(RTShortCount(44811), @"44K");
    RT_EQUAL(RTShortCount(999999), @"999K");
    RT_EQUAL(RTShortCount(1234567), @"1.2M");
    RT_EQUAL(RTShortCount(904270011), @"904M");
    RT_EQUAL(RTShortCount(2700000000LL), @"2.7B");
    RT_EQUAL(RTShortCount(15000000000000LL), @"15000B");
}

RT_TEST(test_ago_text) {
    NSDate *now = [NSDate dateWithTimeIntervalSince1970:2000000000];
    RT_EQUAL(RTAgoText([now dateByAddingTimeInterval:-30], now), @"now");
    RT_EQUAL(RTAgoText([now dateByAddingTimeInterval:60], now), @"now");
    RT_EQUAL(RTAgoText([now dateByAddingTimeInterval:-60], now), @"1 minute ago");
    RT_EQUAL(RTAgoText([now dateByAddingTimeInterval:-5 * 60], now), @"5 minutes ago");
    RT_EQUAL(RTAgoText([now dateByAddingTimeInterval:-3600 * 23], now), @"23 hours ago");
    RT_EQUAL(RTAgoText([now dateByAddingTimeInterval:-86400], now), @"1 day ago");
    RT_EQUAL(RTAgoText([now dateByAddingTimeInterval:-86400 * 15], now), @"2 weeks ago");
    RT_EQUAL(RTAgoText([now dateByAddingTimeInterval:-86400 * 45], now), @"1 month ago");
    RT_EQUAL(RTAgoText([now dateByAddingTimeInterval:-86400 * 365 * 3], now), @"3 years ago");
}
