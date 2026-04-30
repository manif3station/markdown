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
  - Test count: `Files=5, Tests=92`
- Coverage test:
  - `docker compose -f ~/projects/skills/docker-compose.testing.yml run --rm perl-test bash -lc 'cd /workspace/skills/markdown && cover -delete && HARNESS_PERL_SWITCHES=-MDevel::Cover prove -lr t && cover -report text -select_re "^lib/" -coverage statement -coverage subroutine'`
  - Result: pass
  - Coverage: `100.0%` statement and `100.0%` subroutine for `lib/Markdown/CLI.pm`, `lib/Markdown/Enhancer.pm`, and `lib/Markdown/Runner.pm`
- Installed DD proof:
  - `dashboard skills install ~/projects/skills/skills/markdown`
  - Result: pass, updated installed skill from `0.04` to `0.05`
  - `dashboard markdown.convert /tmp/markdown-proof.XXXXXX/report.md /tmp/markdown-proof.XXXXXX/report.html`
  - Result: pass, output html contained a real `<table>` and `<code>token</code>`
  - `dashboard markdown.convert /tmp/markdown-proof.XXXXXX/report.md /tmp/markdown-proof.XXXXXX/report.pdf`
  - Result: pass, extracted PDF text was `Name Value alpha beta Use token here.` with no raw pipe or backtick syntax
- macOS install and runtime proof:
  - `ssh macdev 'zsh -lic "dashboard skills install /tmp/markdown-mac-proof/markdown"'`
  - Result: pass, updated installed skill from `0.04` to `0.05`
  - `ssh macdev 'zsh -lic "dashboard markdown.convert .../report.md .../report.html"'`
  - Result: pass, output html contained a real `<table>` and `<code>token</code>`
  - `ssh macdev 'zsh -lic "dashboard markdown.convert .../report.md .../report.pdf"'`
  - Result: pass, extracted PDF text was `Name Value alpha beta Use token here.` with no raw pipe or backtick syntax
- Cleanup:
  - `docker compose -f ~/projects/skills/docker-compose.testing.yml run --rm perl-test bash -lc 'rm -rf /workspace/skills/markdown/cover_db'`
  - Result: pass
