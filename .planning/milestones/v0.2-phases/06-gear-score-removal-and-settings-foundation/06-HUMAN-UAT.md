---
status: complete
phase: 06-gear-score-removal-and-settings-foundation
source: [06-VERIFICATION.md]
started: 2026-11-14T12:00:00Z
updated: 2026-11-15T12:00:00Z
---

## Current Test

[complete: the author passed every check in game, 2026-11-15]

## Tests

### 1. v0.1 saved data loads clean
expected: With a SavedVariables file from v0.1 (it has `gs` data), `/reload` shows no Lua errors; after logout the saved file no longer has `gs` (or `autoRefresh`), and `schema = 2`
result: pass

### 2. No gear score anywhere in the finder
expected: Browse (in game and `/tgf preview`) shows no GS column, no GS sort, no "Your GS", no gear score tooltip lines
result: pass

### 3. No inspects after a ready check
expected: In a group, a ready check does not inspect group members (only hovering a friendly player's tooltip inspects, for item level)
result: pass

## Summary

total: 3
passed: 3
issues: 0
pending: 0
skipped: 0
blocked: 0

## Gaps
