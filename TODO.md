# Roadmap

Version 1.0.0 holds all the planned features. The owner checked them on the
iPhone 4S on 2026-10-16, and all the checks passed. New tasks come here when
the owner chooses them. The reason for each choice is in
[docs/decisions.md](docs/decisions.md).

## Ideas for the owner to choose

## Known problems

- A live video does not play.
- A seek starts play at the start of a segment, up to 7 seconds before the
  point that you chose. On a slow network, a seek also waits for the
  segment that downloads at that time.
- The News topic takes 10 to 15 seconds to load the first time. Its answer
  is 892 KB.
