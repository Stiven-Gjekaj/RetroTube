# Roadmap

Each release adds one big part. The reason for each choice is in
[docs/decisions.md](docs/decisions.md).

## 1.0.0

- All of the above, checked on the iPhone 4S
- A Cydia repository, if the owner chooses one

## Known problems

- A live video does not play.
- A seek starts play at the start of a segment, up to 7 seconds before the
  point that you chose.
- The News topic takes 10 to 15 seconds to load the first time. Its answer
  is 892 KB.
- These were not tested with a tap on the phone: the topic buttons of the
  Popular tab, the quality action sheet,
  the Subscribe button, the Clear button of the history, and a swipe to
  remove a row. The code under them has tests.
- The sound of the app was not checked by ear. The tests check that the
  player plays the stream, not that the speaker gives sound.
