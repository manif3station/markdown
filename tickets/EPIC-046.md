# EPIC-046

## Title

Add DOCX and markdown round-trip routes to the `markdown` skill.

## Status

Done

## Outcome

Extend `dashboard markdown.convert` so `.docx` can recover markdown by default and markdown can target `.docx` explicitly while reusing the existing PDF and office-document backends.

## Tickets

- `DD-073` Add `.docx -> .md` and `.md -> .docx` routes to `dashboard markdown.convert`
