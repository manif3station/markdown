# EPIC-385

## Title

Retroactively gate the ungated `markdown` pdf-to-docx / pdf-to-markdown bugfix commit.

## Goal

Commit `61c8ed9` ("bugfix") was pushed directly without the gated cycle: no
backlog entry, no ticket, no `Changes` record, no version bump, and no
verified coverage evidence. Running the coverage gate against it showed
`lib/Markdown/Runner.pm` at `93.4%` statement / `95.0%` subroutine — the new
PDF text-operator handlers (`TJ`/`Td`/`TD`/`T*`/`'`/`"` dispatch), the
ToUnicode CMap paths, the unreadable-PDF error path, the DOCX code-block
branches, and the LibreOffice scratch-dir rename were all unexercised.

This epic brings the shipped change back inside the process: restore the
`100%` coverage gate with real tests, align `README.md`/`docs/`/`Changes`/
version metadata with the implemented behavior, capture cross-platform
verification evidence, and complete the release commit and push.

## Status

Done — see `DD-386`.
