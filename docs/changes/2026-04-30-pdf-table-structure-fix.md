# 2026-04-30 pdf table structure fix

## Summary

Fixed markdown-to-pdf table rendering so markdown tables are drawn as visible table structures instead of being flattened into plain text lines.

## What Changed

- the pdf renderer now draws table cell rectangles for markdown pipe tables
- table cells now wrap long text within the cell width
- inline markdown markers such as backticks are stripped from table cell text before drawing
- page-break handling was added for tall tables so the renderer can continue on a new page

## Proof

- Docker unit tests verify rectangle drawing and table text rendering
- local DD installed proof passed with a realistic four-column sample table
- macOS installed proof on `macdev` passed with the same table sample
