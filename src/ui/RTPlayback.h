// Starts the playback of a video: it loads the streams, starts a stream
// session on the local HLS server, and shows the system movie player.

#import <UIKit/UIKit.h>
#import "RTModels.h"

// The user default with the highest video height to play. 0 or no value
// means Auto: the player changes the quality with the speed of the network.
extern NSString *const RTMaxHeightDefaultsKey;

@class RTPlayerInfo;

@interface RTPlayback : NSObject
+ (void)playVideo:(RTVideo *)video from:(UIViewController *)controller;
// Plays with streams that are already loaded. info can be nil. Then it loads them.
+ (void)playVideo:(RTVideo *)video info:(RTPlayerInfo *)info from:(UIViewController *)controller;
// YES when the quality is Auto. This is the default.
+ (BOOL)isAuto;
// The highest height to play. For Auto, the highest height of Auto.
+ (NSInteger)maxHeight;
@end
