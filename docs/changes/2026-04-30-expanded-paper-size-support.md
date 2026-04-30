# Expanded Paper Size Support

## What changed

- added ISO `A0` through `A10`
- added ISO `B0` through `B10`
- added ISO `C0` through `C7`
- added `DL`
- added `ANSI-A` through `ANSI-E`
- extended `-A` shorthand to `0` through `10`

## Why it changed

Some markdown-to-pdf workflows need more than the original small A-series subset. The skill now covers the broader paper families commonly used for print, envelopes, and ANSI drawing sizes.

## Proof

- Docker tests and 100% coverage passed
- installed runtime proof passed on Linux and macOS
- representative generated PDFs reported the expected media boxes for `A0`, `DL`, and `ANSI-D`
