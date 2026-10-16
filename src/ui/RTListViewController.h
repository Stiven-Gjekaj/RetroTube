// A table of videos and channels from one InnerTube list, with more pages
// when the person scrolls to the end.

#import <UIKit/UIKit.h>
#import "RTModels.h"

@interface RTListViewController : UITableViewController

// The request of the first page. Subclasses set it, then call reload.
@property (nonatomic, copy) NSURLRequest *firstRequest;
// The endpoint of the continuation requests: "search", "browse", or "next".
@property (nonatomic, copy) NSString *continuationEndpoint;
// The text that shows when the list is empty.
@property (nonatomic, copy) NSString *emptyText;
@property (nonatomic, readonly) NSArray *items;

- (void)reload;

// Subclasses can change what a page adds. The default adds all its items.
- (NSArray *)itemsToAdd:(RTPage *)page;

// Runs after the new items of a page show. The default does nothing.
- (void)didAddItems:(NSArray *)items;

// Shows the item again, for example after a change of its title.
- (void)reloadItems:(NSArray *)items;

// Reads an answer. It runs on a background queue. The default returns
// RTParsePage(json).
- (id)resultFromJSON:(NSDictionary *)json;
// Gives the page of a result. It runs on the main queue. The default returns
// the result.
- (RTPage *)pageFromResult:(id)result;

@end
