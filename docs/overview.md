# Overview

`markdown` is a CLI conversion skill for documentation files.

It exists so DD users can move content between markdown, html, pdf, and docx without building one-off shell pipelines each time they need a new copy format.

The current supported routes are:

- markdown to html
- markdown to pdf
- docx to pdf
- markdown to docx
- html to markdown
- pdf to markdown
- docx to markdown
- pdf to docx

The skill uses Perl modules for the markdown/html/pdf routes:

- `Markdown::Perl` for markdown to html
- `HTML::WikiConverter` for html to markdown
- `PDF::API2` for markdown to pdf
- `CAM::PDF` for pdf to markdown

For office-document routes, the skill uses host Office backends instead of pretending there is one pure-Perl DOCX/PDF engine that works everywhere:

- Linux uses LibreOffice / `soffice`
- macOS uses Microsoft Word automation for docx-to-pdf when Word is installed, with LibreOffice fallback, and uses LibreOffice for pdf-to-docx
- Windows uses Microsoft Word automation through PowerShell COM when Word is installed, with LibreOffice fallback

The skill also adds a local `Markdown::Enhancer` layer above those modules. That layer patches the parts the base stack is weak on:

- markdown pipe tables
- inline code marked with backticks
- fenced code blocks
- blockquotes

For pdf output, the skill also draws markdown tables as table cells with borders instead of flattening the rows into one plain text stream.
Long PDF table values are wrapped inside each cell, and the row height grows to fit the extra lines.

The preferred interface is positional:

- `dashboard markdown.convert source.md target.pdf`
- `dashboard markdown.convert source.md target.pdf --paper A3 --landscape`
- `dashboard markdown.convert source.md target.html`
- `dashboard markdown.convert source.md target.docx`
- `dashboard markdown.convert source.docx`
- `dashboard markdown.convert source.docx target.md`
- `dashboard markdown.convert source.docx target.pdf`
- `dashboard markdown.convert source.html`
- `dashboard markdown.convert source.pdf`
- `dashboard markdown.convert source.pdf target.docx`

The skill also emits verbose progress to `stderr` so callers can see each step during long-running conversions.

For PDF output, the skill supports:

- ISO paper sizes `A0` through `A10`
- ISO paper sizes `B0` through `B10`
- ISO paper sizes `C0` through `C7`
- `DL`
- `ANSI-A` through `ANSI-E`
- shorthand paper selection with `-A 0|1|2|3|4|5|6|7|8|9|10`
- `--landscape`
- `--portrait`

Portrait is the default orientation.

The layout settings are applied to the real generated PDF page size. Current proofs cover A3 landscape on Linux and macOS for markdown-to-pdf. The DOCX/PDF office routes and the chained `.docx <-> .md` plus `.md -> .docx` routes are proven through Docker tests and backend-selection tests for Linux, macOS, and Windows code paths.
