#import "RTFeedCache.h"
#import "RTModels.h"
#import "RTText.h"

NSString *RTFeedCachePath(void) {
    NSString *caches = NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES)[0];
    return [caches stringByAppendingPathComponent:@"RetroTube/feed.archive"];
}

void RTSaveFeed(NSString *path, NSArray *channelIds, NSArray *videos) {
    if (!path || !channelIds || !videos) return;
    [[NSFileManager defaultManager] createDirectoryAtPath:[path stringByDeletingLastPathComponent]
                              withIntermediateDirectories:YES attributes:nil error:NULL];
    [NSKeyedArchiver archiveRootObject:@{ @"channels": [channelIds sortedArrayUsingSelector:@selector(compare:)],
                                          @"videos": videos }
                                toFile:path];
}

NSArray *RTLoadFeed(NSString *path, NSArray *channelIds, NSDate *now) {
    id saved = nil;
    @try {
        saved = [NSKeyedUnarchiver unarchiveObjectWithFile:path];
    } @catch (NSException *exception) {
        saved = nil;
    }
    if (![saved isKindOfClass:[NSDictionary class]]) return nil;
    NSArray *sorted = [channelIds sortedArrayUsingSelector:@selector(compare:)];
    if (![saved[@"channels"] isEqual:sorted]) return nil;
    NSMutableArray *videos = [NSMutableArray array];
    for (id item in saved[@"videos"]) {
        if (![item isKindOfClass:[RTVideo class]]) continue;
        RTVideo *video = item;
        if (video.publishedDate) video.publishedText = RTAgoText(video.publishedDate, now);
        [videos addObject:video];
    }
    return videos;
}
