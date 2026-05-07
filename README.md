# markdown

## Description

`markdown` is a Developer Dashboard skill that converts markdown, html, pdf, and docx files between practical documentation formats with a Perl-first conversion stack.

## Value

It gives developers, writers, and operators one DD CLI command to move notes and docs between markdown, browser-ready html, shareable pdf, and office-friendly docx without switching tools.

## Problem It Solves

Documentation work often needs the same content in more than one format. A person may write in markdown, share as pdf, preview as html, deliver a docx, or recover markdown from html or pdf later. That conversion work is repetitive and easy to get wrong when done ad hoc.

## What It Does To Solve It

This skill adds a CLI converter that:

- turns markdown into html
- turns markdown into pdf
- turns docx into pdf
- turns html into markdown
- turns pdf into markdown
- turns pdf into docx when the target path ends in `.docx`
- keeps markdown/html/pdf routes on Perl modules
- uses host Office backends for docx/pdf routes:
  - Linux: LibreOffice / `soffice`
  - macOS: Microsoft Word automation first for docx-to-pdf, LibreOffice fallback, LibreOffice for pdf-to-docx
  - Windows: Microsoft Word automation through PowerShell COM first, LibreOffice fallback
- adds a skill-local enhancer layer on top of those Perl modules for markdown features the base stack is weak on, such as tables and inline code
- reuses the source basename when the caller does not provide an explicit output path
- appends the right output extension when `--to` omits it
- infers the conversion route from positional file arguments and file extensions
- lets the caller choose PDF paper size with `--paper` and orientation with `--landscape` or `--portrait`
- prints step-by-step progress to `stderr` while it works
- wraps long PDF table-cell content inside the cell and increases row height to fit it

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

## License

`markdown` is released under the MIT License.

See [LICENSE](LICENSE).

## Runtime Dependencies

This skill now installs its Perl conversion stack through `cpanfile`.

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

For office-document routes, the skill also declares host backends:

- Linux: `aptfile` installs `libreoffice`
- macOS: `brewfile` installs `libreoffice`
- Windows: install Microsoft Word or LibreOffice on the host

## How To Use It

Convert markdown to pdf with a positional target:

```bash
dashboard markdown.convert notes.md notes.pdf
```

Convert markdown to pdf on A3 landscape paper:

```bash
dashboard markdown.convert notes.md notes.pdf --paper A3 --landscape
```

The shorthand form is also supported:

```bash
dashboard markdown.convert notes.md notes.pdf -A 3 --landscape
```

That route is now proven against the real generated PDF page box, not just the command JSON output.

Use a non-A paper family when needed:

```bash
dashboard markdown.convert notes.md notes.pdf --paper ANSI-D
dashboard markdown.convert notes.md notes.pdf --paper DL
dashboard markdown.convert notes.md notes.pdf --paper B5
dashboard markdown.convert notes.md notes.pdf --paper C7
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
The generated markdown table html now emits `<table border="1">`.

Convert the same markdown to pdf:

```bash
dashboard markdown.convert report.md report.pdf
```

The resulting pdf now strips raw pipe-table syntax and backticks instead of printing the markdown markers directly.

For markdown tables, the pdf renderer now draws table cell structure instead of collapsing the table into plain paragraph text.
Long table values such as class names, test filenames, and status text are now wrapped inside the same cell instead of spilling into adjacent columns.

Convert docx to pdf with the same basename:

```bash
dashboard markdown.convert report.docx
```

Convert docx to pdf with an explicit output path:

```bash
dashboard markdown.convert report.docx report.pdf
```

Convert html back to markdown with the same basename:

```bash
dashboard markdown.convert notes.html
```

Convert pdf back to markdown with the same basename:

```bash
dashboard markdown.convert notes.pdf
```

Convert pdf to docx with an explicit output path:

```bash
dashboard markdown.convert scan.pdf scan.docx
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
Use `--paper A1`, `A2`, `A3`, or `A4` with pdf output when the document needs a larger or smaller page size.
```

```text
Use `-A 1`, `2`, `3`, or `4` as the compact shorthand for `--paper A1`, `A2`, `A3`, or `A4`.
```

```text
Use `--paper` with ISO `A0` through `A10`, `B0` through `B10`, `C0` through `C7`, `DL`, or `ANSI-A` through `ANSI-E` when the output needs a specific print or envelope size.
```

```text
Use `--landscape` for wider tables. The default orientation is portrait.
```

```text
Use the default PDF table renderer when a markdown table contains long class names, paths, or action text. The skill now wraps those values inside each cell and grows the row height to match.
```

```text
Use a target path ending in `.html` when markdown should become a browser-friendly html file.
```

```text
Use html or pdf as the only positional source argument when you want markdown back.
```

```text
Use a `.docx` source when you want a `.pdf` output from an office document. If no target is given, the skill reuses the basename and writes a sibling `.pdf`.
```

```text
Use a `.pdf` source with a `.docx` target when you want office-document output instead of markdown recovery.
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
If the source is `.docx`, only `.pdf` output is supported.
```

```text
If `--paper`, `--landscape`, or `--portrait` are used on a non-pdf route, the skill exits non-zero and explains that those flags are only valid for PDF output.
```

```text
If the caller provides more than one paper-size selector, such as `--paper A4 -A 3`, the skill exits non-zero and asks for a single paper-size choice.
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
- `docs/changes/2026-04-30-pdf-table-cell-wrapping-fix.md`
- `docs/changes/2026-04-30-expanded-paper-size-support.md`
