#import "RTAppDelegate.h"
#import <AVFoundation/AVFoundation.h>
#import "RTChannelViewController.h"
#import "RTHLSServer.h"
#import "RTLink.h"
#import "RTVideoViewController.h"
#import "RTNavigationController.h"
#import "RTSearchViewController.h"
#import "RTTheme.h"

@interface RTAppDelegate ()
@property (nonatomic, strong) UINavigationController *navigation;
@property (nonatomic, strong) RTSearchViewController *search;
@end

@implementation RTAppDelegate

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    // Play the sound of a video also when the ring switch is off.
    [[AVAudioSession sharedInstance] setCategory:AVAudioSessionCategoryPlayback error:NULL];
    [[RTHLSServer shared] start:NULL];
    RTApplyTheme();

    self.window = [[UIWindow alloc] initWithFrame:[UIScreen mainScreen].bounds];
    self.search = [RTSearchViewController new];
    self.navigation = [[RTNavigationController alloc] initWithRootViewController:self.search];
    self.window.rootViewController = self.navigation;
    [self.window makeKeyAndVisible];
    // iOS calls application:openURL: after this method for a launch from a
    // link, so this method does not open the link.
    return YES;
}

- (BOOL)application:(UIApplication *)application openURL:(NSURL *)url sourceApplication:(NSString *)sourceApplication
         annotation:(id)annotation {
    return [self openLink:url];
}

- (BOOL)openLink:(NSURL *)url {
    RTLink *link = RTParseLink(url);
    if (link.kind == RTLinkNone) return NO;
    // A link can come while the movie player shows. Close it first.
    [self.navigation dismissViewControllerAnimated:NO completion:nil];
    if (link.kind == RTLinkSearch) {
        [self.navigation popToRootViewControllerAnimated:NO];
        [self.search searchFor:link.value];
    } else if (link.kind == RTLinkVideo) {
        RTVideo *video = [RTVideo new];
        video.videoId = link.value;
        [self.navigation pushViewController:[[RTVideoViewController alloc] initWithVideo:video] animated:NO];
    } else if (link.kind == RTLinkChannel) {
        RTChannel *channel = [RTChannel new];
        channel.channelId = link.value;
        [self.navigation pushViewController:[[RTChannelViewController alloc] initWithChannel:channel] animated:NO];
    }
    return YES;
}

@end
