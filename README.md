# markdown

## Description

`markdown` is a Developer Dashboard skill that converts markdown, html, and pdf files between practical documentation formats.

## Value

It gives developers, writers, and operators one DD CLI command to move notes and docs between markdown, browser-ready html, and shareable pdf without switching tools.

## Problem It Solves

Documentation work often needs the same content in more than one format. A person may write in markdown, share as pdf, preview as html, or recover markdown from html or pdf later. That conversion work is repetitive and easy to get wrong when done ad hoc.

## What It Does To Solve It

This skill adds a CLI converter that:

- turns markdown into html
- turns markdown into pdf
- turns html into markdown
- turns pdf into markdown
- reuses the source basename when the caller does not provide an explicit output path
- appends the right output extension when `--to` omits it
- infers the conversion route from positional file arguments and file extensions
- prints step-by-step progress to `stderr` while it works

## Developer Dashboard Feature Added

This skill adds a CLI command:

- `dashboard markdown.convert`

## Installation

Install from the skill repo:

```bash
dashboard skills install git@github.mf:manif3station/markdown.git
```

For local development in this workspace:

```bash
dashboard skills install ~/projects/skills/skills/markdown
```

## Runtime Dependencies

Ubuntu and Debian-family hosts:

```bash
dashboard apt install pandoc poppler-utils wkhtmltopdf
```

macOS hosts:

```bash
dashboard brew install pandoc poppler weasyprint
```

## How To Use It

Convert markdown to pdf with a positional target:

```bash
dashboard markdown.convert notes.md notes.pdf
```

Convert markdown to html with a positional target:

```bash
dashboard markdown.convert notes.md notes.html
```

Convert html back to markdown with the same basename:

```bash
dashboard markdown.convert notes.html
```

Convert pdf back to markdown with the same basename:

```bash
dashboard markdown.convert notes.pdf
```

Convert markdown to html with the legacy flag path:

```bash
dashboard markdown.convert --from notes.md --html --to ./exports/notes
```

## Normal Cases

```text
Use a target path ending in `.pdf` when markdown should become a shareable pdf.
```

```text
Use a target path ending in `.html` when markdown should become a browser-friendly html file.
```

```text
Use html or pdf as the only positional source argument when you want markdown back.
```

## Edge Cases

```text
If --to omits the final extension, the skill appends the right one for the target format.
```

```text
If markdown is the source and the caller does not provide a target path ending in `.pdf` or `.html`, the skill exits non-zero and explains the missing target format.
```

```text
If html or pdf is the source, only markdown output is supported.
```

```text
PDF generation uses wkhtmltopdf when it is available and falls back to weasyprint when wkhtmltopdf is not installed.
```

```text
If the source file does not exist or the extension is unsupported, the skill exits non-zero and reports the problem clearly.
```

```text
Progress logs are printed to stderr during conversion so long-running pdf and html conversions do not appear stuck.
```

## Docs

- `docs/overview.md`
- `docs/usage.md`
- `docs/changes/2026-04-30-initial-release.md`
- `docs/changes/2026-04-30-macos-pdf-backend-fix.md`
