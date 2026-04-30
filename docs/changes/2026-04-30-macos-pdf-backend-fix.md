# 2026-04-30 macOS pdf backend fix

`markdown` now uses a supported macOS package contract for pdf generation.

## What changed

- macOS installation now declares `weasyprint` in `brewfile`
- markdown-to-pdf keeps `wkhtmltopdf` support when it is present
- markdown-to-pdf now falls back to `weasyprint` when `wkhtmltopdf` is not installed

## Why

Current Homebrew installs no longer provide `wkhtmltopdf`, which caused `dashboard skills install markdown` to fail on macOS before the skill could even be used.

## Result

The skill stays installable on macOS and still supports Ubuntu and Debian-family hosts with the original `wkhtmltopdf` path.
