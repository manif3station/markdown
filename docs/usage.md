# Usage

## Install

```bash
dashboard skills install git@github.mf:manif3station/markdown.git
```

Local workspace install:

```bash
dashboard skills install ~/projects/skills/skills/markdown
```

## Runtime Modules

This skill declares its runtime in `cpanfile`:

- `Markdown::Perl`
- `HTML::WikiConverter`
- `PDF::API2`
- `CAM::PDF`

The skill-local `Markdown::Enhancer` module sits on top of that runtime to improve markdown features the base stack does not render well enough by itself.

For office-document routes, the skill also declares host backends:

- Linux: `aptfile` installs `libreoffice`
- macOS: `brewfile` installs `libreoffice`
- Windows: install Microsoft Word or LibreOffice on the host

## Command

```bash
dashboard markdown.convert <source> [target]
```

## Proven Examples

Markdown to pdf:

```bash
dashboard markdown.convert notes.md notes.pdf
```

Markdown to pdf on A3 landscape paper:

```bash
dashboard markdown.convert notes.md notes.pdf --paper A3 --landscape
```

The compact shorthand is:

```bash
dashboard markdown.convert notes.md notes.pdf -A 3 --landscape
```

The expanded paper-size families are also supported:

```bash
dashboard markdown.convert notes.md notes.pdf --paper ANSI-D
dashboard markdown.convert notes.md notes.pdf --paper DL
dashboard markdown.convert notes.md notes.pdf --paper B5
dashboard markdown.convert notes.md notes.pdf --paper C7
dashboard markdown.convert notes.md notes.pdf -A 0
dashboard markdown.convert notes.md notes.pdf -A 10
```

That path is proven against the real generated PDF page box. The generated file reports `1191 x 842 pts (A3)` in `pdfinfo`.

DOCX to PDF with the same basename:

```bash
dashboard markdown.convert report.docx
```

DOCX to PDF with an explicit target:

```bash
dashboard markdown.convert report.docx report.pdf
```

Markdown to html:

```bash
dashboard markdown.convert notes.md notes.html
```

Markdown with a table and inline code to html:

```bash
dashboard markdown.convert report.md report.html
```

That html table output now emits `<table border="1">`.

Markdown with a table and inline code to pdf:

```bash
dashboard markdown.convert report.md report.pdf
```

That pdf path now draws a visible table layout for markdown pipe tables and removes raw markdown markers from the cell text.
It also wraps long table values inside the current cell and grows the row height so adjacent columns do not overlap.

HTML back to markdown:

```bash
dashboard markdown.convert notes.html
```

PDF back to markdown:

```bash
dashboard markdown.convert notes.pdf
```

PDF to DOCX with an explicit target:

```bash
dashboard markdown.convert scan.pdf scan.docx
```

Legacy flag syntax still works:

```bash
dashboard markdown.convert --from notes.md --html --to notes.html
```

## Output Naming Rules

- when the target path is omitted for html or pdf input, the skill reuses the source basename and changes only the extension to `.md`
- when the target path is omitted for docx input, the skill reuses the source basename and changes only the extension to `.pdf`
- when `--to` is present without the final output suffix, the skill appends the right one
- markdown input requires a target filename ending in `.pdf` or `.html`, or the legacy `--pdf`/`--html` flags
- html and pdf input default to markdown output
- pdf input can target `.docx` explicitly
- docx input always targets `.pdf`

## PDF Layout Controls

- `--paper` accepts `A1`, `A2`, `A3`, and `A4`
- `--paper` accepts ISO `A0` through `A10`, `B0` through `B10`, `C0` through `C7`, `DL`, and `ANSI-A` through `ANSI-E`
- `-A 0|1|2|3|4|5|6|7|8|9|10` is shorthand for `--paper A0|A1|A2|A3|A4|A5|A6|A7|A8|A9|A10`
- `--portrait` is the default orientation
- `--landscape` switches the generated pdf to landscape mode
- `--paper`, `--landscape`, and `--portrait` are only valid when the target output is pdf
- only one paper-size selector may be used at a time

## Progress Output

- conversion progress is printed to `stderr`
- the log includes detected source and target formats
- the log includes the active conversion step
- current renderer fixes proven in this ticket include pipe tables and inline code so raw markdown markers are not left behind in html or pdf output
- current renderer fixes also include long PDF table-cell wrapping for class names, file paths, and action text

## Office Route Notes

- docx-to-pdf uses the host Office backend, not `PDF::API2`
- Linux requires LibreOffice / `soffice`
- macOS prefers Microsoft Word automation for docx-to-pdf and can fall back to LibreOffice
- Windows prefers Microsoft Word automation through PowerShell COM and can fall back to LibreOffice
- pdf-to-docx uses LibreOffice on Linux and macOS, and Word or LibreOffice on Windows
