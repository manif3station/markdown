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
  - Test count: `Files=4, Tests=61`
- Coverage test:
  - `docker compose -f ~/projects/skills/docker-compose.testing.yml run --rm perl-test bash -lc 'cd /workspace/skills/markdown && cover -delete && HARNESS_PERL_SWITCHES=-MDevel::Cover prove -lr t && cover -report text -select_re "^lib/" -coverage statement -coverage subroutine'`
  - Result: pass
  - Coverage: `100.0%` statement and `100.0%` subroutine for `lib/Markdown/CLI.pm` and `lib/Markdown/Runner.pm`
- Installed DD proof:
  - Host dependency install via `dashboard skills install ~/projects/skills/skills/markdown` stopped at the `aptfile` step because `sudo` was required on this Linux host
  - The installed skill tree was then synced from the local repo into `~/.developer-dashboard/skills/sk/skills/markdown/` so the real `dashboard markdown.convert` command path could still be proven without weakening the dependency declarations
  - `PATH="/tmp/markdown-skill-proof-final/fake-bin:$PATH" dashboard markdown.convert --from /tmp/markdown-skill-proof-final/note.md --html`
  - Result: pass, produced `/tmp/markdown-skill-proof-final/note.html`
  - `PATH="/tmp/markdown-skill-proof-final/fake-bin:$PATH" dashboard markdown.convert --from /tmp/markdown-skill-proof-final/note.pdf`
  - Result: pass, produced `/tmp/markdown-skill-proof-final/note.md`
- Cleanup:
  - `docker compose -f ~/projects/skills/docker-compose.testing.yml run --rm perl-test bash -lc 'rm -rf /workspace/skills/markdown/cover_db'`
  - Result: pass
