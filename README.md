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
dashboard brew install pandoc poppler wkhtmltopdf
```

## How To Use It

Convert markdown to pdf with the same basename:

```bash
dashboard markdown.convert --from notes.md --pdf
```

Convert markdown to html with an explicit output file:

```bash
dashboard markdown.convert --from notes.md --to notes.html
```

Convert markdown to html and let the skill add the `.html` suffix:

```bash
dashboard markdown.convert --from notes.md --html --to ./exports/notes
```

Convert html back to markdown with the same basename:

```bash
dashboard markdown.convert --from notes.html
```

Convert pdf back to markdown with the same basename:

```bash
dashboard markdown.convert --from notes.pdf
```

## Normal Cases

```text
Use --pdf or --to-pdf when markdown should become a shareable pdf.
```

```text
Use --html or --to-html when markdown should become a browser-friendly html file.
```

```text
Use html or pdf as the source with no other target flag when you want markdown back.
```

## Edge Cases

```text
If --to omits the final extension, the skill appends the right one for the target format.
```

```text
If markdown is the source and the caller does not provide either a target flag or a .pdf/.html output path, the skill exits non-zero and explains the missing target format.
```

```text
If html or pdf is the source, only markdown output is supported.
```

```text
If the source file does not exist or the extension is unsupported, the skill exits non-zero and reports the problem clearly.
```

## Docs

- `docs/overview.md`
- `docs/usage.md`
- `docs/changes/2026-04-30-initial-release.md`
