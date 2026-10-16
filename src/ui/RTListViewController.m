#import "RTListViewController.h"
#import "RTChannelViewController.h"
#import "RTInnerTube.h"
#import "RTParse.h"
#import "RTPlayback.h"
#import "RTVideoCell.h"

// Load the next page when one of the last rows shows.
static const NSUInteger RTLoadMoreDistance = 5;

@interface RTListViewController ()
@property (nonatomic, strong) NSMutableArray *list;
@property (nonatomic, copy) NSString *continuation;
@property (nonatomic) BOOL loading;
@property (nonatomic) NSUInteger generation;  // A new reload drops the answers of the old one.
@property (nonatomic, strong) UILabel *messageLabel;
@property (nonatomic, strong) UIActivityIndicatorView *spinner;
@end

@implementation RTListViewController

- (instancetype)init {
    if ((self = [super initWithStyle:UITableViewStylePlain])) {
        _list = [NSMutableArray array];
        _continuationEndpoint = @"browse";
    }
    return self;
}

- (NSArray *)items {
    return self.list;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.tableView.rowHeight = [RTVideoCell height];
    self.spinner = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleGray];
    self.spinner.frame = CGRectMake(0, 0, 320, 44);
    self.messageLabel = [[UILabel alloc] initWithFrame:CGRectMake(20, 0, 280, 80)];
    self.messageLabel.textAlignment = NSTextAlignmentCenter;
    self.messageLabel.textColor = [UIColor grayColor];
    self.messageLabel.numberOfLines = 0;
    self.messageLabel.font = [UIFont systemFontOfSize:15];
    self.messageLabel.backgroundColor = [UIColor clearColor];
    self.refreshControl = [UIRefreshControl new];
    [self.refreshControl addTarget:self action:@selector(reload) forControlEvents:UIControlEventValueChanged];
    if (self.firstRequest && !self.list.count) [self reload];
    else [self updateFooter];
}

- (void)updateFooter {
    if (self.loading) {
        [self.spinner startAnimating];
        self.tableView.tableFooterView = self.spinner;
    } else if (!self.list.count && self.messageLabel.text.length) {
        [self.spinner stopAnimating];
        self.tableView.tableFooterView = self.messageLabel;
    } else {
        [self.spinner stopAnimating];
        self.tableView.tableFooterView = [UIView new];  // No empty separator lines.
    }
}

- (void)reload {
    if (!self.firstRequest) {
        [self.refreshControl endRefreshing];
        return;
    }
    self.generation++;
    [self.list removeAllObjects];
    self.continuation = nil;
    self.loading = NO;
    [self.tableView reloadData];
    [self loadRequest:self.firstRequest];
}

- (NSArray *)itemsToAdd:(RTPage *)page {
    return page.items;
}

- (id)resultFromJSON:(NSDictionary *)json {
    return RTParsePage(json);
}

- (RTPage *)pageFromResult:(id)result {
    return result;
}

- (void)loadRequest:(NSURLRequest *)request {
    if (self.loading) return;
    self.loading = YES;
    self.messageLabel.text = nil;
    [self updateFooter];
    NSUInteger generation = self.generation;
    __weak RTListViewController *weakSelf = self;
    [[RTInnerTube shared] send:request transform:^id(NSDictionary *json) {
        return [weakSelf resultFromJSON:json];
    } handler:^(id result, NSError *error) {
        RTListViewController *controller = weakSelf;
        if (!controller || generation != controller.generation) return;
        RTPage *page = result ? [controller pageFromResult:result] : nil;
        controller.loading = NO;
        [controller.refreshControl endRefreshing];
        if (error) {
            controller.messageLabel.text = error.localizedDescription;
            controller.continuation = nil;
        } else {
            NSMutableArray *added = [NSMutableArray array];
            for (id item in [controller itemsToAdd:page]) {
                if (![controller.list containsObject:item]) [added addObject:item];
            }
            NSUInteger start = controller.list.count;
            [controller.list addObjectsFromArray:added];
            // A page with no new items ends the list, so that a loop of
            // tokens does not load forever.
            controller.continuation = added.count ? page.continuation : nil;
            if (start == 0) {
                [controller.tableView reloadData];
            } else if (added.count) {
                NSMutableArray *paths = [NSMutableArray array];
                for (NSUInteger i = start; i < controller.list.count; i++) {
                    [paths addObject:[NSIndexPath indexPathForRow:(NSInteger)i inSection:0]];
                }
                [controller.tableView insertRowsAtIndexPaths:paths withRowAnimation:UITableViewRowAnimationNone];
            }
            if (!controller.list.count) controller.messageLabel.text = controller.emptyText;
        }
        [controller updateFooter];
    }];
}

- (void)loadMore {
    if (self.continuation && !self.loading) {
        [self loadRequest:[[RTInnerTube shared] continuationRequest:self.continuation endpoint:self.continuationEndpoint]];
    }
}

#pragma mark - Table

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return (NSInteger)self.list.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    static NSString *const identifier = @"item";
    RTVideoCell *cell = [tableView dequeueReusableCellWithIdentifier:identifier];
    if (!cell) cell = [[RTVideoCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:identifier];
    id item = self.list[(NSUInteger)indexPath.row];
    if ([item isKindOfClass:[RTVideo class]]) [cell showVideo:item];
    else [cell showChannel:item];
    return cell;
}

- (void)tableView:(UITableView *)tableView willDisplayCell:(UITableViewCell *)cell forRowAtIndexPath:(NSIndexPath *)indexPath {
    if ((NSUInteger)indexPath.row + RTLoadMoreDistance >= self.list.count) [self loadMore];
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    id item = self.list[(NSUInteger)indexPath.row];
    if ([item isKindOfClass:[RTVideo class]]) {
        [RTPlayback playVideo:item from:self];
    } else {
        [self.navigationController pushViewController:[[RTChannelViewController alloc] initWithChannel:item]
                                             animated:YES];
    }
}

@end
