// Searches YouTube for videos and channels.

#import "RTListViewController.h"

@interface RTSearchViewController : RTListViewController <UISearchBarDelegate>
- (void)searchFor:(NSString *)query;
@end
