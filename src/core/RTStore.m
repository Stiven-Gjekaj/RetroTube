#import "RTStore.h"

NSString *const RTStoreDidChangeNotification = @"RTStoreDidChange";
const NSUInteger RTHistoryLimit = 200;

@interface RTStore ()
@property (nonatomic, copy) NSString *directory;
@property (nonatomic, strong) NSMutableArray *subscriptionList;
@property (nonatomic, strong) NSMutableArray *historyList;
@end

@implementation RTStore

+ (instancetype)shared {
    static RTStore *shared;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        NSString *support = NSSearchPathForDirectoriesInDomains(NSApplicationSupportDirectory, NSUserDomainMask, YES)[0];
        shared = [[RTStore alloc] initWithDirectory:[support stringByAppendingPathComponent:@"RetroTube"]];
    });
    return shared;
}

- (instancetype)initWithDirectory:(NSString *)directory {
    if ((self = [super init])) {
        _directory = [directory copy];
        [[NSFileManager defaultManager] createDirectoryAtPath:directory withIntermediateDirectories:YES attributes:nil
                                                        error:NULL];
        _subscriptionList = [self load:@"subscriptions" class:[RTChannel class]];
        _historyList = [self load:@"history" class:[RTVideo class]];
    }
    return self;
}

- (NSString *)pathOf:(NSString *)name {
    return [[self.directory stringByAppendingPathComponent:name] stringByAppendingPathExtension:@"archive"];
}

// Reads a list. A file that is missing or damaged gives an empty list.
- (NSMutableArray *)load:(NSString *)name class:(Class)itemClass {
    NSMutableArray *items = [NSMutableArray array];
    id archived = nil;
    @try {
        archived = [NSKeyedUnarchiver unarchiveObjectWithFile:[self pathOf:name]];
    } @catch (NSException *exception) {
        archived = nil;
    }
    if ([archived isKindOfClass:[NSArray class]]) {
        for (id item in archived) {
            if ([item isKindOfClass:itemClass]) [items addObject:item];
        }
    }
    return items;
}

- (void)save:(NSString *)name items:(NSArray *)items {
    [NSKeyedArchiver archiveRootObject:items toFile:[self pathOf:name]];
    [[NSNotificationCenter defaultCenter] postNotificationName:RTStoreDidChangeNotification object:self];
}

- (NSArray *)subscriptions {
    return [self.subscriptionList copy];
}

- (BOOL)isSubscribed:(NSString *)channelId {
    for (RTChannel *channel in self.subscriptionList) {
        if ([channel.channelId isEqualToString:channelId]) return YES;
    }
    return NO;
}

- (void)subscribe:(RTChannel *)channel {
    if (!channel.channelId.length) return;
    [self.subscriptionList removeObject:channel];  // Equal by channel ID
    [self.subscriptionList addObject:channel];
    [self.subscriptionList sortUsingComparator:^NSComparisonResult(RTChannel *a, RTChannel *b) {
        return [a.title ?: a.channelId caseInsensitiveCompare:b.title ?: b.channelId];
    }];
    [self save:@"subscriptions" items:self.subscriptionList];
}

- (void)unsubscribe:(NSString *)channelId {
    RTChannel *key = [RTChannel new];
    key.channelId = channelId;
    if (![self.subscriptionList containsObject:key]) return;
    [self.subscriptionList removeObject:key];
    [self save:@"subscriptions" items:self.subscriptionList];
}

- (NSArray *)history {
    return [self.historyList copy];
}

- (void)addToHistory:(RTVideo *)video {
    if (!video.videoId.length) return;
    [self.historyList removeObject:video];  // Equal by video ID
    [self.historyList insertObject:video atIndex:0];
    while (self.historyList.count > RTHistoryLimit) [self.historyList removeLastObject];
    [self save:@"history" items:self.historyList];
}

- (void)removeFromHistory:(NSString *)videoId {
    RTVideo *key = [RTVideo new];
    key.videoId = videoId;
    if (![self.historyList containsObject:key]) return;
    [self.historyList removeObject:key];
    [self save:@"history" items:self.historyList];
}

- (void)clearHistory {
    [self.historyList removeAllObjects];
    [self save:@"history" items:self.historyList];
}

@end
