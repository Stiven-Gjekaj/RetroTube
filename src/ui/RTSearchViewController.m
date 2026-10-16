#import "RTSearchViewController.h"
#import "RTChannelViewController.h"
#import "RTInnerTube.h"
#import "RTLink.h"
#import "RTVideoViewController.h"

@interface RTSearchViewController ()
@property (nonatomic, strong) UISearchBar *searchBar;
@end

@implementation RTSearchViewController

- (instancetype)init {
    if ((self = [super init])) {
        self.title = @"Search";
        self.continuationEndpoint = @"search";
        self.emptyText = @"No results.";
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.searchBar = [[UISearchBar alloc] initWithFrame:CGRectMake(0, 0, 320, 44)];
    self.searchBar.placeholder = @"Search YouTube";
    self.searchBar.delegate = self;
    self.tableView.tableHeaderView = self.searchBar;
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    if (!self.items.count && !self.firstRequest) [self.searchBar becomeFirstResponder];
}

- (void)searchFor:(NSString *)query {
    [self view];  // Load the search bar.
    self.searchBar.text = query;
    [self.searchBar resignFirstResponder];
    self.firstRequest = [[RTInnerTube shared] searchRequest:query params:nil];
    [self reload];
}

// A pasted YouTube link opens its video or its channel. Other text is a search.
- (void)searchBarSearchButtonClicked:(UISearchBar *)searchBar {
    RTLink *link = RTParseText(searchBar.text);
    if (link.kind == RTLinkVideo) {
        [searchBar resignFirstResponder];
        RTVideo *video = [RTVideo new];
        video.videoId = link.value;
        [self.navigationController pushViewController:[[RTVideoViewController alloc] initWithVideo:video] animated:YES];
    } else if (link.kind == RTLinkChannel) {
        [searchBar resignFirstResponder];
        RTChannel *channel = [RTChannel new];
        channel.channelId = link.value;
        [self.navigationController pushViewController:[[RTChannelViewController alloc] initWithChannel:channel]
                                             animated:YES];
    } else if (link.kind == RTLinkSearch) {
        [self searchFor:link.value];
    }
}

- (void)searchBarTextDidBeginEditing:(UISearchBar *)searchBar {
    [searchBar setShowsCancelButton:YES animated:YES];
}

- (void)searchBarTextDidEndEditing:(UISearchBar *)searchBar {
    [searchBar setShowsCancelButton:NO animated:YES];
}

- (void)searchBarCancelButtonClicked:(UISearchBar *)searchBar {
    [searchBar resignFirstResponder];
}

@end
