# 2026-05-07 DOCX Markdown Roundtrip

`markdown` now treats `.docx` as a markdown-recoverable source by default.

Supported routes added in this ticket:

- `.docx` to `.md`
- `.md` to `.docx`

The command contract stays extension-driven:

- `dashboard markdown.convert report.docx`
- `dashboard markdown.convert report.docx report.md`
- `dashboard markdown.convert notes.md notes.docx`

Implementation detail:

- `.docx -> .md` chains through `docx -> pdf -> markdown`
- `.md -> .docx` chains through `markdown -> pdf -> docx`

This keeps the skill on the existing office-document PDF backend path instead of introducing a separate DOCX markdown engine.
