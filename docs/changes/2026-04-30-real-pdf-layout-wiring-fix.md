# 2026-04-30 real pdf layout wiring fix

## Summary

Fixed the real default PDF renderer so paper-size and orientation settings reach the `PDF::API2` page setup instead of only appearing in logs and JSON output.

## What Changed

- corrected the default markdown-to-pdf callback wiring so the layout hash reaches the renderer
- added a unit proof that checks the actual `mediabox` arguments for A3 landscape
- added installed runtime proofs that inspect the generated PDF page size on Linux and macOS

## Proof

- Docker tests verify the default renderer uses `1191 x 842` for A3 landscape
- local runtime proof showed `pdfinfo` page size `1191 x 842 pts (A3)`
- macOS runtime proof on `macdev` showed the same `1191 x 842 pts (A3)` page size
