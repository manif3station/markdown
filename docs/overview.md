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

The skill also adds a local `Markdown::Enhancer` layer above those modules. That layer patches the parts the base stack is weak on:

- markdown pipe tables
- inline code marked with backticks
- fenced code blocks
- blockquotes

For pdf output, the skill also draws markdown tables as table cells with borders instead of flattening the rows into one plain text stream.

The preferred interface is positional:

- `dashboard markdown.convert source.md target.pdf`
- `dashboard markdown.convert source.md target.pdf --paper A3 --landscape`
- `dashboard markdown.convert source.md target.html`
- `dashboard markdown.convert source.html`
- `dashboard markdown.convert source.pdf`

The skill also emits verbose progress to `stderr` so callers can see each step during long-running conversions.

For PDF output, the skill supports:

- paper sizes `A1`, `A2`, `A3`, and `A4`
- shorthand paper selection with `-A 1|2|3|4`
- `--landscape`
- `--portrait`

Portrait is the default orientation.

The layout settings are applied to the real generated PDF page size. Current proofs cover A3 landscape on Linux and macOS.
