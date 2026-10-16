#import "RTLocalListViewController.h"
#import "RTChannelViewController.h"
#import "RTVideoCell.h"
#import "RTVideoViewController.h"

@interface RTLocalListViewController ()
@property (nonatomic, strong) UIView *emptyView;
@property (nonatomic, strong) UILabel *emptyLabel;
@end

@implementation RTLocalListViewController

- (instancetype)init {
    return [super initWithStyle:UITableViewStylePlain];
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.tableView.rowHeight = [RTVideoCell height];
    // The table makes its footer as wide as itself, so the label is inside a
    // view, with a margin on each side.
    self.emptyView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 320, 100)];
    self.emptyLabel = [[UILabel alloc] initWithFrame:CGRectMake(20, 0, 280, 100)];
    self.emptyLabel.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    [self.emptyView addSubview:self.emptyLabel];
    self.emptyLabel.textAlignment = NSTextAlignmentCenter;
    self.emptyLabel.textColor = [UIColor grayColor];
    self.emptyLabel.numberOfLines = 0;
    self.emptyLabel.font = [UIFont systemFontOfSize:15];
    self.emptyLabel.backgroundColor = [UIColor clearColor];
    [self updateFooter];
}

- (void)setItems:(NSArray *)items {
    _items = [items copy];
    if (self.isViewLoaded) {
        [self.tableView reloadData];
        [self updateFooter];
    }
}

- (void)setLoading:(BOOL)loading {
    _loading = loading;
    if (self.isViewLoaded) [self updateFooter];
}

- (void)setEmptyText:(NSString *)emptyText {
    _emptyText = [emptyText copy];
    if (self.isViewLoaded) [self updateFooter];
}

- (void)updateFooter {
    self.emptyLabel.text = self.emptyText;
    self.tableView.tableFooterView = (self.items.count || self.loading) ? [UIView new] : self.emptyView;
}

- (BOOL)canDeleteItems {
    return NO;
}

- (void)deleteItem:(id)item {
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return (NSInteger)self.items.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    static NSString *const identifier = @"item";
    RTVideoCell *cell = [tableView dequeueReusableCellWithIdentifier:identifier];
    if (!cell) cell = [[RTVideoCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:identifier];
    id item = self.items[(NSUInteger)indexPath.row];
    if ([item isKindOfClass:[RTVideo class]]) [cell showVideo:item];
    else [cell showChannel:item];
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    id item = self.items[(NSUInteger)indexPath.row];
    UIViewController *next = [item isKindOfClass:[RTVideo class]]
        ? [[RTVideoViewController alloc] initWithVideo:item]
        : [[RTChannelViewController alloc] initWithChannel:item];
    [self.navigationController pushViewController:next animated:YES];
}

- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath {
    return [self canDeleteItems];
}

- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle
    forRowAtIndexPath:(NSIndexPath *)indexPath {
    if (editingStyle != UITableViewCellEditingStyleDelete) return;
    [self deleteItem:self.items[(NSUInteger)indexPath.row]];
}

@end
