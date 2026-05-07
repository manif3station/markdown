# 2026-05-07 DOCX PDF Office Routes

`markdown` now supports office-document conversion routes through `dashboard markdown.convert`:

- `.docx` to `.pdf`
- `.pdf` to `.docx` when the target path ends in `.docx`

The command keeps the same extension-driven contract as the existing markdown, html, and pdf routes:

- `dashboard markdown.convert report.docx`
- `dashboard markdown.convert report.docx report.pdf`
- `dashboard markdown.convert scan.pdf scan.docx`

The route backends are host-aware:

- Linux uses LibreOffice / `soffice`
- macOS prefers Microsoft Word automation for docx-to-pdf and falls back to LibreOffice
- Windows prefers Microsoft Word automation through PowerShell COM and falls back to LibreOffice

This ticket also adds the host dependency files used by the skill installer:

- `aptfile` with `libreoffice`
- `brewfile` with `libreoffice`

Verification for this change is Docker-based and includes:

- full skill functional tests
- `100.0%` statement and subroutine coverage for production modules
- explicit route-selection tests
- explicit backend-selection tests for Linux, macOS, and Windows code paths
