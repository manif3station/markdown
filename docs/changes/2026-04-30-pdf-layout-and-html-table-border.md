# 2026-04-30 pdf layout and html table border

## Summary

Added PDF paper-size and orientation controls, and made generated HTML tables emit `border="1"`.

## What Changed

- `dashboard markdown.convert` now accepts `--paper A1|A2|A3|A4`
- `--landscape` and `--portrait` now control the generated PDF orientation
- portrait is the default orientation
- non-PDF routes reject PDF-only layout flags clearly
- generated markdown table HTML now emits `<table border="1">`

## Proof

- Docker tests verify route validation, CLI argument passing, and 100% coverage
- installed DD proof passed locally for `--paper A3 --landscape`
- installed DD proof passed on `macdev` for `--paper A3 --landscape`
