# Usage

## Install

```bash
dashboard skills install git@github.mf:manif3station/markdown.git
```

Local workspace install:

```bash
dashboard skills install ~/projects/skills/skills/markdown
```

## Runtime Packages

Ubuntu and Debian-family:

```bash
dashboard apt install pandoc poppler-utils wkhtmltopdf
```

macOS:

```bash
dashboard brew install pandoc poppler weasyprint
```

## Command

```bash
dashboard markdown.convert --from <source> [--to <output>] [--pdf|--to-pdf|--html|--to-html]
```

## Proven Examples

Markdown to pdf:

```bash
dashboard markdown.convert --from notes.md --pdf
```

Markdown to html:

```bash
dashboard markdown.convert --from notes.md --to notes.html
```

HTML back to markdown:

```bash
dashboard markdown.convert --from notes.html
```

PDF back to markdown:

```bash
dashboard markdown.convert --from notes.pdf
```

## Pdf Backend Selection

- on Ubuntu and Debian-family hosts, the documented package path installs `wkhtmltopdf`
- on macOS, the documented package path installs `weasyprint`
- at runtime the skill prefers `wkhtmltopdf` and falls back to `weasyprint`

## Output Naming Rules

- when `--to` is omitted, the skill reuses the source basename and changes only the extension
- when `--to` is present without the final output suffix, the skill appends the right one
- markdown input requires either a pdf/html target flag or an output filename ending in `.pdf` or `.html`
- html and pdf input default to markdown output
