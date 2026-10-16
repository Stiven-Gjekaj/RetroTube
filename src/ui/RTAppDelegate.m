#import "RTAppDelegate.h"
#import <AVFoundation/AVFoundation.h>
#import "RTHLSServer.h"
#import "RTNavigationController.h"
#import "RTSearchViewController.h"

@implementation RTAppDelegate

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    // Play the sound of a video also when the ring switch is off.
    [[AVAudioSession sharedInstance] setCategory:AVAudioSessionCategoryPlayback error:NULL];
    [[RTHLSServer shared] start:NULL];

    self.window = [[UIWindow alloc] initWithFrame:[UIScreen mainScreen].bounds];
    UINavigationController *search =
        [[RTNavigationController alloc] initWithRootViewController:[RTSearchViewController new]];
    self.window.rootViewController = search;
    [self.window makeKeyAndVisible];
    return YES;
}

@end
