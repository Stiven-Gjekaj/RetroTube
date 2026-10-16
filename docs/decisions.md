# Decisions

This file records each choice of the owner and each technical decision.
Each entry gives the reason.

## Choices of the owner (2026-10-16)

- **The repository is public.**
  It is the same as most other repositories of the owner.
- **The interface is stock iOS 6 UIKit.**
  It uses the navigation bar, the tab bar, and plain table cells.
  It fits the system, and it is fast on the A5 chip.
- **The bars and the buttons use the colors of the logo** (chosen after
  0.2.0). The controls stay the stock iOS 6 controls, with a tint of walnut,
  cream, and amber.
- **Subscriptions are local.**
  There is no sign-in.
  The app keeps the subscriptions and the history on the phone.
  It makes the feed from the channel pages.
- **Version 1.0.0 holds all the features.**
  Version 1.0.0 has search, playback, the video page, channels, local
  subscriptions, history, the Popular tab, and a .deb package.
- **Each big addition gets a release.**
  The releases are 0.x versions until version 1.0.0.
- **The Popular tab replaces Trending.**
  YouTube removed the Trending page in 2025.
  The `FEtrending` browse ID gives HTTP 400.
  The home feed with no account is empty.
  The Popular tab shows shelves from the YouTube topic channels, for example
  Music, Gaming, Sports, and News.

## The region

YouTube does not accept all regions as the `gl` value. For the region AL
(Albania), a search gives HTTP 400, and a topic page gives HTTP 200 with no
videos (tested on 2026-10-16).

**Decision: the app checks the region one time.** Before the first request,
it sends one search with the region of the phone. If YouTube answers HTTP
400, the app uses US. The result stays in the user defaults, so the check
runs one time for each region.

## The InnerTube clients

- **Lists use the MWEB client.**
  One search page is 160 KB as MWEB, 656 KB as WEB, 2.6 MB as ANDROID, and
  6.8 MB as IOS (measured on 2026-10-16).
  The A5 chip parses a small answer faster.
  MWEB gives `videoWithContextRenderer` items for search, for the channel
  videos tab, and for the related videos.
- **Playback uses the VISIONOS client with a visitor ID.**
  The app gets the visitor ID from the `/visitor_id` endpoint and keeps it.
  If YouTube asks for a sign-in, the app gets a new visitor ID and tries one
  more time.
  The VISIONOS client gives direct stream URLs with no signature cipher, and
  the URLs serve the full file.
  A test on 2026-10-16 gave these results for the player request:

  | Client | Result |
  | --- | --- |
  | IOS | Direct URLs, but each URL serves only the first 60 to 65 seconds of the content. Then HTTP 403. A wait does not change this. |
  | ANDROID | The same limit as IOS. |
  | ANDROID_VR | "Sign in to confirm you're not a bot" with no visitor ID. With a visitor ID, the same limit as IOS. |
  | TVHTML5 | Refused. |
  | MWEB, WEB embedded, TV embedded | Refused without the JavaScript of the web player. |
  | VISIONOS with a visitor ID | Direct URLs that serve the full file, for 6 of 6 videos. H.264 up to 1080p and AAC. |

  The IOS limit comes from the PO token rule of YouTube. A PO token needs the
  BotGuard JavaScript, and iOS 6 cannot run it.

## Playback

The IOS client gives no muxed format.
It gives an HLS manifest for some videos only (1 of 5 videos in a test on
2026-10-16).
For the other videos it gives separate DASH streams: H.264 video in
fragmented MP4, and AAC audio in fragmented MP4.

Tests on the iPhone 4S with iOS 6.1.3 gave these results:

| Test | Result |
| --- | --- |
| AVPlayer, DASH H.264 video (fragmented MP4), remote or local | Plays |
| AVPlayer, DASH AAC audio (fragmented MP4), remote or local | Fails, OSStatus -12842 |
| AVPlayer, the same AAC in a plain M4A | Plays |
| AVPlayer, the same AAC as ADTS | Plays |
| AVMutableComposition of the two DASH streams | Fails, OSStatus -12780 |
| AVPlayer, MPEG-TS HLS from a `file://` URL | Fails |
| AVPlayer, MPEG-TS HLS from `http://127.0.0.1` | Plays, also across segments |

**Decision: the app runs a local HLS server.**
The server reads the DASH video and audio with HTTP range requests.
It remuxes each fragment into an MPEG-TS segment.
The player gets one HLS playlist on `127.0.0.1`.
The result is one player with seek, the standard controls, and correct sync.
The server does not decode or encode media, so the CPU cost is small.

The HLS manifest of the VISIONOS client puts the audio in separate
renditions. The app does not use it.

A test on the iPhone 4S with a 720p video of 340 seconds (2026-10-16) gave
these results:

- The player request, the visitor ID, and the two stream heads take 0.7 to
  5.4 seconds. Most of the time is the network.
- Play starts 1.3 seconds after that.
- The app uses 0.1 to 0.2 seconds of CPU for each second of video. The
  system decodes the video in another process.
- A seek to the middle starts play again after 4 seconds, at the start of the
  segment.

## The icon

iOS 6 rounds the corners of an App Store icon and adds the gloss. It does
not do this for an app in `/Applications`, because it takes that app for a
system app. The icons of the system apps have the corners and the gloss in
the image. A test on the iPhone 4S (2026-10-16) showed the RetroTube icon
square, next to the round Settings icon.

**Decision: the icon image has its own corners and gloss.**
`assets/brand/icon-ios6.svg` adds a corner radius of 10 of 57 pixels and a
gloss to `assets/brand/icon.svg`. `scripts/icons.sh` renders it.

## Releases

- The version uses semantic versioning.
- A release gets a tag `vX.Y.Z`, notes in `CHANGELOG.md`, and the .deb
  package as an asset on GitHub.
