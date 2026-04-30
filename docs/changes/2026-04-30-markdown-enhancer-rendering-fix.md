# 2026-04-30 markdown enhancer rendering fix

## Summary

Added a skill-local `Markdown::Enhancer` layer to improve markdown output before the CPAN converters and PDF renderer consume it.

## What Changed

- html conversion now rewrites markdown pipe tables into real html `<table>` markup
- html conversion now rewrites inline backtick code into `<code>` markup
- pdf conversion now normalizes markdown tables into readable row text without raw pipe characters
- pdf conversion now strips backticks from inline code instead of printing them directly
- fenced code blocks and blockquotes are now normalized through the enhancer layer as well

## Why

The base Perl stack was functional, but it was weak on a few markdown features that users expect to render cleanly. Tables and inline code were the most visible problems because the output still showed raw markdown syntax.
