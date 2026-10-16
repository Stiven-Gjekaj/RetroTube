// Makes short English texts for the lists: counts and ages.

#import <Foundation/Foundation.h>

// 950 gives "950", 44811 gives "44K", 1234567 gives "1.2M", 2700000000 gives "2.7B".
NSString *RTShortCount(long long count);

// The time from date to now, as YouTube writes it: "5 minutes ago",
// "1 day ago", "3 weeks ago", "2 years ago". A date after now gives "now".
NSString *RTAgoText(NSDate *date, NSDate *now);
