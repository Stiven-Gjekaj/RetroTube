// Keeps the subscriptions and the history on the phone.
// Each change writes the file at once. Use the store on the main thread.

#import <Foundation/Foundation.h>
#import "RTModels.h"

// Posted after each change. The object is the store.
extern NSString *const RTStoreDidChangeNotification;

// The longest history. The oldest videos go first.
extern const NSUInteger RTHistoryLimit;

@interface RTStore : NSObject

// Keeps the files in Library/Application Support/RetroTube.
+ (instancetype)shared;

// Tests give a directory of their own.
- (instancetype)initWithDirectory:(NSString *)directory;

// Sorted by title, with no difference between capital and small letters.
@property (nonatomic, readonly) NSArray *subscriptions;
- (BOOL)isSubscribed:(NSString *)channelId;
// A second subscribe to the same channel updates its title and picture.
- (void)subscribe:(RTChannel *)channel;
- (void)unsubscribe:(NSString *)channelId;

// Newest first.
@property (nonatomic, readonly) NSArray *history;
// Puts the video at the top. A video that is already in the history moves.
- (void)addToHistory:(RTVideo *)video;
- (void)removeFromHistory:(NSString *)videoId;
- (void)clearHistory;

@end
