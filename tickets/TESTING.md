# Testing

## Policy

- tests run only inside Docker
- the shared test container definition lives at the workspace root
- this skill keeps its test files in `t/`

## Commands

```bash
docker compose -f ~/projects/skills/docker-compose.testing.yml run --rm perl-test bash -lc 'cd /workspace/skills/markdown && prove -lr t'
docker compose -f ~/projects/skills/docker-compose.testing.yml run --rm perl-test bash -lc 'cd /workspace/skills/markdown && cover -delete && HARNESS_PERL_SWITCHES=-MDevel::Cover prove -lr t && cover -report text -select_re "^lib/" -coverage statement -coverage subroutine'
```

## Latest Verification

- Date: 2026-04-30
- Functional test:
  - `docker compose -f ~/projects/skills/docker-compose.testing.yml run --rm perl-test bash -lc 'cd /workspace/skills/markdown && prove -lr t'`
  - Result: pass
  - Test count: `Files=5, Tests=193`
- Coverage test:
  - `docker compose -f ~/projects/skills/docker-compose.testing.yml run --rm perl-test bash -lc 'cd /workspace/skills/markdown && cover -delete && HARNESS_PERL_SWITCHES=-MDevel::Cover prove -lr t && cover -report text -select_re "^lib/" -coverage statement -coverage subroutine'`
  - Result: pass
  - Coverage: `100.0%` statement and `100.0%` subroutine for `lib/Markdown/CLI.pm`, `lib/Markdown/Enhancer.pm`, and `lib/Markdown/Runner.pm`
- Installed DD proof:
  - `dashboard skills install ~/projects/skills/skills/markdown`
  - Result: pass, updated installed skill from `0.10` to `0.11` during proof
  - `dashboard markdown.convert /tmp/markdown-layout-proof.XXXXXX/report.md /tmp/markdown-layout-proof.XXXXXX/report.html`
  - Result: pass, generated html emitted `<table border="1">`
  - `dashboard markdown.convert /tmp/markdown-layout-proof.XXXXXX/report.md /tmp/markdown-layout-proof.XXXXXX/report.pdf -A 3 --landscape`
  - Result: pass, json result reported `paper=A3` and `orientation=landscape`, and `pdfinfo` reported `1191 x 842 pts (A3)`
  - `dashboard markdown.convert /tmp/markdown-paper-proof.md /tmp/markdown-paper-a0.pdf -A 0`
  - Result: pass, `pdfinfo` reported `2384 x 3370 pts (A0)`
  - `dashboard markdown.convert /tmp/markdown-paper-proof.md /tmp/markdown-paper-b10.pdf --paper B10`
  - Result: pass, `pdfinfo` reported `88 x 125 pts`
  - `dashboard markdown.convert /tmp/markdown-paper-proof.md /tmp/markdown-paper-c7.pdf --paper C7`
  - Result: pass, `pdfinfo` reported `230 x 323 pts`
  - `dashboard markdown.convert /tmp/markdown-paper-proof.md /tmp/markdown-paper-dl.pdf --paper DL`
  - Result: pass, `pdfinfo` reported `312 x 624 pts`
  - `dashboard markdown.convert /tmp/markdown-paper-proof.md /tmp/markdown-paper-ansi-d.pdf --paper ANSI-D`
  - Result: pass, `pdfinfo` reported `1584 x 2448 pts`
  - `dashboard markdown.convert /tmp/markdown-overlap-sample.md /tmp/markdown-overlap-sample.pdf`
  - Result: pass, a rendered PNG proof of page 1 showed long class names, test filenames, and status text wrapped inside their own cells with taller rows and no cross-column overlap
  - `dashboard markdown.convert /tmp/markdown-layout-proof.XXXXXX/report.md /tmp/markdown-layout-proof.XXXXXX/bad.pdf --paper A4 -A 3`
  - Result: pass, command failed clearly with `Choose only one paper size selection`
- macOS install and runtime proof:
  - `ssh macdev 'zsh -lic "dashboard skills install /tmp/markdown-mac-proof/markdown"'`
  - Result: pass, updated installed skill to `0.11` during proof
  - `ssh macdev 'zsh -lic "dashboard markdown.convert .../report.md .../report.html"'`
  - Result: pass, generated html emitted `<table border="1">`
  - `ssh macdev 'zsh -lic "dashboard markdown.convert .../report.md .../report.pdf -A 3 --landscape"'`
  - Result: pass, json result reported `paper=A3` and `orientation=landscape`, and `pdfinfo` reported `1191 x 842 pts (A3)`
  - `ssh macdev 'zsh -lic "dashboard markdown.convert /tmp/markdown-paper-proof.md /tmp/markdown-paper-a0.pdf -A 0"'`
  - Result: pass, `pdfinfo` reported `2384 x 3370 pts (A0)`
  - `ssh macdev 'zsh -lic "dashboard markdown.convert /tmp/markdown-paper-proof.md /tmp/markdown-paper-dl.pdf --paper DL"'`
  - Result: pass, `pdfinfo` reported `312 x 624 pts`
  - `ssh macdev 'zsh -lic "dashboard markdown.convert /tmp/markdown-paper-proof.md /tmp/markdown-paper-ansi-d.pdf --paper ANSI-D"'`
  - Result: pass, `pdfinfo` reported `1584 x 2448 pts`
  - `ssh macdev 'zsh -lic "dashboard markdown.convert /tmp/markdown-overlap-sample.md /tmp/markdown-overlap-sample.pdf"'`
  - Result: pass, `pdftotext` showed wrapped long class names, test filenames, and multi-line status text instead of a single overlapped row
  - `ssh macdev 'zsh -lic "dashboard markdown.convert .../report.md .../bad.pdf --paper A4 -A 3"'`
  - Result: pass, command failed clearly with `Choose only one paper size selection`
- Cleanup:
  - `docker compose -f ~/projects/skills/docker-compose.testing.yml run --rm perl-test bash -lc 'rm -rf /workspace/skills/markdown/cover_db'`
  - Result: pass
