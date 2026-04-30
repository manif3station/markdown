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
  - Test count: `Files=4, Tests=68`
- Coverage test:
  - `docker compose -f ~/projects/skills/docker-compose.testing.yml run --rm perl-test bash -lc 'cd /workspace/skills/markdown && cover -delete && HARNESS_PERL_SWITCHES=-MDevel::Cover prove -lr t && cover -report text -select_re "^lib/" -coverage statement -coverage subroutine'`
  - Result: pass
  - Coverage: `100.0%` statement and `100.0%` subroutine for `lib/Markdown/CLI.pm` and `lib/Markdown/Runner.pm`
- Installed DD proof:
  - The installed skill tree was synced into `~/.developer-dashboard/skills/sk/skills/markdown/` so the real `dashboard markdown.convert` command path could be proven on this host without depending on privileged package installation steps
  - `PATH="/tmp/markdown-weasyprint-proof.XXXXXX/fake-bin:$PATH" dashboard markdown.convert --from /tmp/markdown-weasyprint-proof.XXXXXX/note.md --pdf`
  - Result: pass, produced `/tmp/markdown-weasyprint-proof.XXXXXX/note.pdf` with only `weasyprint` present as the pdf backend
  - `PATH="/tmp/markdown-weasyprint-proof.XXXXXX/fake-bin:$PATH" dashboard markdown.convert --from /tmp/markdown-weasyprint-proof.XXXXXX/note.pdf`
  - Result: pass, produced `/tmp/markdown-weasyprint-proof.XXXXXX/note.md`
- Homebrew package proof:
  - `curl -fsSL https://formulae.brew.sh/api/formula/weasyprint.json | jq -r '[.name, .versions.stable] | @tsv'`
  - Result: pass, returned `weasyprint` with stable version `68.1`
  - `curl -fsSL https://formulae.brew.sh/api/formula/wkhtmltopdf.json`
  - Result: fail with `404`, confirming the old Homebrew package path is not currently available
- macOS install and runtime proof:
  - `scp` copied the current local skill snapshot to `macdev:/tmp/markdown.tgz`
  - `ssh macdev 'zsh -lic "cd /tmp/markdown-proof/markdown && dashboard skills install /tmp/markdown-proof/markdown"'`
  - Result: pass, installed `markdown` at version `0.02`
  - `ssh macdev "zsh -lic '... dashboard markdown.convert --from \"$tmpdir/note.md\" --pdf; dashboard markdown.convert --from \"$tmpdir/note.pdf\" ...'"`
  - Result: pass, produced `note.pdf` and restored markdown from that pdf
  - `ssh macdev "zsh -lic '... dashboard markdown.convert --from \"$tmpdir/page.md\" --html ...'"`
  - Result: pass, produced `page.html`
- Cleanup:
  - `docker compose -f ~/projects/skills/docker-compose.testing.yml run --rm perl-test bash -lc 'rm -rf /workspace/skills/markdown/cover_db'`
  - Result: pass
