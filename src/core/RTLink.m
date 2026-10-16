#import "RTLink.h"

@implementation RTLink
@end

static RTLink *RTMakeLink(RTLinkKind kind, NSString *value) {
    RTLink *link = [RTLink new];
    link.kind = value.length ? kind : RTLinkNone;
    link.value = value.length ? value : nil;
    return link;
}

static NSDictionary *RTQuery(NSURL *url) {
    NSMutableDictionary *values = [NSMutableDictionary dictionary];
    for (NSString *pair in [url.query componentsSeparatedByString:@"&"]) {
        NSRange equals = [pair rangeOfString:@"="];
        if (equals.location == NSNotFound) continue;
        NSString *key = [pair substringToIndex:equals.location];
        NSString *value = [[pair substringFromIndex:NSMaxRange(equals)] stringByReplacingOccurrencesOfString:@"+"
                                                                                                  withString:@" "];
        value = [value stringByReplacingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
        if (value && !values[key]) values[key] = value;
    }
    return values;
}

// A video ID has 11 characters from the URL-safe Base64 alphabet.
static NSString *RTVideoId(NSString *text) {
    if (text.length != 11) return nil;
    NSCharacterSet *allowed =
        [NSCharacterSet characterSetWithCharactersInString:@"ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_"];
    return [[text stringByTrimmingCharactersInSet:allowed] length] == 0 ? text : nil;
}

static NSString *RTChannelId(NSString *text) {
    return [text hasPrefix:@"UC"] && text.length == 24 ? text : nil;
}

RTLink *RTParseLink(NSURL *url) {
    NSString *scheme = url.scheme.lowercaseString;
    NSString *host = url.host.lowercaseString;
    NSDictionary *query = RTQuery(url);
    NSArray *parts = [url.path pathComponents];  // "/", "watch", ...
    NSString *first = parts.count > 1 ? parts[1] : nil;
    NSString *second = parts.count > 2 ? parts[2] : nil;

    if ([scheme isEqualToString:@"retrotube"]) {
        if ([host isEqualToString:@"search"]) return RTMakeLink(RTLinkSearch, query[@"q"]);
        if ([host isEqualToString:@"watch"]) return RTMakeLink(RTLinkVideo, RTVideoId(query[@"v"]));
        if ([host isEqualToString:@"channel"]) return RTMakeLink(RTLinkChannel, RTChannelId(query[@"id"]));
        if ([@[ @"popular", @"feed", @"subscriptions", @"history" ] containsObject:host]) return RTMakeLink(RTLinkTab, host);
        return RTMakeLink(RTLinkNone, nil);
    }
    if (![scheme isEqualToString:@"https"] && ![scheme isEqualToString:@"http"]) return RTMakeLink(RTLinkNone, nil);

    if ([host isEqualToString:@"youtu.be"]) return RTMakeLink(RTLinkVideo, RTVideoId(first));
    NSSet *hosts = [NSSet setWithObjects:@"youtube.com", @"www.youtube.com", @"m.youtube.com", @"music.youtube.com", nil];
    if (![hosts containsObject:host]) return RTMakeLink(RTLinkNone, nil);
    if ([first isEqualToString:@"watch"]) return RTMakeLink(RTLinkVideo, RTVideoId(query[@"v"]));
    if ([first isEqualToString:@"shorts"] || [first isEqualToString:@"live"] || [first isEqualToString:@"embed"]) {
        return RTMakeLink(RTLinkVideo, RTVideoId(second));
    }
    if ([first isEqualToString:@"channel"]) return RTMakeLink(RTLinkChannel, RTChannelId(second));
    if ([first isEqualToString:@"results"]) return RTMakeLink(RTLinkSearch, query[@"search_query"]);
    return RTMakeLink(RTLinkNone, nil);
}

RTLink *RTParseText(NSString *text) {
    NSString *trimmed = [text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if (!trimmed.length) return RTMakeLink(RTLinkNone, nil);
    NSString *candidate = trimmed;
    if (![candidate hasPrefix:@"http"] &&
        ([candidate hasPrefix:@"youtu"] || [candidate hasPrefix:@"www.youtu"] || [candidate hasPrefix:@"m.youtu"])) {
        candidate = [@"https://" stringByAppendingString:candidate];
    }
    if ([candidate rangeOfString:@" "].location == NSNotFound) {
        NSURL *url = [NSURL URLWithString:candidate];
        RTLink *link = url ? RTParseLink(url) : nil;
        if (link.kind != RTLinkNone) return link;
    }
    return RTMakeLink(RTLinkSearch, trimmed);
}
