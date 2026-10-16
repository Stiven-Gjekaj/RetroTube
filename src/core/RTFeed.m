#import "RTFeed.h"
#import "RTText.h"

NSURL *RTFeedURL(NSString *channelId) {
    NSString *url = [NSString stringWithFormat:@"https://www.youtube.com/feeds/videos.xml?channel_id=%@", channelId];
    return [NSURL URLWithString:url];
}

NSDate *RTParseISODate(NSString *text) {
    static NSDateFormatter *formatter;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        formatter = [NSDateFormatter new];
        formatter.locale = [[NSLocale alloc] initWithLocaleIdentifier:@"en_US_POSIX"];
        formatter.dateFormat = @"yyyy-MM-dd'T'HH:mm:ssZ";
    });
    if (text.length < 20) return nil;
    // iOS 6 reads the zone "+0000" with "Z". Remove the colon of "+00:00".
    NSString *clean = text;
    if ([clean hasSuffix:@"Z"]) {
        clean = [[clean substringToIndex:clean.length - 1] stringByAppendingString:@"+0000"];
    } else if (clean.length >= 6 && [clean characterAtIndex:clean.length - 3] == ':') {
        clean = [clean stringByReplacingCharactersInRange:NSMakeRange(clean.length - 3, 1) withString:@""];
    }
    @synchronized (formatter) {
        return [formatter dateFromString:clean];
    }
}

@interface RTFeedReader : NSObject <NSXMLParserDelegate>
@property (nonatomic, strong) NSMutableArray *videos;
@property (nonatomic, strong) RTVideo *current;
@property (nonatomic, strong) NSMutableString *text;
@property (nonatomic, copy) NSString *channelName;  // The name of the feed, for entries with no author
@property (nonatomic) BOOL inAuthor;
@property (nonatomic) BOOL isFeed;
@property (nonatomic, strong) NSDate *now;
@end

@implementation RTFeedReader

- (void)parser:(NSXMLParser *)parser didStartElement:(NSString *)name namespaceURI:(NSString *)namespaceURI
 qualifiedName:(NSString *)qualifiedName attributes:(NSDictionary *)attributes {
    self.text = [NSMutableString string];
    if ([name isEqualToString:@"feed"]) {
        self.isFeed = YES;
    } else if ([name isEqualToString:@"entry"]) {
        self.current = [RTVideo new];
    } else if ([name isEqualToString:@"author"]) {
        self.inAuthor = YES;
    } else if (self.current && [qualifiedName isEqualToString:@"media:statistics"]) {
        long long views = [attributes[@"views"] longLongValue];
        if (attributes[@"views"]) self.current.viewsText = [RTShortCount(views) stringByAppendingString:@" views"];
    }
}

- (void)parser:(NSXMLParser *)parser foundCharacters:(NSString *)string {
    [self.text appendString:string];
}

- (void)parser:(NSXMLParser *)parser didEndElement:(NSString *)name namespaceURI:(NSString *)namespaceURI
 qualifiedName:(NSString *)qualifiedName {
    NSString *text = [self.text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    RTVideo *video = self.current;
    if ([name isEqualToString:@"author"]) {
        self.inAuthor = NO;
    } else if ([name isEqualToString:@"name"] && self.inAuthor) {
        if (video) video.channelName = text;
        else self.channelName = text;
    } else if (!video) {
        // The fields of the feed itself.
    } else if ([qualifiedName isEqualToString:@"yt:videoId"]) {
        video.videoId = text;
        NSString *thumb = [NSString stringWithFormat:@"https://i.ytimg.com/vi/%@/mqdefault.jpg", text];
        video.thumbnailURL = [NSURL URLWithString:thumb];
    } else if ([qualifiedName isEqualToString:@"yt:channelId"]) {
        video.channelId = [text hasPrefix:@"UC"] ? text : [@"UC" stringByAppendingString:text];
    } else if ([name isEqualToString:@"title"] && ![qualifiedName hasPrefix:@"media:"]) {
        video.title = text;
    } else if ([name isEqualToString:@"published"]) {
        video.publishedDate = RTParseISODate(text);
        if (video.publishedDate) video.publishedText = RTAgoText(video.publishedDate, self.now);
    } else if ([name isEqualToString:@"entry"]) {
        if (!video.channelName) video.channelName = self.channelName;
        if (video.videoId.length) [self.videos addObject:video];
        self.current = nil;
    }
}

@end

NSArray *RTParseFeed(NSData *data, NSDate *now) {
    if (!data) return nil;
    NSXMLParser *parser = [[NSXMLParser alloc] initWithData:data];
    parser.shouldProcessNamespaces = YES;
    parser.shouldReportNamespacePrefixes = NO;
    RTFeedReader *reader = [RTFeedReader new];
    reader.videos = [NSMutableArray array];
    reader.now = now;
    parser.delegate = reader;
    if (![parser parse] || !reader.isFeed) return nil;
    return [reader.videos sortedArrayUsingComparator:^NSComparisonResult(RTVideo *a, RTVideo *b) {
        return [b.publishedDate ?: [NSDate distantPast] compare:a.publishedDate ?: [NSDate distantPast]];
    }];
}
