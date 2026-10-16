// A table cell for a video or a channel: a thumbnail on the left, the title,
// and one line of details.

#import <UIKit/UIKit.h>
#import "RTModels.h"

@interface RTVideoCell : UITableViewCell

+ (CGFloat)height;
- (void)showVideo:(RTVideo *)video;
- (void)showChannel:(RTChannel *)channel;

@end
