// The colors of the logo, for the bars, the buttons, and the accents.
// The controls stay the stock iOS 6 controls. See docs/decisions.md.

#import <UIKit/UIKit.h>

UIColor *RTWalnutColor(void);  // The bars
UIColor *RTCreamColor(void);   // Light backgrounds
UIColor *RTAmberColor(void);   // Accents: links, the play button
UIColor *RTBrownTextColor(void);

// Sets the tint of the bars of the app. Call it before the first window shows.
void RTApplyTheme(void);
