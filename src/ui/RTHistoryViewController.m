#import "RTHistoryViewController.h"
#import "RTStore.h"

@implementation RTHistoryViewController

- (instancetype)init {
    if ((self = [super init])) {
        self.title = @"History";
        self.tabBarItem.image = [UIImage imageNamed:@"Tab-history.png"];
        self.emptyText = @"The videos that you play show here.";
        self.items = [RTStore shared].history;
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
    [self updateClearButton];
}

- (void)storeChanged {
    self.items = [RTStore shared].history;
    [self updateClearButton];
}

- (void)updateClearButton {
    self.navigationItem.rightBarButtonItem =
        self.items.count ? [[UIBarButtonItem alloc] initWithTitle:@"Clear" style:UIBarButtonItemStyleBordered
                                                           target:self action:@selector(askClear)]
                         : nil;
}

- (void)askClear {
    UIActionSheet *sheet = [[UIActionSheet alloc] initWithTitle:nil delegate:self cancelButtonTitle:@"Cancel"
                                         destructiveButtonTitle:@"Clear History" otherButtonTitles:nil];
    [sheet showFromTabBar:self.tabBarController.tabBar];
}

- (void)actionSheet:(UIActionSheet *)actionSheet clickedButtonAtIndex:(NSInteger)buttonIndex {
    if (buttonIndex == actionSheet.destructiveButtonIndex) [[RTStore shared] clearHistory];
}

- (BOOL)canDeleteItems {
    return YES;
}

- (void)deleteItem:(RTVideo *)video {
    [[RTStore shared] removeFromHistory:video.videoId];
}

@end
