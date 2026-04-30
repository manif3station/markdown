# Overview

`markdown` is a CLI conversion skill for documentation files.

It exists so DD users can move content between markdown, html, and pdf without building one-off shell pipelines each time they need a new copy format.

The current supported routes are:

- markdown to html
- markdown to pdf
- html to markdown
- pdf to markdown

The skill uses Perl modules for every supported route:

- `Markdown::Perl` for markdown to html
- `HTML::WikiConverter` for html to markdown
- `PDF::API2` for markdown to pdf
- `CAM::PDF` for pdf to markdown

The preferred interface is positional:

- `dashboard markdown.convert source.md target.pdf`
- `dashboard markdown.convert source.md target.html`
- `dashboard markdown.convert source.html`
- `dashboard markdown.convert source.pdf`

The skill also emits verbose progress to `stderr` so callers can see each step during long-running conversions.
