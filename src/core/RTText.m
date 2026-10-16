#import "RTText.h"

NSString *RTShortCount(long long count) {
    if (count < 1000) return [NSString stringWithFormat:@"%lld", count];
    const char *units[] = { "K", "M", "B" };
    double value = (double)count;
    int unit = -1;
    while (value >= 1000 && unit < 2) {
        value /= 1000;
        unit++;
    }
    // One decimal under 10, as YouTube does: "1.2M", but "44K".
    if (value < 10) {
        double rounded = floor(value * 10) / 10;
        if (rounded == floor(rounded)) return [NSString stringWithFormat:@"%.0f%s", rounded, units[unit]];
        return [NSString stringWithFormat:@"%.1f%s", rounded, units[unit]];
    }
    return [NSString stringWithFormat:@"%.0f%s", floor(value), units[unit]];
}

NSString *RTAgoText(NSDate *date, NSDate *now) {
    NSTimeInterval seconds = [now timeIntervalSinceDate:date];
    if (seconds < 60) return @"now";
    struct { double size; const char *name; } steps[] = {
        { 365 * 86400, "year" }, { 30 * 86400, "month" }, { 7 * 86400, "week" },
        { 86400, "day" }, { 3600, "hour" }, { 60, "minute" },
    };
    for (size_t i = 0; i < sizeof(steps) / sizeof(steps[0]); i++) {
        long count = (long)(seconds / steps[i].size);
        if (count >= 1) {
            return [NSString stringWithFormat:@"%ld %s%s ago", count, steps[i].name, count == 1 ? "" : "s"];
        }
    }
    return @"now";
}
