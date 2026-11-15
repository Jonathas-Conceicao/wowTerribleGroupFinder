---
status: complete
phase: 10-settings-window
source: [10-VERIFICATION.md, 10-REVIEW.md]
started: 2026-11-14T20:00:00Z
updated: 2026-11-15T12:00:00Z
---

## Current Test

[complete: the author passed every check in game, 2026-11-15]

## Tests

### 1. Settings page
expected: Settings > AddOns > TerribleGroupFinder shows the sections Item level / Group finder / Messages; `/tgf settings` and `/tgf config` open it (finder closed, open, right after `/reload`); in combat they print a message; no taint on the Settings panel (`/console taintLog 2`)
result: pass

### 2. Toggles live
expected: Each checkbox changes its feature at once (player / item tooltips, character sheet row, Inspect text, Dynamic refresh, Swipe animations — greyed while Dynamic refresh is off —, region flags); `/tgf set regionflags off` with the page open updates the checkbox
result: pass

### 3. Edit whisper messages
expected: Pressing the button with Settings open prints a hint; closing Settings opens the group finder on the Messages tab; in game it never opens the preview window
result: pass

### 4. Saved
expected: Choices survive `/reload` and relogging; a fresh install has every option on
result: pass

## Summary

total: 4
passed: 4
issues: 0
pending: 0
skipped: 0
blocked: 0

## Gaps
