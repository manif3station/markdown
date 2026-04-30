# 2026-04-30 paper shorthand and single selection

## Summary

Added `-A` paper-size shorthand and made duplicate paper-size selection fail clearly.

## What Changed

- `-A 1`, `2`, `3`, and `4` now map to `A1`, `A2`, `A3`, and `A4`
- mixed paper selectors such as `--paper A4 -A 3` now fail with a clear single-selection error
- installed runtime proof now covers the shorthand path on Linux and macOS
