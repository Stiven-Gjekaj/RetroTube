// A table of videos or channels that the app has on the phone: the feed, the
// subscriptions, and the history. Subclasses set the items.

#import <UIKit/UIKit.h>

@interface RTLocalListViewController : UITableViewController

@property (nonatomic, copy) NSArray *items;
@property (nonatomic, copy) NSString *emptyText;
// While YES, the empty text does not show.
@property (nonatomic) BOOL loading;

// Subclasses can let the person delete a row. The default is NO.
- (BOOL)canDeleteItems;
- (void)deleteItem:(id)item;

@end
