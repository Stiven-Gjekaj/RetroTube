#import "RTVideoCell.h"
#import "RTImageLoader.h"

static const CGFloat RTThumbWidth = 120;
static const CGFloat RTThumbHeight = 68;
static const CGFloat RTMargin = 6;

@interface RTVideoCell ()
@property (nonatomic, strong) UIImageView *thumb;
@property (nonatomic, strong) UILabel *title;
@property (nonatomic, strong) UILabel *details;
@property (nonatomic, strong) UILabel *length;
@property (nonatomic, copy) NSURL *imageURL;
@end

@implementation RTVideoCell

+ (CGFloat)height {
    return RTThumbHeight + 2 * RTMargin;
}

- (instancetype)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier {
    if ((self = [super initWithStyle:style reuseIdentifier:reuseIdentifier])) {
        _thumb = [[UIImageView alloc] initWithFrame:CGRectMake(RTMargin, RTMargin, RTThumbWidth, RTThumbHeight)];
        _thumb.contentMode = UIViewContentModeScaleAspectFill;
        _thumb.clipsToBounds = YES;
        _thumb.backgroundColor = [UIColor colorWithWhite:0.85 alpha:1];
        [self.contentView addSubview:_thumb];

        _length = [UILabel new];
        _length.font = [UIFont boldSystemFontOfSize:11];
        _length.textColor = [UIColor whiteColor];
        _length.backgroundColor = [UIColor colorWithWhite:0 alpha:0.75];
        _length.textAlignment = NSTextAlignmentCenter;
        [_thumb addSubview:_length];

        _title = [UILabel new];
        _title.font = [UIFont boldSystemFontOfSize:14];
        _title.numberOfLines = 2;
        _title.backgroundColor = [UIColor clearColor];
        _title.highlightedTextColor = [UIColor whiteColor];
        [self.contentView addSubview:_title];

        _details = [UILabel new];
        _details.font = [UIFont systemFontOfSize:12];
        _details.textColor = [UIColor grayColor];
        _details.numberOfLines = 2;
        _details.backgroundColor = [UIColor clearColor];
        _details.highlightedTextColor = [UIColor whiteColor];
        [self.contentView addSubview:_details];
    }
    return self;
}

- (void)layoutSubviews {
    [super layoutSubviews];
    CGFloat left = RTMargin * 2 + RTThumbWidth;
    CGFloat width = self.contentView.bounds.size.width - left - RTMargin;
    CGSize titleSize = [self.title.text sizeWithFont:self.title.font constrainedToSize:CGSizeMake(width, 36)
                                       lineBreakMode:NSLineBreakByTruncatingTail];
    self.title.frame = CGRectMake(left, RTMargin, width, titleSize.height);
    CGFloat top = RTMargin + titleSize.height + 2;
    self.details.frame = CGRectMake(left, top, width, RTThumbHeight + RTMargin - top);
    [self.details sizeToFit];
    CGRect frame = self.details.frame;
    frame.size.width = width;
    self.details.frame = frame;

    [self.length sizeToFit];
    CGSize size = self.length.bounds.size;
    self.length.frame = CGRectMake(RTThumbWidth - size.width - 8, RTThumbHeight - size.height - 2,
                                   size.width + 6, size.height);
}

- (void)prepareForReuse {
    [super prepareForReuse];
    self.thumb.image = nil;
    self.imageURL = nil;
}

- (void)loadImage:(NSURL *)url {
    self.imageURL = url;
    UIImage *cached = [[RTImageLoader shared] cachedImageForURL:url];
    self.thumb.image = cached;
    if (cached || !url) return;
    __weak RTVideoCell *weakSelf = self;
    [[RTImageLoader shared] loadURL:url handler:^(UIImage *image) {
        // The cell can show another item now. Check the URL.
        if ([weakSelf.imageURL isEqual:url]) weakSelf.thumb.image = image;
    }];
}

static NSString *RTJoin(NSArray *parts) {
    NSMutableArray *present = [NSMutableArray array];
    for (id part in parts) {
        if ([part isKindOfClass:[NSString class]] && [part length]) [present addObject:part];
    }
    return [present componentsJoinedByString:@" · "];
}

- (void)showVideo:(RTVideo *)video {
    self.title.text = video.title;
    self.details.text = [NSString stringWithFormat:@"%@\n%@", video.channelName ?: @"",
                         RTJoin(@[ video.viewsText ?: [NSNull null], video.publishedText ?: [NSNull null] ])];
    self.length.text = video.lengthText ?: @"LIVE";
    self.length.hidden = NO;
    self.thumb.frame = CGRectMake(RTMargin, RTMargin, RTThumbWidth, RTThumbHeight);
    [self loadImage:video.thumbnailURL];
    [self setNeedsLayout];
}

- (void)showChannel:(RTChannel *)channel {
    self.title.text = channel.title;
    self.details.text = RTJoin(@[ channel.handle ?: [NSNull null], channel.subscribersText ?: [NSNull null] ]);
    self.length.hidden = YES;
    // A channel picture is round on YouTube. Here it is a square in the middle.
    CGFloat side = RTThumbHeight;
    self.thumb.frame = CGRectMake(RTMargin + (RTThumbWidth - side) / 2, RTMargin, side, side);
    [self loadImage:channel.avatarURL];
    [self setNeedsLayout];
}

@end
