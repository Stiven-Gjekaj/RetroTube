#import "RTImageLoader.h"
#import "RTDiskCache.h"

@interface RTImageLoader ()
@property (nonatomic, strong) NSCache *images;
@property (nonatomic, strong) NSOperationQueue *queue;
@property (nonatomic, strong) RTDiskCache *disk;
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
        // The thumbnails stay on disk between launches. A thumbnail is about
        // 15 KB, so 30 MB holds about 2000 of them.
        NSString *caches = NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES)[0];
        _disk = [[RTDiskCache alloc] initWithDirectory:[caches stringByAppendingPathComponent:@"RetroTube/Images"]
                                                 limit:30 * 1024 * 1024];
        RTDiskCache *disk = _disk;
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0), ^{ [disk trim]; });
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
    [self.queue addOperationWithBlock:^{
        NSString *key = url.absoluteString;
        NSData *data = [self.disk dataForKey:key];
        if (!data) {
            NSURLRequest *request = [NSURLRequest requestWithURL:url cachePolicy:NSURLRequestReturnCacheDataElseLoad
                                                 timeoutInterval:20];
            NSHTTPURLResponse *response = nil;
            data = [NSURLConnection sendSynchronousRequest:request returningResponse:(NSURLResponse **)&response
                                                     error:NULL];
            if (response.statusCode != 200) data = nil;
            if (data) [self.disk setData:data forKey:key];
        }
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
