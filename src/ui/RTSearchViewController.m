#import "RTSearchViewController.h"
#import "RTInnerTube.h"

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

- (void)searchBarSearchButtonClicked:(UISearchBar *)searchBar {
    NSString *query = [searchBar.text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
    if (!query.length) return;
    [searchBar resignFirstResponder];
    self.firstRequest = [[RTInnerTube shared] searchRequest:query params:nil];
    [self reload];
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
