# 2026-04-30 positional cli and progress update

`markdown.convert` now uses positional file arguments as the primary interface.

## What changed

- the first positional file is the source
- the optional second positional file is the output target
- the target format is inferred from the output file extension
- html and pdf input still default to markdown output when no target is provided
- conversion progress now prints to `stderr` during each step

## Result

The command is shorter to use, and long conversions no longer appear idle because the skill reports the active step and command path.
