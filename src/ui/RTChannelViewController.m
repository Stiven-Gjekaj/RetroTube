#import "RTChannelViewController.h"
#import "RTInnerTube.h"

@interface RTChannelViewController ()
@property (nonatomic, strong) RTChannel *channel;
@end

@implementation RTChannelViewController

- (instancetype)initWithChannel:(RTChannel *)channel {
    if ((self = [super init])) {
        _channel = channel;
        self.title = channel.title ?: @"Channel";
        self.emptyText = @"This channel has no videos.";
        self.continuationEndpoint = @"browse";
        self.firstRequest = [[RTInnerTube shared] browseRequest:channel.channelId params:RTBrowseParamsChannelVideos];
    }
    return self;
}

// The videos tab does not name the channel in each item. Add it.
- (NSArray *)itemsToAdd:(RTPage *)page {
    NSMutableArray *videos = [NSMutableArray array];
    for (id item in page.items) {
        if (![item isKindOfClass:[RTVideo class]]) continue;
        RTVideo *video = item;
        if (!video.channelName) video.channelName = self.channel.title;
        if (!video.channelId) video.channelId = self.channel.channelId;
        [videos addObject:video];
    }
    return videos;
}

@end
