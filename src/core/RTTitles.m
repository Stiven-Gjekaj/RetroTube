#import "RTTitles.h"

NSURL *RTOEmbedURL(NSString *videoId) {
    NSString *url = [NSString stringWithFormat:
        @"https://www.youtube.com/oembed?format=json&url=https%%3A%%2F%%2Fwww.youtube.com%%2Fwatch%%3Fv%%3D%@", videoId];
    return [NSURL URLWithString:url];
}

NSString *RTParseOEmbedTitle(NSData *data) {
    if (!data) return nil;
    id json = [NSJSONSerialization JSONObjectWithData:data options:0 error:NULL];
    if (![json isKindOfClass:[NSDictionary class]]) return nil;
    id title = json[@"title"];
    return [title isKindOfClass:[NSString class]] && [title length] ? title : nil;
}

void RTLoadOriginalTitles(NSArray *videoIds, void (^handler)(NSDictionary *titles)) {
    NSMutableDictionary *titles = [NSMutableDictionary dictionary];
    if (!videoIds.count) {
        dispatch_async(dispatch_get_main_queue(), ^{ handler(titles); });
        return;
    }
    NSOperationQueue *queue = [NSOperationQueue new];
    queue.maxConcurrentOperationCount = 4;
    __block NSUInteger left = videoIds.count;
    for (NSString *videoId in videoIds) {
        [queue addOperationWithBlock:^{
            NSURLRequest *request = [NSURLRequest requestWithURL:RTOEmbedURL(videoId)
                                                     cachePolicy:NSURLRequestReturnCacheDataElseLoad
                                                 timeoutInterval:15];
            NSHTTPURLResponse *response = nil;
            NSData *data = [NSURLConnection sendSynchronousRequest:request returningResponse:(NSURLResponse **)&response
                                                             error:NULL];
            NSString *title = response.statusCode == 200 ? RTParseOEmbedTitle(data) : nil;
            @synchronized (titles) {
                if (title) titles[videoId] = title;
                if (--left > 0) return;
            }
            NSDictionary *result = [titles copy];
            dispatch_async(dispatch_get_main_queue(), ^{ handler(result); });
        }];
    }
}
