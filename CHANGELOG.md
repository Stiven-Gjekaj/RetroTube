# Changelog

Every release is written here, newest first. A version is
`MAJOR.MINOR.PATCH`. Before 1.0.0, each big addition raises the minor number.
Each release on GitHub has the `.deb` package as an asset.

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
