// Starts the playback of a video: it loads the streams, starts a stream
// session on the local HLS server, and shows the system movie player.

#import <UIKit/UIKit.h>
#import "RTModels.h"

// The user default with the highest video height to play. The default is 720.
extern NSString *const RTMaxHeightDefaultsKey;

@interface RTPlayback : NSObject
+ (void)playVideo:(RTVideo *)video from:(UIViewController *)controller;
@end
