#import "RTFeedLoader.h"
#import "RTFeed.h"
#import "RTModels.h"

const NSUInteger RTFeedLimit = 150;

void RTLoadFeeds(NSArray *channelIds, void (^handler)(NSArray *videos, NSUInteger failures)) {
    if (!channelIds.count) {
        dispatch_async(dispatch_get_main_queue(), ^{ handler(@[], 0); });
        return;
    }
    NSOperationQueue *queue = [NSOperationQueue new];
    queue.maxConcurrentOperationCount = 4;
    NSMutableArray *videos = [NSMutableArray array];
    __block NSUInteger left = channelIds.count, failures = 0;
    NSDate *now = [NSDate date];
    for (NSString *channelId in channelIds) {
        [queue addOperationWithBlock:^{
            NSURLRequest *request = [NSURLRequest requestWithURL:RTFeedURL(channelId)
                                                     cachePolicy:NSURLRequestReloadIgnoringLocalCacheData
                                                 timeoutInterval:20];
            NSHTTPURLResponse *response = nil;
            NSData *data = [NSURLConnection sendSynchronousRequest:request returningResponse:(NSURLResponse **)&response
                                                             error:NULL];
            NSArray *entries = response.statusCode == 200 ? RTParseFeed(data, now) : nil;
            @synchronized (videos) {
                if (entries) [videos addObjectsFromArray:entries];
                else failures++;
                if (--left > 0) return;
            }
            // The last feed is in. Sort, cut, and give the result.
            [videos sortUsingComparator:^NSComparisonResult(RTVideo *a, RTVideo *b) {
                return [b.publishedDate ?: [NSDate distantPast] compare:a.publishedDate ?: [NSDate distantPast]];
            }];
            NSArray *result = [videos subarrayWithRange:NSMakeRange(0, MIN(videos.count, RTFeedLimit))];
            NSUInteger failed = failures;
            dispatch_async(dispatch_get_main_queue(), ^{ handler(result, failed); });
        }];
    }
}
