// The page of one video: a large picture with a play button, the details, the
// channel, the description, and the related videos.

#import "RTListViewController.h"

@interface RTVideoViewController : RTListViewController
- (instancetype)initWithVideo:(RTVideo *)video;
@end
