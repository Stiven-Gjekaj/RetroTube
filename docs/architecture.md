# Architecture

RetroTube is one iOS app in Objective-C with ARC. It uses only the frameworks
of iOS 6: UIKit, Foundation, MediaPlayer, AVFoundation, and CoreMedia.

## The path of a video

```
search -> list -> player request -> stream session -> HLS server -> movie player
```

1. **Search.** `RTInnerTube` sends a search request as the MWEB client.
   `RTParsePage` finds the videos, the channels, and the token of the next
   page in the answer.
2. **List.** `RTListViewController` shows the items in a table. When the
   last rows show, it loads the next page with the token.
3. **Player request.** `RTInnerTube loadPlayer:` sends the player request as
   the VISIONOS client with a visitor ID. `RTParsePlayer` keeps the H.264
   video streams and the AAC sound streams.
4. **Stream session.** `RTStreamSession` reads the start of the two DASH
   files: the init segment and the segment index (`sidx`). Each entry of the
   video index becomes one HLS segment.
5. **HLS server.** `RTHLSServer` listens on `127.0.0.1` on a free port. It
   gives the playlist, and for each segment it asks the session.
6. **Segment.** The session reads the bytes of the video fragment and of the
   sound that covers the same time, with HTTP range requests.
   `RTRemuxSegment` reads the samples (`RTMP4`) and writes them into one
   MPEG transport stream (`RTTS`): H.264 in Annex B form and AAC in ADTS
   frames. The session keeps the last 3 segments and loads the next one
   before the player asks for it.
7. **Movie player.** `MPMoviePlayerViewController` plays the playlist URL.

## Why a server on the phone

iOS 6 does not play the fragmented MP4 sound of YouTube, and it does not
play HLS from a file URL. It plays MPEG-TS HLS from an HTTP URL.
[decisions.md](decisions.md#playback) has the tests.

## Files

```
src/core/      code with no UIKit. The tests run it on the Mac and on the phone.
  RTModels       the video, channel, and page objects
  RTParse        reads the lists of InnerTube answers
  RTPlayer       reads the player answer and picks the streams
  RTInnerTube    makes and sends the InnerTube requests
  RTLink         reads retrotube:// and YouTube links
  RTMP4          reads fragmented MP4: init, sidx, moof
  RTTS           writes MPEG transport streams
  RTRemux        makes one TS segment from the fragments
  RTStreamSession  the playlist and the segments of one video
  RTHLSServer    the HTTP server on 127.0.0.1
src/ui/        the screens
tests/         the tests of src/core
probe/         tools that run on the phone
scripts/       build, test, install, and package
resources/     Info.plist, icons, launch images
packaging/     the files of the Cydia package
```

## The SDK

The app builds with the iOS 9.3 SDK and the clang of the current Xcode.
`fix-sdk.sh` changes the SDK stubs:

- It removes the simulator architectures, so that the new linker accepts the
  stubs.
- It moves the URL loading classes into the Foundation stub, where iOS 6 has
  them.
- It adds the C string functions to the libsystem_c stub, where iOS 6 has
  them.

`build.sh` stops the build when code uses an API that is newer than iOS 6.
