#import "RTSubscriptionsViewController.h"
#import "RTStore.h"

@implementation RTSubscriptionsViewController

- (instancetype)init {
    if ((self = [super init])) {
        self.title = @"Subscriptions";
        self.tabBarItem.image = [UIImage imageNamed:@"Tab-subscriptions.png"];
        self.emptyText = @"Open a channel and tap Subscribe.";
        self.items = [RTStore shared].subscriptions;
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(storeChanged)
                                                     name:RTStoreDidChangeNotification object:nil];
    }
    return self;
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.navigationItem.rightBarButtonItem = self.editButtonItem;
}

- (void)storeChanged {
    self.items = [RTStore shared].subscriptions;
}

- (BOOL)canDeleteItems {
    return YES;
}

- (void)deleteItem:(RTChannel *)channel {
    [[RTStore shared] unsubscribe:channel.channelId];
}

@end
