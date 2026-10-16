#import "RTFeedViewController.h"
#import "RTFeedLoader.h"
#import "RTStore.h"

@interface RTFeedViewController ()
@property (nonatomic, copy) NSArray *loadedIds;  // The subscriptions of the last load
@end

@implementation RTFeedViewController

- (instancetype)init {
    if ((self = [super init])) {
        self.title = @"Feed";
        self.tabBarItem.image = [UIImage imageNamed:@"Tab-feed.png"];
        self.emptyText = @"Subscribe to channels to see their new videos here.";
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.refreshControl = [UIRefreshControl new];
    [self.refreshControl addTarget:self action:@selector(reload) forControlEvents:UIControlEventValueChanged];
    [self reload];
}

// Load again when the subscriptions changed while another tab showed.
- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    NSArray *ids = [[RTStore shared].subscriptions valueForKey:@"channelId"];
    if (self.loadedIds && ![ids isEqualToArray:self.loadedIds]) [self reload];
}

- (void)reload {
    if (self.loading) return;
    NSArray *ids = [[RTStore shared].subscriptions valueForKey:@"channelId"];
    self.loadedIds = ids;
    if (!ids.count) {
        self.items = @[];
        [self.refreshControl endRefreshing];
        return;
    }
    self.loading = YES;
    if (!self.items.count) [self.refreshControl beginRefreshing];
    __weak RTFeedViewController *weakSelf = self;
    RTLoadFeeds(ids, ^(NSArray *videos, NSUInteger failures) {
        weakSelf.loading = NO;
        [weakSelf.refreshControl endRefreshing];
        if (videos.count || !failures) weakSelf.items = videos;
        if (failures == ids.count) weakSelf.emptyText = @"The feeds did not load. Pull down to try again.";
        else weakSelf.emptyText = @"Subscribe to channels to see their new videos here.";
        if (!weakSelf.items.count) weakSelf.items = @[];
    });
}

@end
