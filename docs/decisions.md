# Decisions

This file records each choice of the owner and each technical decision.
Each entry gives the reason.

## Choices of the owner (2026-10-16)

- **The repository is public.**
  It is the same as most other repositories of the owner.
- **The interface is stock iOS 6 UIKit.**
  It uses the navigation bar, the tab bar, and plain table cells.
  It fits the system, and it is fast on the A5 chip.
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

## The InnerTube clients

- **Lists use the MWEB client.**
  One search page is 160 KB as MWEB, 656 KB as WEB, 2.6 MB as ANDROID, and
  6.8 MB as IOS (measured on 2026-10-16).
  The A5 chip parses a small answer faster.
  MWEB gives `videoWithContextRenderer` items for search, for the channel
  videos tab, and for the related videos.
- **Playback uses the IOS client.**
  The IOS client gives direct stream URLs with no signature cipher.
  The MWEB, WEB embedded, and TV embedded clients refuse playback without the
  JavaScript of the web player.

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

When the IOS client gives an HLS manifest, the app can play it directly if
its segments are MPEG-TS.

## Releases

- The version uses semantic versioning.
- A release gets a tag `vX.Y.Z`, notes in `CHANGELOG.md`, and the .deb
  package as an asset on GitHub.
