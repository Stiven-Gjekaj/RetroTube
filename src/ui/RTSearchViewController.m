#import "RTSearchViewController.h"
#import "RTChannelViewController.h"
#import "RTInnerTube.h"
#import "RTLink.h"
#import "RTTitles.h"
#import "RTVideoViewController.h"

@interface RTSearchViewController ()
@property (nonatomic, strong) UISearchBar *searchBar;
@property (nonatomic, strong) NSMutableSet *checkedTitles;     // The video IDs that have their original title
@property (nonatomic, strong) NSMutableArray *pendingTitles;   // The videos of the next batch
@end

@implementation RTSearchViewController

- (instancetype)init {
    if ((self = [super init])) {
        self.title = @"Search";
        self.tabBarItem.image = [UIImage imageNamed:@"Tab-search.png"];
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
    // A new search has new items. Check their titles again.
    [self.checkedTitles removeAllObjects];
    [self.pendingTitles removeAllObjects];
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

// YouTube search can give a translated title. Show the original one, see
// RTTitles.h. Ask only for the rows that show, one time for each video.
// Collect the rows for a short time, so that one scroll gives one batch.
- (void)tableView:(UITableView *)tableView willDisplayCell:(UITableViewCell *)cell
    forRowAtIndexPath:(NSIndexPath *)indexPath {
    [super tableView:tableView willDisplayCell:cell forRowAtIndexPath:indexPath];
    id item = self.items[(NSUInteger)indexPath.row];
    if (![item isKindOfClass:[RTVideo class]]) return;
    RTVideo *video = item;
    if (!self.checkedTitles) self.checkedTitles = [NSMutableSet set];
    if (!self.pendingTitles) self.pendingTitles = [NSMutableArray array];
    if ([self.checkedTitles containsObject:video.videoId]) return;
    [self.checkedTitles addObject:video.videoId];
    [self.pendingTitles addObject:video];
    [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(loadPendingTitles) object:nil];
    [self performSelector:@selector(loadPendingTitles) withObject:nil afterDelay:0.3];
}

- (void)loadPendingTitles {
    NSMutableDictionary *videos = [NSMutableDictionary dictionary];
    for (RTVideo *video in self.pendingTitles) videos[video.videoId] = video;
    [self.pendingTitles removeAllObjects];
    __weak RTSearchViewController *weakSelf = self;
    RTLoadOriginalTitles(videos.allKeys, ^(NSDictionary *titles) {
        NSMutableArray *changed = [NSMutableArray array];
        [titles enumerateKeysAndObjectsUsingBlock:^(NSString *videoId, NSString *title, BOOL *stop) {
            RTVideo *video = videos[videoId];
            if (![video.title isEqualToString:title]) {
                video.title = title;
                [changed addObject:video];
            }
        }];
        [weakSelf reloadItems:changed];
    });
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
