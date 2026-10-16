#import "RTAppDelegate.h"
#import <AVFoundation/AVFoundation.h>
#import "RTChannelViewController.h"
#import "RTFeedViewController.h"
#import "RTHistoryViewController.h"
#import "RTSubscriptionsViewController.h"
#import "RTTabBarController.h"
#import "RTHLSServer.h"
#import "RTLink.h"
#import "RTPopularViewController.h"
#import "RTVideoViewController.h"
#import "RTNavigationController.h"
#import "RTSearchViewController.h"
#import "RTStore.h"
#import "RTTheme.h"

@interface RTAppDelegate ()
@property (nonatomic, strong) UITabBarController *tabs;
@property (nonatomic, strong) UINavigationController *searchNavigation;
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
    self.searchNavigation = [[RTNavigationController alloc] initWithRootViewController:self.search];
    self.tabs = [RTTabBarController new];
    self.tabs.viewControllers = @[
        [[RTNavigationController alloc] initWithRootViewController:[RTPopularViewController new]],
        [[RTNavigationController alloc] initWithRootViewController:[RTFeedViewController new]],
        self.searchNavigation,
        [[RTNavigationController alloc] initWithRootViewController:[RTSubscriptionsViewController new]],
        [[RTNavigationController alloc] initWithRootViewController:[RTHistoryViewController new]],
    ];
    // With subscriptions, start on the feed. Without them, on Popular.
    if ([RTStore shared].subscriptions.count) self.tabs.selectedIndex = 1;
    self.window.rootViewController = self.tabs;
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
    [self.tabs dismissViewControllerAnimated:NO completion:nil];
    if (link.kind == RTLinkTab) {
        NSUInteger index = [@[ @"popular", @"feed", @"search", @"subscriptions", @"history" ] indexOfObject:link.value];
        UINavigationController *navigation = self.tabs.viewControllers[index];
        [navigation popToRootViewControllerAnimated:NO];
        self.tabs.selectedViewController = navigation;
        return YES;
    }
    self.tabs.selectedViewController = self.searchNavigation;
    if (link.kind == RTLinkSearch) {
        [self.searchNavigation popToRootViewControllerAnimated:NO];
        [self.search searchFor:link.value];
    } else if (link.kind == RTLinkVideo) {
        RTVideo *video = [RTVideo new];
        video.videoId = link.value;
        [self.searchNavigation pushViewController:[[RTVideoViewController alloc] initWithVideo:video] animated:NO];
    } else if (link.kind == RTLinkChannel) {
        RTChannel *channel = [RTChannel new];
        channel.channelId = link.value;
        [self.searchNavigation pushViewController:[[RTChannelViewController alloc] initWithChannel:channel] animated:NO];
    }
    return YES;
}

@end
