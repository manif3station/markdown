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
