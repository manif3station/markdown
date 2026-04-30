# markdown

## Description

`markdown` is a Developer Dashboard skill that converts markdown, html, and pdf files between practical documentation formats with a Perl-only conversion stack.

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
- uses Perl modules for all supported conversions instead of relying on host document-converter packages
- adds a skill-local enhancer layer on top of those Perl modules for markdown features the base stack is weak on, such as tables and inline code
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

This skill now installs its conversion stack through `cpanfile`.

The current Perl modules are:

- `Markdown::Perl`
- `HTML::WikiConverter`
- `PDF::API2`
- `CAM::PDF`

On top of that CPAN stack, the skill ships `Markdown::Enhancer` to improve output for:

- markdown tables
- inline code marked with backticks
- fenced code blocks
- blockquotes

## How To Use It

Convert markdown to pdf with a positional target:

```bash
dashboard markdown.convert notes.md notes.pdf
```

Convert markdown to html with a positional target:

```bash
dashboard markdown.convert notes.md notes.html
```

Convert markdown with a table and inline code to html:

```bash
dashboard markdown.convert report.md report.html
```

The resulting html now renders markdown table rows as a real `<table>` and inline code like `` `token` `` as `<code>token</code>`.

Convert the same markdown to pdf:

```bash
dashboard markdown.convert report.md report.pdf
```

The resulting pdf now strips raw pipe-table syntax and backticks instead of printing the markdown markers directly.

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
- `docs/changes/2026-04-30-positional-cli-and-progress.md`
- `docs/changes/2026-04-30-all-perl-conversion-stack.md`
- `docs/changes/2026-04-30-markdown-enhancer-rendering-fix.md`
