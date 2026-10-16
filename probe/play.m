// play: play one video through the local HLS server, with no interface.
// It prints the play time each 2 seconds, seeks to the middle, and prints
// the CPU time that the process used.
// Usage: play VIDEO_ID [MAX_HEIGHT [reset]]
// "reset" forgets the visitor ID first.

#import <AVFoundation/AVFoundation.h>
#import <CoreMedia/CoreMedia.h>
#import <Foundation/Foundation.h>
#include <sys/resource.h>
#import "RTHLSServer.h"
#import "RTInnerTube.h"
#import "RTStreamSession.h"

static double CPUSeconds(void) {
    struct rusage usage;
    getrusage(RUSAGE_SELF, &usage);
    return usage.ru_utime.tv_sec + usage.ru_stime.tv_sec + (usage.ru_utime.tv_usec + usage.ru_stime.tv_usec) / 1e6;
}

static void Report(AVPlayerItem *item, double start) {
    printf("  t=%5.1fs status %ld time %6.2f cpu %.2fs %s\n", -[[NSDate dateWithTimeIntervalSince1970:start] timeIntervalSinceNow],
           (long)item.status, CMTimeGetSeconds(item.currentTime), CPUSeconds(),
           item.error ? item.error.localizedDescription.UTF8String : "");
}

static void Run(double seconds) {
    [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:seconds]];
}

int main(int argc, char **argv) {
    @autoreleasepool {
        NSString *videoId = argc > 1 ? @(argv[1]) : @"a5uQMwRMHcs";
        NSInteger maxHeight = argc > 2 ? atoi(argv[2]) : 720;
        [[AVAudioSession sharedInstance] setCategory:AVAudioSessionCategoryPlayback error:NULL];
        [[AVAudioSession sharedInstance] setActive:YES error:NULL];
        double start = [[NSDate date] timeIntervalSince1970];

        NSError *error = nil;
        if (argc > 3 && !strcmp(argv[3], "reset")) [RTInnerTube shared].visitorData = nil;
        RTPlayerInfo *info = [[RTInnerTube shared] loadPlayer:videoId error:&error];
        if (!info) printf("player: %s\n", error.description.UTF8String);
        RTFormat *video = [info videoFormatForMaxHeight:maxHeight];
        printf("%s: %s, %lds, video %s, audio %s\n", videoId.UTF8String, info.status.UTF8String, (long)info.lengthSeconds,
               video.description.UTF8String, info.audioFormat.description.UTF8String);
        if (!video) return 1;

        RTStreamSession *session = [[RTStreamSession alloc] initWithVideo:video audio:info.audioFormat];
        if (![session prepare:&error]) {
            printf("prepare: %s\n", error.description.UTF8String);
            return 1;
        }
        printf("prepared: %lu segments after %.2fs\n", (unsigned long)session.segmentCount,
               [[NSDate date] timeIntervalSince1970] - start);
        RTHLSServer *server = [RTHLSServer shared];
        [server start:NULL];
        NSURL *url = [server addSource:session];

        AVPlayerItem *item = [AVPlayerItem playerItemWithURL:url];
        AVPlayer *player = [AVPlayer playerWithPlayerItem:item];
        [player play];
        for (int i = 0; i < 6; i++) {
            Run(2);
            Report(item, start);
        }
        double middle = info.lengthSeconds / 2.0;
        printf("seek to %.0fs\n", middle);
        [player seekToTime:CMTimeMakeWithSeconds(middle, 600)];
        for (int i = 0; i < 5; i++) {
            Run(2);
            Report(item, start);
        }
    }
    return 0;
}
