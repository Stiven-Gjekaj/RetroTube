#import "RTVideoViewController.h"
#import <QuartzCore/QuartzCore.h>
#import "RTChannelViewController.h"
#import "RTImageLoader.h"
#import "RTInnerTube.h"
#import "RTNext.h"
#import "RTPlayback.h"

static const CGFloat RTPadding = 10;

// A round dark button with a white triangle, drawn in code.
@interface RTPlayButton : UIControl
@end

@implementation RTPlayButton

- (instancetype)initWithFrame:(CGRect)frame {
    if ((self = [super initWithFrame:frame])) self.backgroundColor = [UIColor clearColor];
    return self;
}

- (void)setHighlighted:(BOOL)highlighted {
    [super setHighlighted:highlighted];
    [self setNeedsDisplay];
}

- (void)drawRect:(CGRect)rect {
    CGContextRef context = UIGraphicsGetCurrentContext();
    CGRect circle = CGRectInset(self.bounds, 2, 2);
    CGContextSetFillColorWithColor(context, [UIColor colorWithWhite:0 alpha:self.highlighted ? 0.85 : 0.6].CGColor);
    CGContextFillEllipseInRect(context, circle);
    CGContextSetStrokeColorWithColor(context, [UIColor whiteColor].CGColor);
    CGContextSetLineWidth(context, 3);
    CGContextStrokeEllipseInRect(context, circle);
    CGFloat size = circle.size.width * 0.36;
    CGPoint center = CGPointMake(CGRectGetMidX(circle) + size * 0.12, CGRectGetMidY(circle));
    CGContextMoveToPoint(context, center.x - size / 2, center.y - size / 2);
    CGContextAddLineToPoint(context, center.x + size / 2, center.y);
    CGContextAddLineToPoint(context, center.x - size / 2, center.y + size / 2);
    CGContextClosePath(context);
    CGContextSetFillColorWithColor(context, [UIColor whiteColor].CGColor);
    CGContextFillPath(context);
}

@end

@interface RTVideoViewController ()
@property (nonatomic, strong) RTVideo *video;
@property (nonatomic, strong) RTNextInfo *details;
@property (nonatomic, strong) RTPlayerInfo *playerInfo;
@property (nonatomic, copy) NSString *fullDescription;
@property (nonatomic) BOOL descriptionOpen;
@property (nonatomic, strong) UIView *header;
@property (nonatomic, strong) UIImageView *picture;
@property (nonatomic, strong) UILabel *titleLabel;
@property (nonatomic, strong) UILabel *statsLabel;
@property (nonatomic, strong) UIControl *channelRow;
@property (nonatomic, strong) UIImageView *avatar;
@property (nonatomic, strong) UILabel *channelLabel;
@property (nonatomic, strong) UILabel *subscribersLabel;
@property (nonatomic, strong) UILabel *descriptionLabel;
@property (nonatomic, strong) UIButton *moreButton;
@end

@implementation RTVideoViewController

- (instancetype)initWithVideo:(RTVideo *)video {
    if ((self = [super init])) {
        _video = video;
        self.title = @"Video";
        self.continuationEndpoint = @"next";
        self.emptyText = @"";
        self.firstRequest = [[RTInnerTube shared] nextRequest:video.videoId];
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.refreshControl = nil;
    [self buildHeader];
    [self layoutHeader];
    // Load the streams now, so that play starts faster.
    __weak RTVideoViewController *weakSelf = self;
    [[RTInnerTube shared] loadPlayer:self.video.videoId handler:^(RTPlayerInfo *info, NSError *error) {
        weakSelf.playerInfo = info;
        if (info.shortDescription.length) weakSelf.fullDescription = info.shortDescription;
        if (!weakSelf.video.title && info.title) weakSelf.video.title = info.title;
        [weakSelf layoutHeader];
    }];
}

- (UILabel *)label:(UIFont *)font color:(UIColor *)color lines:(NSInteger)lines {
    UILabel *label = [UILabel new];
    label.font = font;
    label.textColor = color;
    label.numberOfLines = lines;
    label.backgroundColor = [UIColor clearColor];
    return label;
}

- (void)buildHeader {
    self.header = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 320, 300)];
    self.header.backgroundColor = [UIColor whiteColor];

    self.picture = [[UIImageView alloc] initWithFrame:CGRectMake(0, 0, 320, 180)];
    self.picture.backgroundColor = [UIColor blackColor];
    self.picture.contentMode = UIViewContentModeScaleAspectFill;
    self.picture.clipsToBounds = YES;
    self.picture.userInteractionEnabled = YES;
    [self.picture addGestureRecognizer:[[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(play)]];
    [self.header addSubview:self.picture];
    RTPlayButton *play = [[RTPlayButton alloc] initWithFrame:CGRectMake(0, 0, 64, 64)];
    play.center = CGPointMake(160, 90);
    [play addTarget:self action:@selector(play) forControlEvents:UIControlEventTouchUpInside];
    [self.picture addSubview:play];
    // The large picture of YouTube is at a fixed URL for each video.
    NSURL *large = [NSURL URLWithString:[NSString stringWithFormat:@"https://i.ytimg.com/vi/%@/hqdefault.jpg",
                                         self.video.videoId]];
    self.picture.image = [[RTImageLoader shared] cachedImageForURL:self.video.thumbnailURL];
    __weak RTVideoViewController *weakSelf = self;
    [[RTImageLoader shared] loadURL:large handler:^(UIImage *image) {
        if (image) weakSelf.picture.image = image;
    }];

    self.titleLabel = [self label:[UIFont boldSystemFontOfSize:16] color:[UIColor blackColor] lines:0];
    [self.header addSubview:self.titleLabel];
    self.statsLabel = [self label:[UIFont systemFontOfSize:13] color:[UIColor grayColor] lines:0];
    [self.header addSubview:self.statsLabel];

    self.channelRow = [UIControl new];
    [self.channelRow addTarget:self action:@selector(openChannel) forControlEvents:UIControlEventTouchUpInside];
    self.avatar = [[UIImageView alloc] initWithFrame:CGRectMake(RTPadding, 6, 36, 36)];
    self.avatar.backgroundColor = [UIColor colorWithWhite:0.85 alpha:1];
    self.avatar.layer.cornerRadius = 4;
    self.avatar.clipsToBounds = YES;
    [self.channelRow addSubview:self.avatar];
    self.channelLabel = [self label:[UIFont boldSystemFontOfSize:14] color:[UIColor blackColor] lines:1];
    self.channelLabel.frame = CGRectMake(56, 6, 230, 18);
    [self.channelRow addSubview:self.channelLabel];
    self.subscribersLabel = [self label:[UIFont systemFontOfSize:12] color:[UIColor grayColor] lines:1];
    self.subscribersLabel.frame = CGRectMake(56, 24, 230, 16);
    [self.channelRow addSubview:self.subscribersLabel];
    UILabel *arrow = [self label:[UIFont boldSystemFontOfSize:20] color:[UIColor lightGrayColor] lines:1];
    arrow.text = @"\u203a";
    arrow.frame = CGRectMake(296, 10, 14, 26);
    [self.channelRow addSubview:arrow];
    [self.header addSubview:self.channelRow];

    self.descriptionLabel = [self label:[UIFont systemFontOfSize:13] color:[UIColor darkGrayColor] lines:4];
    [self.header addSubview:self.descriptionLabel];
    self.moreButton = [UIButton buttonWithType:UIButtonTypeCustom];
    self.moreButton.titleLabel.font = [UIFont boldSystemFontOfSize:13];
    [self.moreButton setTitleColor:[UIColor colorWithRed:0.2 green:0.35 blue:0.65 alpha:1] forState:UIControlStateNormal];
    self.moreButton.contentHorizontalAlignment = UIControlContentHorizontalAlignmentLeft;
    [self.moreButton addTarget:self action:@selector(toggleDescription) forControlEvents:UIControlEventTouchUpInside];
    [self.header addSubview:self.moreButton];
}

static NSString *RTJoinParts(NSArray *parts) {
    NSMutableArray *present = [NSMutableArray array];
    for (id part in parts) {
        if ([part isKindOfClass:[NSString class]] && [part length]) [present addObject:part];
    }
    return [present componentsJoinedByString:@" \u00b7 "];
}

static UIView *RTLine(CGFloat y) {
    UIView *line = [[UIView alloc] initWithFrame:CGRectMake(0, y, 320, 1)];
    line.backgroundColor = [UIColor colorWithWhite:0.88 alpha:1];
    return line;
}

// Sets the text of each label and puts the labels one under the other.
- (void)layoutHeader {
    if (!self.header) return;
    for (UIView *view in self.header.subviews) {
        if (view.tag == 1) [view removeFromSuperview];
    }
    CGFloat width = 320 - 2 * RTPadding;
    CGFloat y = 180 + RTPadding;

    self.titleLabel.text = self.details.title ?: self.video.title;
    CGSize size = [self.titleLabel.text sizeWithFont:self.titleLabel.font constrainedToSize:CGSizeMake(width, 200)];
    self.titleLabel.frame = CGRectMake(RTPadding, y, width, size.height);
    y += size.height + 4;

    NSString *likes = self.details.likesText.length ? [self.details.likesText stringByAppendingString:@" likes"] : nil;
    self.statsLabel.text = RTJoinParts(@[ self.details.viewsText ?: self.video.viewsText ?: [NSNull null],
                                          self.details.publishDateText ?: self.video.publishedText ?: [NSNull null],
                                          likes ?: [NSNull null] ]);
    size = [self.statsLabel.text sizeWithFont:self.statsLabel.font constrainedToSize:CGSizeMake(width, 60)];
    self.statsLabel.frame = CGRectMake(RTPadding, y, width, size.height);
    y += size.height + RTPadding;

    RTChannel *channel = self.details.channel;
    UIView *top = RTLine(y);
    top.tag = 1;
    [self.header addSubview:top];
    self.channelRow.frame = CGRectMake(0, y + 1, 320, 48);
    self.channelLabel.text = channel.title ?: self.video.channelName;
    self.subscribersLabel.text = channel.subscribersText;
    self.channelRow.enabled = channel.channelId != nil || self.video.channelId != nil;
    if (channel.avatarURL && !self.avatar.image) {
        __weak RTVideoViewController *weakSelf = self;
        [[RTImageLoader shared] loadURL:channel.avatarURL handler:^(UIImage *image) { weakSelf.avatar.image = image; }];
    }
    y += 49;
    UIView *bottom = RTLine(y);
    bottom.tag = 1;
    [self.header addSubview:bottom];
    y += RTPadding;

    NSString *text = self.fullDescription ?: self.details.descriptionText;
    self.descriptionLabel.text = text;
    self.descriptionLabel.numberOfLines = self.descriptionOpen ? 0 : 4;
    CGFloat limit = self.descriptionOpen ? 10000 : self.descriptionLabel.font.lineHeight * 4 + 1;
    size = [text sizeWithFont:self.descriptionLabel.font constrainedToSize:CGSizeMake(width, limit)];
    self.descriptionLabel.frame = CGRectMake(RTPadding, y, width, size.height);
    y += size.height;
    CGSize full = [text sizeWithFont:self.descriptionLabel.font constrainedToSize:CGSizeMake(width, 10000)];
    BOOL needsMore = full.height > size.height + 1 || self.descriptionOpen;
    self.moreButton.hidden = !needsMore;
    [self.moreButton setTitle:self.descriptionOpen ? @"Less" : @"More" forState:UIControlStateNormal];
    if (needsMore) {
        self.moreButton.frame = CGRectMake(RTPadding, y, 80, 28);
        y += 28;
    }
    y += text.length ? RTPadding : 0;

    UILabel *related = [self label:[UIFont boldSystemFontOfSize:13] color:[UIColor whiteColor] lines:1];
    related.tag = 1;
    related.backgroundColor = [UIColor colorWithRed:0.47 green:0.53 blue:0.62 alpha:1];
    related.text = @"  Related videos";
    related.frame = CGRectMake(0, y, 320, 22);
    [self.header addSubview:related];
    y += 22;

    self.header.frame = CGRectMake(0, 0, 320, y);
    self.tableView.tableHeaderView = self.header;
}

- (id)resultFromJSON:(NSDictionary *)json {
    return RTParseNext(json);
}

- (RTPage *)pageFromResult:(RTNextInfo *)result {
    // A continuation answer has no details. Keep the details of the first page.
    if (result.title) {
        self.details = result;
        if (result.channel) {
            self.video.channelId = self.video.channelId ?: result.channel.channelId;
            self.video.channelName = self.video.channelName ?: result.channel.title;
        }
        if (!self.video.title) self.video.title = result.title;
        [self layoutHeader];
    }
    return result.related;
}

- (void)play {
    [RTPlayback playVideo:self.video info:self.playerInfo from:self];
}

- (void)openChannel {
    RTChannel *channel = self.details.channel;
    if (!channel) {
        channel = [RTChannel new];
        channel.channelId = self.video.channelId;
        channel.title = self.video.channelName;
    }
    if (!channel.channelId) return;
    [self.navigationController pushViewController:[[RTChannelViewController alloc] initWithChannel:channel] animated:YES];
}

- (void)toggleDescription {
    self.descriptionOpen = !self.descriptionOpen;
    [self layoutHeader];
}

@end
