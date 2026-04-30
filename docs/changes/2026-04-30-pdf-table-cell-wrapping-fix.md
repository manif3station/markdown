# PDF Table Cell Wrapping Fix

## What changed

- fixed markdown-to-pdf table cells so long values wrap inside the current cell width
- made PDF table rows grow in height when wrapped table content needs extra lines
- corrected the real `PDF::API2` text-width calculation so runtime wrapping matches the Docker tests

## Why it changed

Long class names, file paths, and action text could overlap adjacent columns in real generated PDFs even though the mocked test path looked correct. The runtime font-width calculation was too small, so the renderer was not wrapping when it should have.

## Proof

- Docker tests and 100% coverage passed
- installed runtime proof with a realistic multi-row markdown table passed
- the rendered first PDF page now shows wrapped cell content instead of horizontal overlap
