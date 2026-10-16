#import "RTTest.h"
#import "RTLink.h"

static RTLink *Link(NSString *text) {
    return RTParseLink([NSURL URLWithString:text]);
}

#define RT_LINK(link, expectedKind, expectedValue)  \
    do {                                            \
        RTLink *rt_link = (link);                   \
        RT_EQUAL_INT(rt_link.kind, expectedKind);   \
        RT_EQUAL(rt_link.value, expectedValue);     \
    } while (0)

RT_TEST(test_link_reads_retrotube_links) {
    RT_LINK(Link(@"retrotube://search?q=daft%20punk"), RTLinkSearch, @"daft punk");
    RT_LINK(Link(@"retrotube://search?q=daft+punk"), RTLinkSearch, @"daft punk");
    RT_LINK(Link(@"retrotube://watch?v=jNQXAC9IVRw"), RTLinkVideo, @"jNQXAC9IVRw");
    RT_LINK(Link(@"retrotube://channel?id=UC_kRDKYrUlrbtrSiyu5Tflg"), RTLinkChannel, @"UC_kRDKYrUlrbtrSiyu5Tflg");
}

RT_TEST(test_link_reads_youtube_links) {
    RT_LINK(Link(@"https://www.youtube.com/watch?v=jNQXAC9IVRw&t=10s"), RTLinkVideo, @"jNQXAC9IVRw");
    RT_LINK(Link(@"https://m.youtube.com/watch?feature=share&v=jNQXAC9IVRw"), RTLinkVideo, @"jNQXAC9IVRw");
    RT_LINK(Link(@"https://music.youtube.com/watch?v=jNQXAC9IVRw"), RTLinkVideo, @"jNQXAC9IVRw");
    RT_LINK(Link(@"https://youtu.be/jNQXAC9IVRw?si=abc"), RTLinkVideo, @"jNQXAC9IVRw");
    RT_LINK(Link(@"https://www.youtube.com/shorts/jNQXAC9IVRw"), RTLinkVideo, @"jNQXAC9IVRw");
    RT_LINK(Link(@"http://youtube.com/embed/jNQXAC9IVRw"), RTLinkVideo, @"jNQXAC9IVRw");
    RT_LINK(Link(@"https://www.youtube.com/channel/UC_kRDKYrUlrbtrSiyu5Tflg/videos"), RTLinkChannel,
            @"UC_kRDKYrUlrbtrSiyu5Tflg");
    RT_LINK(Link(@"https://www.youtube.com/results?search_query=retro+tv"), RTLinkSearch, @"retro tv");
}

RT_TEST(test_link_refuses_other_links) {
    RT_LINK(Link(@"https://example.com/watch?v=jNQXAC9IVRw"), RTLinkNone, nil);
    RT_LINK(Link(@"https://www.youtube.com/watch?v=short"), RTLinkNone, nil);
    RT_LINK(Link(@"https://www.youtube.com/watch?v=jNQXAC9IV!w"), RTLinkNone, nil);
    RT_LINK(Link(@"https://www.youtube.com/channel/notachannel"), RTLinkNone, nil);
    RT_LINK(Link(@"retrotube://other?q=x"), RTLinkNone, nil);
    RT_LINK(Link(@"retrotube://search"), RTLinkNone, nil);
    RT_LINK(Link(@"ftp://youtu.be/jNQXAC9IVRw"), RTLinkNone, nil);
}

RT_TEST(test_text_gives_link_or_search) {
    RT_LINK(RTParseText(@"  daft punk \n"), RTLinkSearch, @"daft punk");
    RT_LINK(RTParseText(@"youtu.be/jNQXAC9IVRw"), RTLinkVideo, @"jNQXAC9IVRw");
    RT_LINK(RTParseText(@"https://www.youtube.com/watch?v=jNQXAC9IVRw"), RTLinkVideo, @"jNQXAC9IVRw");
    RT_LINK(RTParseText(@"www.youtube.com/watch?v=jNQXAC9IVRw"), RTLinkVideo, @"jNQXAC9IVRw");
    RT_LINK(RTParseText(@"https://example.com"), RTLinkSearch, @"https://example.com");
    RT_LINK(RTParseText(@"   "), RTLinkNone, nil);
}
