#import "RTPopularViewController.h"
#import "RTInnerTube.h"

// The user default with the index of the last topic.
static NSString *const RTPopularTopicKey = @"RTPopularTopic";

@interface RTPopularViewController ()
@property (nonatomic, strong) UISegmentedControl *topics;
@end

@implementation RTPopularViewController

+ (NSArray *)topicNames {
    return @[ @"Music", @"Gaming", @"Sports", @"News" ];
}

+ (NSArray *)topicChannelIds {
    return @[ @"UC-9-kyTW8ZkZNDHQJ6FgpwQ", @"UCOpNcN46UbXVtpKMrmU4Abg", @"UCEgdi0XIXXZ-qJOFPf4JSKw",
              @"UCYfdidRxbB8Qhf0Nx7ioOYw" ];
}

- (instancetype)init {
    if ((self = [super init])) {
        self.title = @"Popular";
        self.tabBarItem.image = [UIImage imageNamed:@"Tab-popular.png"];
        self.emptyText = @"No videos.";
        self.continuationEndpoint = @"browse";
    }
    return self;
}

- (void)viewDidLoad {
    self.topics = [[UISegmentedControl alloc] initWithItems:[[self class] topicNames]];
    self.topics.segmentedControlStyle = UISegmentedControlStyleBar;
    self.topics.frame = CGRectMake(0, 0, 300, 30);
    NSInteger saved = [[NSUserDefaults standardUserDefaults] integerForKey:RTPopularTopicKey];
    self.topics.selectedSegmentIndex = saved >= 0 && saved < (NSInteger)[[self class] topicNames].count ? saved : 0;
    [self.topics addTarget:self action:@selector(topicChanged) forControlEvents:UIControlEventValueChanged];
    self.navigationItem.titleView = self.topics;
    [self useTopic];
    [super viewDidLoad];
}

- (void)useTopic {
    NSString *channelId = [[self class] topicChannelIds][(NSUInteger)self.topics.selectedSegmentIndex];
    self.firstRequest = [[RTInnerTube shared] browseRequest:channelId params:nil];
}

- (void)topicChanged {
    [[NSUserDefaults standardUserDefaults] setInteger:self.topics.selectedSegmentIndex forKey:RTPopularTopicKey];
    [self useTopic];
    [self reload];
    [self.tableView setContentOffset:CGPointZero animated:NO];
}

// A topic page has shelves of videos and playlists. Keep only the videos.
- (NSArray *)itemsToAdd:(RTPage *)page {
    NSMutableArray *videos = [NSMutableArray array];
    for (id item in page.items) {
        if ([item isKindOfClass:[RTVideo class]]) [videos addObject:item];
    }
    return videos;
}

@end
