// probe: test if the phone can talk to YouTube with no outside help.
// Step 1: make HTTPS requests with the system TLS stack.
// Step 2: call the InnerTube /player API with mobile client identities.
// Step 3: read the first bytes of a stream URL and of the HLS manifest.
// Usage: probe [VIDEO_ID]

#import <Foundation/Foundation.h>

static NSData *Fetch(NSMutableURLRequest *req, NSHTTPURLResponse **outResp, NSError **outErr) {
    req.timeoutInterval = 20;
    NSURLResponse *resp = nil;
    NSData *data = [NSURLConnection sendSynchronousRequest:req returningResponse:&resp error:outErr];
    if (outResp) *outResp = (NSHTTPURLResponse *)resp;
    return data;
}

static void PrintResult(NSString *label, NSHTTPURLResponse *resp, NSData *data, NSError *err) {
    if (err) {
        printf("  FAIL %s: %s %ld %s\n", label.UTF8String, err.domain.UTF8String, (long)err.code,
               err.localizedDescription.UTF8String);
    } else {
        printf("  OK   %s: HTTP %ld, %lu bytes\n", label.UTF8String, (long)resp.statusCode,
               (unsigned long)data.length);
    }
}

static BOOL StepTLS(NSString *label, NSString *url) {
    NSMutableURLRequest *req = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:url]];
    NSHTTPURLResponse *resp = nil;
    NSError *err = nil;
    NSData *data = Fetch(req, &resp, &err);
    PrintResult(label, resp, data, err);
    return err == nil;
}

static NSDictionary *Client(NSString *name) {
    if ([name isEqualToString:@"IOS"]) {
        return @{ @"id": @"5",
                  @"ua": @"com.google.ios.youtube/20.10.4 (iPhone16,2; U; CPU iOS 18_3_2 like Mac OS X;)",
                  @"client": @{ @"clientName": @"IOS", @"clientVersion": @"20.10.4",
                                @"deviceMake": @"Apple", @"deviceModel": @"iPhone16,2",
                                @"osName": @"iPhone", @"osVersion": @"18.3.2.22D82",
                                @"hl": @"en", @"gl": @"US" } };
    }
    return @{ @"id": @"28",
              @"ua": @"com.google.android.apps.youtube.vr.oculus/1.62.27 (Linux; U; Android 12L; eureka-user Build/SQ3A.220605.009.A1) gzip",
              @"client": @{ @"clientName": @"ANDROID_VR", @"clientVersion": @"1.62.27",
                            @"deviceMake": @"Oculus", @"deviceModel": @"Quest 3",
                            @"androidSdkVersion": @32, @"osName": @"Android", @"osVersion": @"12L",
                            @"hl": @"en", @"gl": @"US" } };
}

// Returns the player response, or nil.
static NSDictionary *StepPlayer(NSString *clientName, NSString *videoId) {
    NSDictionary *c = Client(clientName);
    NSDictionary *body = @{ @"context": @{ @"client": c[@"client"] },
                            @"videoId": videoId,
                            @"contentCheckOk": @YES, @"racyCheckOk": @YES };
    NSURL *url = [NSURL URLWithString:@"https://www.youtube.com/youtubei/v1/player?prettyPrint=false"];
    NSMutableURLRequest *req = [NSMutableURLRequest requestWithURL:url];
    req.HTTPMethod = @"POST";
    req.HTTPBody = [NSJSONSerialization dataWithJSONObject:body options:0 error:NULL];
    [req setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
    [req setValue:c[@"ua"] forHTTPHeaderField:@"User-Agent"];
    [req setValue:c[@"id"] forHTTPHeaderField:@"X-YouTube-Client-Name"];
    [req setValue:c[@"client"][@"clientVersion"] forHTTPHeaderField:@"X-YouTube-Client-Version"];

    NSHTTPURLResponse *resp = nil;
    NSError *err = nil;
    NSData *data = Fetch(req, &resp, &err);
    PrintResult([NSString stringWithFormat:@"/player as %@", clientName], resp, data, err);
    if (err || !data) return nil;

    NSDictionary *json = [NSJSONSerialization JSONObjectWithData:data options:0 error:NULL];
    if (![json isKindOfClass:[NSDictionary class]]) {
        printf("    response is not JSON\n");
        return nil;
    }
    NSDictionary *ps = json[@"playabilityStatus"];
    printf("    playability: %s %s\n", [ps[@"status"] description].UTF8String,
           ps[@"reason"] ? [ps[@"reason"] description].UTF8String : "");
    NSDictionary *sd = json[@"streamingData"];
    NSArray *all = [(sd[@"formats"] ?: @[]) arrayByAddingObjectsFromArray:(sd[@"adaptiveFormats"] ?: @[])];
    int direct = 0, ciphered = 0, avc = 0;
    for (NSDictionary *f in all) {
        BOOL muxed = [sd[@"formats"] containsObject:f];
        printf("      itag %-3s %-5s %-6s %s\n", [f[@"itag"] description].UTF8String,
               [(f[@"qualityLabel"] ?: @"audio") description].UTF8String, muxed ? "muxed" : "",
               [f[@"mimeType"] description].UTF8String);
        if (f[@"url"]) direct++;
        if (f[@"signatureCipher"] || f[@"cipher"]) ciphered++;
        if ([f[@"mimeType"] rangeOfString:@"avc1"].location != NSNotFound) avc++;
    }
    printf("    formats: %lu total, %d direct URL, %d ciphered, %d H.264\n",
           (unsigned long)all.count, direct, ciphered, avc);
    printf("    hlsManifestUrl: %s\n", sd[@"hlsManifestUrl"] ? "yes" : "no");
    return sd ? json : nil;
}

static void StepStream(NSString *label, NSString *url) {
    NSMutableURLRequest *req = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:url]];
    [req setValue:@"bytes=0-4095" forHTTPHeaderField:@"Range"];
    NSHTTPURLResponse *resp = nil;
    NSError *err = nil;
    NSData *data = Fetch(req, &resp, &err);
    PrintResult(label, resp, data, err);
    if (!err && data.length) {
        NSString *head = [[NSString alloc] initWithData:[data subdataWithRange:NSMakeRange(0, MIN(data.length, 60))]
                                               encoding:NSASCIIStringEncoding];
        const unsigned char *b = data.bytes;
        printf("    first bytes:");
        for (NSUInteger i = 0; i < MIN(data.length, 12); i++) printf(" %02x", b[i]);
        printf("  %s\n", [[head stringByReplacingOccurrencesOfString:@"\n" withString:@" "] UTF8String] ?: "");
    }
}

int main(int argc, char **argv) {
    @autoreleasepool {
        NSString *videoId = argc > 1 ? @(argv[1]) : @"jNQXAC9IVRw";

        printf("Step 1: system TLS\n");
        StepTLS(@"www.youtube.com", @"https://www.youtube.com/robots.txt");
        StepTLS(@"youtubei.googleapis.com", @"https://youtubei.googleapis.com/generate_204");
        StepTLS(@"i.ytimg.com", [NSString stringWithFormat:@"https://i.ytimg.com/vi/%@/mqdefault.jpg", videoId]);

        printf("Step 2: InnerTube /player for %s\n", videoId.UTF8String);
        NSDictionary *found = nil;
        for (NSString *name in @[ @"IOS", @"ANDROID_VR" ]) {
            NSDictionary *r = StepPlayer(name, videoId);
            if (r && !found) found = r;
        }

        printf("Step 3: stream bytes\n");
        if (!found) {
            printf("  SKIP: no client returned streamingData\n");
            return 1;
        }
        NSDictionary *sd = found[@"streamingData"];
        if (sd[@"hlsManifestUrl"]) StepStream(@"HLS manifest", sd[@"hlsManifestUrl"]);
        NSArray *all = [(sd[@"formats"] ?: @[]) arrayByAddingObjectsFromArray:(sd[@"adaptiveFormats"] ?: @[])];
        for (NSDictionary *f in all) {
            if (f[@"url"] && [f[@"mimeType"] rangeOfString:@"avc1"].location != NSNotFound) {
                StepStream([NSString stringWithFormat:@"itag %@ (%@)", f[@"itag"], f[@"qualityLabel"] ?: @"?"], f[@"url"]);
                break;
            }
        }
    }
    return 0;
}
