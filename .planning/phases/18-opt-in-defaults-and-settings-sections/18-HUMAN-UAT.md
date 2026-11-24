---
status: partial
phase: 18-opt-in-defaults-and-settings-sections
source: [18-VERIFICATION.md]
started: 2026-11-24
updated: 2026-11-24
---

## Current Test

[awaiting the author's in-game pass at the end of the milestone]

## Tests

### 1. Fresh install defaults
expected: with no saved file (rename `TerribleGroupFinder.lua` in SavedVariables), no item level text on tooltips / sheet / Inspect, no talent line, no meter prompt; the finder's table, Dynamic refresh with swipes and region flags work
result: [pending]

### 2. Existing player keeps their options
expected: with a v0.2.2 saved file (including one holding only `schema = 3`), everything that showed before still shows; an option the player had turned off stays off; the new slot options are off
result: [pending]

### 3. Settings page order
expected: Settings > AddOns > TerribleGroupFinder shows Group finder (Elite quest button, Dynamic refresh > Swipe animations, Region flags), Player inspection (Player tooltips, Talent points, Item tooltips, Character sheet, Inspect window, Slot item level, Slot enchants), Damage meter (two prompts, Move), Messages
result: [pending]

### 4. New keys settable
expected: `/tgf set eliteQuestButton off`, `/tgf set slotItemLevel on`, `/tgf set slotEnchants on` print the change and the open page's checkboxes follow
result: [pending]

## Summary

total: 4
passed: 0
issues: 0
pending: 4
skipped: 0
blocked: 0

## Gaps
