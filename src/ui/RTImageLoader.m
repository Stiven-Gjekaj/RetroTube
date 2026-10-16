#import "RTImageLoader.h"

@interface RTImageLoader ()
@property (nonatomic, strong) NSCache *images;
@property (nonatomic, strong) NSOperationQueue *queue;
@end

@implementation RTImageLoader

+ (instancetype)shared {
    static RTImageLoader *shared;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ shared = [RTImageLoader new]; });
    return shared;
}

- (instancetype)init {
    if ((self = [super init])) {
        _images = [NSCache new];
        _images.totalCostLimit = 12 * 1024 * 1024;  // The iPhone 4S has 512 MB.
        _queue = [NSOperationQueue new];
        _queue.maxConcurrentOperationCount = 3;
    }
    return self;
}

- (UIImage *)cachedImageForURL:(NSURL *)url {
    return url ? [self.images objectForKey:url] : nil;
}

- (void)loadURL:(NSURL *)url handler:(void (^)(UIImage *image))handler {
    if (!url) {
        handler(nil);
        return;
    }
    UIImage *cached = [self.images objectForKey:url];
    if (cached) {
        handler(cached);
        return;
    }
    NSURLRequest *request = [NSURLRequest requestWithURL:url cachePolicy:NSURLRequestReturnCacheDataElseLoad
                                         timeoutInterval:20];
    [NSURLConnection sendAsynchronousRequest:request queue:self.queue
                           completionHandler:^(NSURLResponse *response, NSData *data, NSError *error) {
        // Decode the image here, not on the main queue.
        UIImage *image = data ? [UIImage imageWithData:data scale:[UIScreen mainScreen].scale] : nil;
        if (image) {
            UIGraphicsBeginImageContextWithOptions(image.size, YES, image.scale);
            [image drawAtPoint:CGPointZero];
            image = UIGraphicsGetImageFromCurrentImageContext();
            UIGraphicsEndImageContext();
            NSUInteger cost = (NSUInteger)(image.size.width * image.size.height * image.scale * image.scale * 4);
            [self.images setObject:image forKey:url cost:cost];
        }
        dispatch_async(dispatch_get_main_queue(), ^{ handler(image); });
    }];
}

@end
