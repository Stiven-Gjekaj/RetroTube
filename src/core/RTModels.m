#import "RTModels.h"

// Writes and reads each listed property with key-value coding.
static void RTEncode(id object, NSCoder *coder, NSArray *keys) {
    for (NSString *key in keys) [coder encodeObject:[object valueForKey:key] forKey:key];
}

static void RTDecode(id object, NSCoder *coder, NSArray *keys) {
    for (NSString *key in keys) [object setValue:[coder decodeObjectForKey:key] forKey:key];
}

static NSArray *RTVideoKeys(void) {
    return @[ @"videoId", @"title", @"channelName", @"channelId", @"lengthText", @"viewsText",
              @"publishedText", @"thumbnailURL" ];
}

static NSArray *RTChannelKeys(void) {
    return @[ @"channelId", @"title", @"handle", @"subscribersText", @"avatarURL" ];
}

@implementation RTVideo

- (instancetype)initWithCoder:(NSCoder *)coder {
    if ((self = [super init])) RTDecode(self, coder, RTVideoKeys());
    return self;
}

- (void)encodeWithCoder:(NSCoder *)coder {
    RTEncode(self, coder, RTVideoKeys());
}

- (BOOL)isEqual:(id)other {
    return [other isKindOfClass:[RTVideo class]] && [[other videoId] isEqualToString:self.videoId];
}

- (NSUInteger)hash {
    return self.videoId.hash;
}

- (NSString *)description {
    return [NSString stringWithFormat:@"<RTVideo %@ %@>", self.videoId, self.title];
}

@end

@implementation RTChannel

- (instancetype)initWithCoder:(NSCoder *)coder {
    if ((self = [super init])) RTDecode(self, coder, RTChannelKeys());
    return self;
}

- (void)encodeWithCoder:(NSCoder *)coder {
    RTEncode(self, coder, RTChannelKeys());
}

- (BOOL)isEqual:(id)other {
    return [other isKindOfClass:[RTChannel class]] && [[other channelId] isEqualToString:self.channelId];
}

- (NSUInteger)hash {
    return self.channelId.hash;
}

- (NSString *)description {
    return [NSString stringWithFormat:@"<RTChannel %@ %@>", self.channelId, self.title];
}

@end

@implementation RTPage
@end
