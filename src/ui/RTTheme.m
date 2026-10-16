#import "RTTheme.h"

static UIColor *RTColor(unsigned rgb) {
    return [UIColor colorWithRed:((rgb >> 16) & 0xff) / 255.0 green:((rgb >> 8) & 0xff) / 255.0
                            blue:(rgb & 0xff) / 255.0 alpha:1];
}

UIColor *RTWalnutColor(void) {
    return RTColor(0x6b3d20);
}

UIColor *RTCreamColor(void) {
    return RTColor(0xf4e9cf);
}

UIColor *RTAmberColor(void) {
    return RTColor(0xe2661a);
}

UIColor *RTBrownTextColor(void) {
    return RTColor(0x3a1f0d);
}

void RTApplyTheme(void) {
    // iOS 6 gives the status bar the color of the navigation bar.
    [[UINavigationBar appearance] setTintColor:RTWalnutColor()];
    [[UISearchBar appearance] setTintColor:RTWalnutColor()];
    [[UIToolbar appearance] setTintColor:RTWalnutColor()];
    [[UITabBar appearance] setTintColor:RTColor(0x2b1a10)];
    [[UITabBar appearance] setSelectedImageTintColor:RTColor(0xffc24a)];
    [[UIRefreshControl appearance] setTintColor:RTWalnutColor()];
}
