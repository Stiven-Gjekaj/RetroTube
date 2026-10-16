# Changelog

Every release is written here, newest first. A version is
`MAJOR.MINOR.PATCH`. Before 1.0.0, each big addition raises the minor number.
From 1.0.0, a fix raises the patch number, a new function raises the minor
number, and a change that breaks the stored subscriptions or history raises
the major number.
Each release on GitHub has the `.deb` package as an asset.

## 1.0.1 (2026-10-16)

- Search results show the original title of each video. YouTube search
  sometimes gave a title that the creator translated into another language,
  for example Italian, and the video page then showed the original. The app
  now gets the original titles from the oEmbed endpoint of YouTube. A
  translated title can show for a moment before the original comes.

## 1.0.0 (2026-10-16)

The first full release. It has the same code as 0.4.0.

- The owner checked all the parts on the iPhone 4S with iOS 6.1.3: the
  sound, Subscribe, the swipe to remove a row, Clear History, the quality
  button, and the topics of the Popular tab. All the checks passed.

## 0.4.0 (2026-10-16)

Popular videos.

- A Popular tab with the videos of four YouTube topics: Music, Gaming,
  Sports, and News. The app remembers the last topic.
- With subscriptions, the app starts on the Feed tab. Without them, it
  starts on Popular.
- Fixes empty pages in a region that YouTube refuses, for example Albania.
  Before the first request, the app checks the region one time and uses US
  if YouTube refuses it.
- The Feed tab does not show its empty text while it loads.
- A `retrotube://popular` link opens the Popular tab.

## 0.3.0 (2026-10-16)

Subscriptions, a feed, and a history, with no account.

- A tab bar with Feed, Search, Subscriptions, and History.
- Subscribe to a channel from its page. The subscriptions stay on the
  phone.
- The Feed tab shows the newest videos of the subscriptions, from their RSS
  feeds. Pull down to load it again.
- The History tab shows the videos that you played, newest first, up to 200.
  Swipe a row to remove it, or clear all of them.
- The channel page shows the name of the channel, also from a link.
- The bars and the accents have the colors of the logo.
- A live video shows LIVE on its picture.

## 0.2.1 (2026-10-16)

- The app icon has round corners and the gloss of iOS 6. iOS 6 does not add
  them to an app in `/Applications`, so the icon was square.

## 0.2.0 (2026-10-16)

The video page and the new logo.

- A tap on a video opens its page: a large picture with a play button, the
  title, the views, the date, the likes, the channel with its picture and its
  subscribers, the full description, and the related videos.
- The page loads the streams before you tap play, so play starts faster.
- A button on the page chooses the highest video quality, from 240p to
  1080p. The default is 720p.
- A new retro logo and app icon: a wood television from the 1970s.
- A `retrotube://watch` link opens the page of the video.
- Fixes a search from a link at launch that failed with HTTP 400 in a region
  that YouTube refuses. The app opened the link two times, and the second
  request did not change to the region US.

## 0.1.0 (2026-10-16)

The first release. It searches and plays.

- Search YouTube for videos and channels. More results load as you scroll.
- Open a channel to see its videos, newest first.
- Play a video in H.264 up to 720p with AAC sound, in the movie player of
  iOS 6, with seek and full screen.
- A server in the app on `127.0.0.1` joins the DASH video and sound of
  YouTube into HLS segments that iOS 6 plays.
- Paste a YouTube link into the search bar to open its video or its channel.
- Open `retrotube://search`, `retrotube://watch`, and `retrotube://channel`
  links.
- When YouTube refuses the region of the phone, the app uses the region US.
