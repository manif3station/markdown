# Overview

`markdown` is a CLI conversion skill for documentation files.

It exists so DD users can move content between markdown, html, and pdf without building one-off shell pipelines each time they need a new copy format.

The current supported routes are:

- markdown to html
- markdown to pdf
- html to markdown
- pdf to markdown

The skill uses `pandoc` as the main bridge, `wkhtmltopdf` or `weasyprint` for pdf generation, and `pdftohtml` when recovering markdown from pdf input.

The preferred interface is positional:

- `dashboard markdown.convert source.md target.pdf`
- `dashboard markdown.convert source.md target.html`
- `dashboard markdown.convert source.html`
- `dashboard markdown.convert source.pdf`

The skill also emits verbose progress to `stderr` so callers can see each step and command path during long-running conversions.
