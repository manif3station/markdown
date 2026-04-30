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
  - Test count: `Files=4, Tests=73`
- Coverage test:
  - `docker compose -f ~/projects/skills/docker-compose.testing.yml run --rm perl-test bash -lc 'cd /workspace/skills/markdown && cover -delete && HARNESS_PERL_SWITCHES=-MDevel::Cover prove -lr t && cover -report text -select_re "^lib/" -coverage statement -coverage subroutine'`
  - Result: pass
  - Coverage: `100.0%` statement and `100.0%` subroutine for `lib/Markdown/CLI.pm` and `lib/Markdown/Runner.pm`
- Installed DD proof:
  - `dashboard skills install ~/projects/skills/skills/markdown`
  - Result: pass, installed skill already at `0.04`
  - `dashboard markdown.convert /tmp/markdown-allperl-proof.XXXXXX/note.md /tmp/markdown-allperl-proof.XXXXXX/note.html`
  - Result: pass, produced json on `stdout` and Perl-step logs on `stderr`
  - `dashboard markdown.convert /tmp/markdown-allperl-proof.XXXXXX/note.md /tmp/markdown-allperl-proof.XXXXXX/note.pdf`
  - Result: pass, produced json on `stdout` and Perl-step logs on `stderr`
  - `dashboard markdown.convert /tmp/markdown-allperl-proof.XXXXXX/note.pdf`
  - Result: pass, produced `/tmp/markdown-allperl-proof.XXXXXX/note.md` with Perl-step logs on `stderr`
- macOS install and runtime proof:
  - `ssh macdev 'zsh -lic "dashboard skills install /tmp/markdown-allperl2/markdown"'`
  - Result: pass, installed skill already at `0.04`
  - `ssh macdev "zsh -lic '... dashboard markdown.convert \"$tmpdir/note.md\" \"$tmpdir/note.html\" ...'"`
  - Result: pass, produced `note.html` and Perl-step logs on `stderr`
  - `ssh macdev "zsh -lic '... dashboard markdown.convert \"$tmpdir/note.md\" \"$tmpdir/note.pdf\" ...'"`
  - Result: pass, produced `note.pdf` and Perl-step logs on `stderr`
  - `ssh macdev "zsh -lic '... dashboard markdown.convert \"$tmpdir/note.pdf\" ...'"`
  - Result: pass, restored markdown from that pdf and printed progress logs
- Cleanup:
  - `docker compose -f ~/projects/skills/docker-compose.testing.yml run --rm perl-test bash -lc 'rm -rf /workspace/skills/markdown/cover_db'`
  - Result: pass
