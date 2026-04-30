# 2026-04-30 all-perl conversion stack

`markdown` now runs its supported conversion routes through Perl modules only.

## What changed

- removed `aptfile`
- removed `brewfile`
- added `cpanfile`
- markdown to html now uses `Markdown::Perl`
- html to markdown now uses `HTML::WikiConverter`
- markdown to pdf now uses `PDF::API2`
- pdf to markdown now uses `CAM::PDF`

## Why

The skill was still relying on host document-converter packages even after the macOS package fix. This update removes that dependency layer so the skill’s document conversion behavior is owned by Perl modules instead of external system packages.

## Result

The installer succeeds without host document-converter packages, and the public `dashboard markdown.convert` command works on both Linux and macOS with the same Perl-only route logic.
