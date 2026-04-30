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

## Command

```bash
dashboard markdown.convert <source> [target]
```

## Proven Examples

Markdown to pdf:

```bash
dashboard markdown.convert notes.md notes.pdf
```

Markdown to html:

```bash
dashboard markdown.convert notes.md notes.html
```

Markdown with a table and inline code to html:

```bash
dashboard markdown.convert report.md report.html
```

Markdown with a table and inline code to pdf:

```bash
dashboard markdown.convert report.md report.pdf
```

That pdf path now draws a visible table layout for markdown pipe tables and removes raw markdown markers from the cell text.

HTML back to markdown:

```bash
dashboard markdown.convert notes.html
```

PDF back to markdown:

```bash
dashboard markdown.convert notes.pdf
```

Legacy flag syntax still works:

```bash
dashboard markdown.convert --from notes.md --html --to notes.html
```

## Output Naming Rules

- when the target path is omitted for html or pdf input, the skill reuses the source basename and changes only the extension to `.md`
- when `--to` is present without the final output suffix, the skill appends the right one
- markdown input requires a target filename ending in `.pdf` or `.html`, or the legacy `--pdf`/`--html` flags
- html and pdf input default to markdown output

## Progress Output

- conversion progress is printed to `stderr`
- the log includes detected source and target formats
- the log includes the active conversion step
- current renderer fixes proven in this ticket include pipe tables and inline code so raw markdown markers are not left behind in html or pdf output
