#import "RTTest.h"
#import "RTPlayer.h"

static NSDictionary *Format(int itag, NSString *mime, int height, int fps, int bitrate) {
    NSMutableDictionary *f = [@{ @"itag": @(itag), @"mimeType": mime, @"bitrate": @(bitrate),
                                 @"url": [NSString stringWithFormat:@"https://r.googlevideo.com/v?itag=%d", itag],
                                 @"initRange": @{ @"start": @"0", @"end": @"738" },
                                 @"indexRange": @{ @"start": @"739", @"end": @"1550" },
                                 @"contentLength": @"17238169" } mutableCopy];
    if (height) {
        f[@"height"] = @(height);
        f[@"fps"] = @(fps);
    }
    return f;
}

static NSDictionary *Answer(NSArray *formats) {
    return @{ @"playabilityStatus": @{ @"status": @"OK" },
              @"videoDetails": @{ @"videoId": @"a5uQMwRMHcs", @"title": @"Instant Crush", @"author": @"DaftPunkVEVO",
                                  @"channelId": @"UCKHF", @"lengthSeconds": @"340", @"viewCount": @"904270625",
                                  @"shortDescription": @"Official video" },
              @"streamingData": @{ @"adaptiveFormats": formats } };
}

RT_TEST(test_player_reads_details) {
    RTPlayerInfo *info = RTParsePlayer(Answer(@[]));
    RT_EQUAL(info.status, @"OK");
    RT_EQUAL(info.videoId, @"a5uQMwRMHcs");
    RT_EQUAL(info.title, @"Instant Crush");
    RT_EQUAL(info.author, @"DaftPunkVEVO");
    RT_EQUAL(info.channelId, @"UCKHF");
    RT_EQUAL(info.shortDescription, @"Official video");
    RT_EQUAL_INT(info.lengthSeconds, 340);
    RT_EQUAL_INT(info.viewCount, 904270625LL);
    RT_EXPECT(!info.isLive);
}

RT_TEST(test_player_reads_ranges_as_inclusive_ends) {
    RTFormat *format = RTParsePlayer(Answer(@[ Format(136, @"video/mp4; codecs=\"avc1.4D401F\"", 720, 30, 1) ])).videoFormats[0];
    RT_EQUAL_INT(format.initRange.location, 0);
    RT_EQUAL_INT(format.initRange.length, 739);
    RT_EQUAL_INT(format.indexRange.location, 739);
    RT_EQUAL_INT(format.indexRange.length, 812);
    RT_EQUAL_INT(format.contentLength, 17238169);
}

RT_TEST(test_player_keeps_only_h264_and_aac) {
    RTPlayerInfo *info = RTParsePlayer(Answer(@[
        Format(137, @"video/mp4; codecs=\"avc1.640028\"", 1080, 30, 2400000),
        Format(248, @"video/webm; codecs=\"vp09.00.40.08\"", 1080, 30, 1000000),
        Format(399, @"video/mp4; codecs=\"av01.0.08M.08\"", 1080, 30, 900000),
        Format(139, @"audio/mp4; codecs=\"mp4a.40.5\"", 0, 0, 50000),
        Format(140, @"audio/mp4; codecs=\"mp4a.40.2\"", 0, 0, 130000),
        Format(251, @"audio/webm; codecs=\"opus\"", 0, 0, 160000) ]));
    RT_EQUAL([info.videoFormats valueForKey:@"itag"], @[ @137 ]);
    RT_EQUAL([info.audioFormats valueForKey:@"itag"], @[ @140 ]);
}

RT_TEST(test_player_picks_highest_video_under_limit) {
    RTPlayerInfo *info = RTParsePlayer(Answer(@[
        Format(134, @"video/mp4; codecs=\"avc1.4D401E\"", 360, 30, 250000),
        Format(137, @"video/mp4; codecs=\"avc1.640028\"", 1080, 30, 2400000),
        Format(136, @"video/mp4; codecs=\"avc1.4D401F\"", 720, 30, 1000000),
        Format(298, @"video/mp4; codecs=\"avc1.4d4020\"", 720, 60, 3000000) ]));
    RT_EQUAL_INT([info videoFormatForMaxHeight:720].itag, 136);
    RT_EQUAL_INT([info videoFormatForMaxHeight:1080].itag, 137);
    RT_EQUAL_INT([info videoFormatForMaxHeight:480].itag, 134);
    RT_EXPECT([info videoFormatForMaxHeight:144] == nil);
}

RT_TEST(test_player_prefers_original_audio) {
    NSMutableDictionary *drc = [Format(140, @"audio/mp4; codecs=\"mp4a.40.2\"", 0, 0, 1) mutableCopy];
    drc[@"isDrc"] = @YES;
    drc[@"url"] = @"https://r.googlevideo.com/drc";
    NSMutableDictionary *dub = [Format(140, @"audio/mp4; codecs=\"mp4a.40.2\"", 0, 0, 1) mutableCopy];
    dub[@"audioTrack"] = @{ @"displayName": @"French", @"audioIsDefault": @NO };
    dub[@"url"] = @"https://r.googlevideo.com/dub";
    NSMutableDictionary *original = [Format(140, @"audio/mp4; codecs=\"mp4a.40.2\"", 0, 0, 1) mutableCopy];
    original[@"audioTrack"] = @{ @"displayName": @"English original", @"audioIsDefault": @YES };
    original[@"url"] = @"https://r.googlevideo.com/original";
    RTPlayerInfo *info = RTParsePlayer(Answer(@[ drc, dub, original ]));
    RT_EQUAL(info.audioFormat.url.absoluteString, @"https://r.googlevideo.com/original");
    RT_EQUAL_INT(info.audioFormats.count, 3);
}

RT_TEST(test_player_skips_ciphered_streams) {
    NSMutableDictionary *f = [Format(136, @"video/mp4; codecs=\"avc1.4D401F\"", 720, 30, 1) mutableCopy];
    [f removeObjectForKey:@"url"];
    f[@"signatureCipher"] = @"s=abc&url=x";
    RT_EQUAL_INT(RTParsePlayer(Answer(@[ f ])).videoFormats.count, 0);
}

RT_TEST(test_player_reads_refusal) {
    RTPlayerInfo *info = RTParsePlayer(@{ @"playabilityStatus": @{ @"status": @"LOGIN_REQUIRED",
                                                                  @"reason": @"Sign in to confirm your age" } });
    RT_EQUAL(info.status, @"LOGIN_REQUIRED");
    RT_EQUAL(info.reason, @"Sign in to confirm your age");
    RT_EQUAL_INT(info.videoFormats.count, 0);
}

RT_TEST(test_player_status_of_empty_answer_is_error) {
    RT_EQUAL(RTParsePlayer(@{}).status, @"ERROR");
}
