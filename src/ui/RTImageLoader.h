// Loads images from the network and keeps them in memory.

#import <UIKit/UIKit.h>

@interface RTImageLoader : NSObject

+ (instancetype)shared;

// Returns the image if it is in memory, or nil.
- (UIImage *)cachedImageForURL:(NSURL *)url;

// Loads the image. The handler runs on the main queue, also when the load fails.
- (void)loadURL:(NSURL *)url handler:(void (^)(UIImage *image))handler;

@end
