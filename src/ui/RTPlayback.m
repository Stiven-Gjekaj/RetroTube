#import "RTPlayback.h"
#import <MediaPlayer/MediaPlayer.h>
#import <QuartzCore/QuartzCore.h>
#import "RTHLSServer.h"
#import "RTInnerTube.h"
#import "RTStreamSession.h"

NSString *const RTMaxHeightDefaultsKey = @"RTMaxHeight";

// A movie player that keeps its stream session for as long as it shows.
@interface RTMoviePlayerViewController : MPMoviePlayerViewController
@property (nonatomic, strong) RTStreamSession *session;
@end

@implementation RTMoviePlayerViewController

- (void)viewDidDisappear:(BOOL)animated {
    [super viewDidDisappear:animated];
    if (self.session && !self.presentingViewController) {
        [[RTHLSServer shared] removeSource:self.session];
        self.session = nil;
    }
}

@end

// A dark box with a spinner, in the middle of the window, while the streams load.
static UIView *RTShowLoading(UIView *parent) {
    UIView *box = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 120, 100)];
    box.center = CGPointMake(CGRectGetMidX(parent.bounds), CGRectGetMidY(parent.bounds));
    box.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleRightMargin |
                           UIViewAutoresizingFlexibleTopMargin | UIViewAutoresizingFlexibleBottomMargin;
    box.backgroundColor = [UIColor colorWithWhite:0 alpha:0.75];
    box.layer.cornerRadius = 10;
    UIActivityIndicatorView *spinner =
        [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleWhiteLarge];
    spinner.center = CGPointMake(60, 40);
    [spinner startAnimating];
    [box addSubview:spinner];
    UILabel *label = [[UILabel alloc] initWithFrame:CGRectMake(0, 68, 120, 20)];
    label.text = @"Loading";
    label.textColor = [UIColor whiteColor];
    label.backgroundColor = [UIColor clearColor];
    label.textAlignment = NSTextAlignmentCenter;
    label.font = [UIFont boldSystemFontOfSize:14];
    [box addSubview:label];
    [parent addSubview:box];
    return box;
}

static void RTShowError(NSString *title, NSString *message) {
    [[[UIAlertView alloc] initWithTitle:title message:message delegate:nil cancelButtonTitle:@"OK"
                      otherButtonTitles:nil] show];
}

@implementation RTPlayback

+ (NSInteger)maxHeight {
    NSInteger height = [[NSUserDefaults standardUserDefaults] integerForKey:RTMaxHeightDefaultsKey];
    return height > 0 ? height : 720;
}

+ (void)playVideo:(RTVideo *)video from:(UIViewController *)controller {
    UIView *window = controller.view.window;
    if (!window) return;
    UIView *loading = RTShowLoading(window);
    window.userInteractionEnabled = NO;
    void (^finish)(void) = ^{
        [loading removeFromSuperview];
        window.userInteractionEnabled = YES;
    };

    [[RTInnerTube shared] loadPlayer:video.videoId handler:^(RTPlayerInfo *info, NSError *error) {
        if (!info) {
            finish();
            RTShowError(@"Cannot load the video", error.localizedDescription);
            return;
        }
        if (![info.status isEqualToString:@"OK"]) {
            finish();
            RTShowError(@"The video does not play", info.reason ?: info.status);
            return;
        }
        RTFormat *videoFormat = [info videoFormatForMaxHeight:[self maxHeight]] ?: info.videoFormats.lastObject;
        if (!videoFormat) {
            finish();
            NSString *text = info.isLive ? @"RetroTube cannot play live videos yet."
                                         : @"The video has no H.264 stream.";
            RTShowError(@"The video does not play", text);
            return;
        }
        RTStreamSession *session = [[RTStreamSession alloc] initWithVideo:videoFormat audio:info.audioFormat];
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^{
            NSError *prepareError = nil;
            BOOL ready = [session prepare:&prepareError];
            dispatch_async(dispatch_get_main_queue(), ^{
                finish();
                if (!ready) {
                    RTShowError(@"Cannot load the video", prepareError.localizedDescription);
                    return;
                }
                NSURL *url = [[RTHLSServer shared] addSource:session];
                RTMoviePlayerViewController *player = [[RTMoviePlayerViewController alloc] initWithContentURL:url];
                player.session = session;
                player.moviePlayer.movieSourceType = MPMovieSourceTypeStreaming;
                [controller presentMoviePlayerViewControllerAnimated:player];
            });
        });
    }];
}

@end
