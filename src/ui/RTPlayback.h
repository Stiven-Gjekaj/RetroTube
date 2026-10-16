// Starts the playback of a video: it loads the streams, starts a stream
// session on the local HLS server, and shows the system movie player.

#import <UIKit/UIKit.h>
#import "RTModels.h"

// The user default with the highest video height to play. The default is 720.
extern NSString *const RTMaxHeightDefaultsKey;

@class RTPlayerInfo;

@interface RTPlayback : NSObject
+ (void)playVideo:(RTVideo *)video from:(UIViewController *)controller;
// Plays with streams that are already loaded. info can be nil. Then it loads them.
+ (void)playVideo:(RTVideo *)video info:(RTPlayerInfo *)info from:(UIViewController *)controller;
+ (NSInteger)maxHeight;
@end
