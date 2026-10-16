// Reads the answer of the InnerTube /next API (MWEB): the details of a video
// and its related videos.

#import <Foundation/Foundation.h>
#import "RTModels.h"

@interface RTNextInfo : NSObject
@property (nonatomic, copy) NSString *title;
@property (nonatomic, copy) NSString *viewsText;        // "904,270,011 views"
@property (nonatomic, copy) NSString *publishDateText;  // "Dec 6, 2013"
@property (nonatomic, copy) NSString *likesText;        // "4M"
@property (nonatomic, copy) NSString *descriptionText;  // YouTube shortens the links in it
@property (nonatomic, strong) RTChannel *channel;       // With the avatar and the subscribers
@property (nonatomic, strong) RTPage *related;          // The related videos, with no channels
@end

RTNextInfo *RTParseNext(NSDictionary *json);
