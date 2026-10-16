#import "RTParse.h"

static NSDictionary *RTDict(id object) {
    return [object isKindOfClass:[NSDictionary class]] ? object : nil;
}

static NSArray *RTArray(id object) {
    return [object isKindOfClass:[NSArray class]] ? object : nil;
}

static NSString *RTString(id object) {
    return [object isKindOfClass:[NSString class]] ? object : nil;
}

NSString *RTText(id textObject) {
    NSDictionary *dict = RTDict(textObject);
    if (!dict) return nil;
    NSString *simple = RTString(dict[@"simpleText"]);
    if (simple) return simple;
    NSArray *runs = RTArray(dict[@"runs"]);
    if (!runs) return nil;
    NSMutableString *text = [NSMutableString string];
    for (id run in runs) {
        NSString *part = RTString(RTDict(run)[@"text"]);
        if (part) [text appendString:part];
    }
    return text.length ? text : nil;
}

NSURL *RTThumbnailURL(id thumbnailObject, NSInteger maxWidth) {
    NSArray *list = RTArray(RTDict(thumbnailObject)[@"thumbnails"]);
    NSDictionary *best = nil, *narrowest = nil;
    for (id item in list) {
        NSDictionary *thumb = RTDict(item);
        if (!RTString(thumb[@"url"])) continue;
        NSInteger width = [thumb[@"width"] integerValue];
        if (!narrowest || width < [narrowest[@"width"] integerValue]) narrowest = thumb;
        if (width <= maxWidth && (!best || width > [best[@"width"] integerValue])) best = thumb;
    }
    NSString *url = (best ?: narrowest)[@"url"];
    if (!url) return nil;
    if ([url hasPrefix:@"//"]) url = [@"https:" stringByAppendingString:url];
    return [NSURL URLWithString:url];
}

// Returns the channel ID of the first run that opens a channel.
static NSString *RTChannelIdOfRuns(id textObject) {
    for (id run in RTArray(RTDict(textObject)[@"runs"])) {
        NSString *browseId = RTString(RTDict(RTDict(RTDict(run)[@"navigationEndpoint"])[@"browseEndpoint"])[@"browseId"]);
        if ([browseId hasPrefix:@"UC"]) return browseId;
    }
    return nil;
}

static RTVideo *RTParseVideo(NSDictionary *r) {
    NSString *videoId = RTString(r[@"videoId"]);
    if (!videoId) return nil;
    RTVideo *video = [RTVideo new];
    video.videoId = videoId;
    video.title = RTText(r[@"headline"]) ?: RTText(r[@"title"]);
    id byline = r[@"shortBylineText"] ?: r[@"longBylineText"];
    video.channelName = RTText(byline);
    video.channelId = RTChannelIdOfRuns(byline);
    video.lengthText = RTText(r[@"lengthText"]);
    video.viewsText = RTText(r[@"shortViewCountText"]) ?: RTText(r[@"viewCountText"]);
    video.publishedText = RTText(r[@"publishedTimeText"]);
    video.thumbnailURL = RTThumbnailURL(r[@"thumbnail"], 320);
    return video;
}

static RTChannel *RTParseChannel(NSDictionary *r) {
    NSString *channelId = RTString(r[@"channelId"]);
    if (!channelId) return nil;
    RTChannel *channel = [RTChannel new];
    channel.channelId = channelId;
    channel.title = RTText(r[@"title"]) ?: RTText(r[@"displayName"]);
    // MWEB puts the handle in subscriberCountText and the subscribers in
    // videoCountText. Find each one by its form.
    for (NSString *key in @[ @"subscriberCountText", @"videoCountText" ]) {
        NSString *text = RTText(r[key]);
        if ([text hasPrefix:@"@"]) channel.handle = text;
        else if ([text rangeOfString:@"subscriber"].location != NSNotFound) channel.subscribersText = text;
    }
    channel.avatarURL = RTThumbnailURL(r[@"thumbnail"], 176);
    return channel;
}

// The state of one walk through an answer.
@interface RTWalkState : NSObject
@property (nonatomic, strong) NSMutableArray *items;
@property (nonatomic, strong) NSMutableSet *seen;
@property (nonatomic, copy) NSString *continuation;
@property (nonatomic) NSUInteger continuationScore;
@end

@implementation RTWalkState
@end

static NSString *RTContinuationToken(NSDictionary *continuationItem) {
    NSDictionary *endpoint = RTDict(continuationItem[@"continuationEndpoint"]);
    NSString *token = RTString(RTDict(endpoint[@"continuationCommand"])[@"token"]);
    if (token) return token;
    // MWEB can put the command one level lower, in a list of commands.
    for (id command in RTArray(RTDict(endpoint[@"commandExecutorCommand"])[@"commands"])) {
        token = RTString(RTDict(RTDict(command)[@"continuationCommand"])[@"token"]);
        if (token) return token;
    }
    return nil;
}

// Adds the items under node to the state. Returns the number of items that
// are under node. An array can hold the items of a list and a
// continuationItemRenderer for the next page. The token of the array with the
// most items is the continuation of the page.
static NSUInteger RTWalk(id node, RTWalkState *state) {
    if (RTArray(node)) {
        NSUInteger count = 0;
        NSString *token = nil;
        for (id child in node) {
            NSDictionary *continuationItem = RTDict(RTDict(child)[@"continuationItemRenderer"]);
            if (continuationItem) token = RTContinuationToken(continuationItem) ?: token;
            else count += RTWalk(child, state);
        }
        if (token && (!state.continuation || count > state.continuationScore)) {
            state.continuation = token;
            state.continuationScore = count;
        }
        return count;
    }
    if (!RTDict(node)) return 0;
    __block NSUInteger count = 0;
    [(NSDictionary *)node enumerateKeysAndObjectsUsingBlock:^(NSString *key, id value, BOOL *stop) {
        id item = nil;
        if ([key isEqualToString:@"videoWithContextRenderer"] || [key isEqualToString:@"compactVideoRenderer"] ||
            [key isEqualToString:@"videoRenderer"]) {
            item = RTDict(value) ? RTParseVideo(value) : nil;
        } else if ([key isEqualToString:@"compactChannelRenderer"] || [key isEqualToString:@"channelRenderer"]) {
            item = RTDict(value) ? RTParseChannel(value) : nil;
        }
        if (item) {
            count++;
            if (![state.seen containsObject:item]) {
                [state.seen addObject:item];
                [state.items addObject:item];
            }
        } else {
            count += RTWalk(value, state);
        }
    }];
    return count;
}

RTPage *RTParsePage(NSDictionary *json) {
    RTWalkState *state = [RTWalkState new];
    state.items = [NSMutableArray array];
    state.seen = [NSMutableSet set];
    RTWalk(json, state);
    RTPage *page = [RTPage new];
    page.items = state.items;
    page.continuation = state.continuation;
    return page;
}
