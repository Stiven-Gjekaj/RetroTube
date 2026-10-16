#import "RTNext.h"
#import "RTParse.h"

@implementation RTNextInfo
@end

// Returns the first value of the key in the tree, or nil. The keys in this
// file are found only one time in an answer, so the order of the search
// does not change the result.
static id RTFind(id node, NSString *key) {
    if ([node isKindOfClass:[NSDictionary class]]) {
        id value = node[key];
        if (value) return value;
        for (id child in [node allValues]) {
            id found = RTFind(child, key);
            if (found) return found;
        }
    } else if ([node isKindOfClass:[NSArray class]]) {
        for (id child in node) {
            id found = RTFind(child, key);
            if (found) return found;
        }
    }
    return nil;
}

static NSDictionary *RTFindDict(id node, NSString *key) {
    id value = RTFind(node, key);
    return [value isKindOfClass:[NSDictionary class]] ? value : nil;
}

RTNextInfo *RTParseNext(NSDictionary *json) {
    RTNextInfo *info = [RTNextInfo new];
    NSDictionary *header = RTFindDict(json, @"videoDescriptionHeaderRenderer");
    NSDictionary *slim = RTFindDict(json, @"slimVideoInformationRenderer");
    info.title = RTText(header[@"title"]) ?: RTText(slim[@"title"]);
    info.viewsText = RTText(header[@"views"]);
    info.publishDateText = RTText(header[@"publishDate"]);

    NSDictionary *sentiment = RTFindDict(json, @"sentimentFactoidRenderer");
    NSDictionary *liked = RTFindDict(sentiment, @"factoidRenderer");
    info.likesText = RTText(liked[@"value"]);

    NSDictionary *body = RTFindDict(json, @"expandableVideoDescriptionBodyRenderer");
    id attributed = body[@"attributedDescriptionBodyText"];
    if ([attributed isKindOfClass:[NSDictionary class]] && [attributed[@"content"] isKindOfClass:[NSString class]]) {
        info.descriptionText = attributed[@"content"];
    } else {
        info.descriptionText = RTText(body[@"descriptionBodyText"]);
    }

    NSDictionary *owner = RTFindDict(json, @"slimOwnerRenderer");
    if (owner) {
        RTChannel *channel = [RTChannel new];
        NSString *browseId = RTFind(owner[@"title"], @"browseId");
        if (![browseId isKindOfClass:[NSString class]]) browseId = RTFind(owner[@"navigationEndpoint"], @"browseId");
        channel.channelId = [browseId isKindOfClass:[NSString class]] ? browseId : nil;
        channel.title = [owner[@"channelName"] isKindOfClass:[NSString class]] ? owner[@"channelName"] : RTText(owner[@"title"]);
        NSString *subscribers = RTText(owner[@"expandedSubtitle"]) ?: RTText(owner[@"collapsedSubtitle"]);
        // MWEB gives only the number, for example "7.2M".
        if (subscribers.length && [subscribers rangeOfString:@" "].location == NSNotFound) {
            subscribers = [subscribers stringByAppendingString:@" subscribers"];
        }
        channel.subscribersText = subscribers;
        channel.avatarURL = RTThumbnailURL(owner[@"thumbnail"], 88);
        if (channel.channelId) info.channel = channel;
    }

    RTPage *page = RTParsePage(json);
    NSMutableArray *videos = [NSMutableArray array];
    for (id item in page.items) {
        if ([item isKindOfClass:[RTVideo class]]) [videos addObject:item];
    }
    page.items = videos;
    info.related = page;
    return info;
}
