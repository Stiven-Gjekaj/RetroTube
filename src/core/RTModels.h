// The objects that the app shows: videos, channels, and pages of them.

#import <Foundation/Foundation.h>

@interface RTVideo : NSObject <NSCoding>
@property (nonatomic, copy) NSString *videoId;
@property (nonatomic, copy) NSString *title;
@property (nonatomic, copy) NSString *channelName;
@property (nonatomic, copy) NSString *channelId;
@property (nonatomic, copy) NSString *lengthText;     // "5:40", or nil for a live video
@property (nonatomic, copy) NSString *viewsText;      // "904M views"
@property (nonatomic, copy) NSString *publishedText;  // "12 years ago"
@property (nonatomic, copy) NSURL *thumbnailURL;
@end

@interface RTChannel : NSObject <NSCoding>
@property (nonatomic, copy) NSString *channelId;
@property (nonatomic, copy) NSString *title;
@property (nonatomic, copy) NSString *handle;           // "@daftpunk"
@property (nonatomic, copy) NSString *subscribersText;  // "7.2M subscribers"
@property (nonatomic, copy) NSURL *avatarURL;
@end

// One page of a list. The items are RTVideo and RTChannel objects.
@interface RTPage : NSObject
@property (nonatomic, copy) NSArray *items;
@property (nonatomic, copy) NSString *continuation;  // nil on the last page
@end
