# Overview

`markdown` is a CLI conversion skill for documentation files.

It exists so DD users can move content between markdown, html, and pdf without building one-off shell pipelines each time they need a new copy format.

The current supported routes are:

- markdown to html
- markdown to pdf
- html to markdown
- pdf to markdown

The skill uses `pandoc` as the main bridge, `wkhtmltopdf` for pdf generation, and `pdftohtml` when recovering markdown from pdf input.
