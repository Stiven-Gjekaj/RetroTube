# Roadmap

Version 1.0.0 holds all the planned features. The owner checked them on the
iPhone 4S on 2026-10-16, and all the checks passed. New tasks come here when
the owner chooses them. The reason for each choice is in
[docs/decisions.md](docs/decisions.md).

## Ideas for the owner to choose

- An Auto quality that changes with the speed of the network. The local
  server can give an HLS playlist with 360p, 480p, and 720p, and the player
  of iOS 6 picks one by the speed.
- A Cydia repository, so that Cydia shows the updates

## Known problems

- A live video does not play.
- A seek starts play at the start of a segment, up to 7 seconds before the
  point that you chose. On a slow network, a seek also waits for the
  segment that downloads at that time.
- The News topic takes 10 to 15 seconds to load the first time. Its answer
  is 892 KB.
