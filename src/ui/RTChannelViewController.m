#import "RTChannelViewController.h"
#import "RTInnerTube.h"
#import "RTParse.h"
#import "RTStore.h"

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

- (void)viewDidLoad {
    [super viewDidLoad];
    [self updateSubscribeButton];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(updateSubscribeButton)
                                                 name:RTStoreDidChangeNotification object:nil];
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)updateSubscribeButton {
    BOOL subscribed = [[RTStore shared] isSubscribed:self.channel.channelId];
    UIBarButtonItem *button = [[UIBarButtonItem alloc] initWithTitle:subscribed ? @"Subscribed" : @"Subscribe"
                                                               style:subscribed ? UIBarButtonItemStyleDone
                                                                                : UIBarButtonItemStyleBordered
                                                              target:self action:@selector(toggleSubscription)];
    self.navigationItem.rightBarButtonItem = button;
}

- (void)toggleSubscription {
    RTStore *store = [RTStore shared];
    if ([store isSubscribed:self.channel.channelId]) [store unsubscribe:self.channel.channelId];
    else [store subscribe:self.channel];
}

// The first page also gives the name and the picture of the channel.
- (id)resultFromJSON:(NSDictionary *)json {
    RTChannel *header = RTParseChannelHeader(json);
    RTPage *page = RTParsePage(json);
    return header ? @{ @"page": page, @"channel": header } : @{ @"page": page };
}

- (RTPage *)pageFromResult:(NSDictionary *)result {
    RTChannel *header = result[@"channel"];
    if (header) {
        self.channel.title = header.title ?: self.channel.title;
        self.channel.handle = header.handle ?: self.channel.handle;
        self.channel.subscribersText = header.subscribersText ?: self.channel.subscribersText;
        self.channel.avatarURL = header.avatarURL ?: self.channel.avatarURL;
        self.title = self.channel.title;
        // Keep the stored subscription up to date.
        if ([[RTStore shared] isSubscribed:self.channel.channelId]) [[RTStore shared] subscribe:self.channel];
    }
    return result[@"page"];
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
