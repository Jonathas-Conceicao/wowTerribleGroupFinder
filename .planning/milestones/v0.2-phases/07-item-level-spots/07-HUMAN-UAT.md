---
status: complete
phase: 07-item-level-spots
source: [07-VERIFICATION.md, 07-REVIEW.md]
started: 2026-11-14T14:00:00Z
updated: 2026-11-15T12:00:00Z
---

## Current Test

[complete: the author passed every check in game, 2026-11-15, after the sheet row moved under Movement Speed with the native look and the Inspect text was raised 3 px]

## Tests

### 1. Player tooltip
expected: Hovering a friendly player (yourself included) shows gold "Item Level N" once known (a quiet inspect fills it in); enemies and attackable players never get a line; opening the Inspect window right after hovering is never blanked
result: pass

### 2. Item tooltips
expected: Weapon / armor tooltips (bags, character sheet, Inspect, chat link, merchant, loot, comparison) show gold "Item Level N" directly under the name, exactly once, still once after hovering ~3 s; bags / ammo / shirts / tabards get none. Also check whether Forever already sends its own item level line: `/dump C_TooltipInfo.GetInventoryItem("player", 16).lines` (a line of type 31 means ours stays off)
result: pass

### 3. Character sheet row (taint)
expected: (Changed after the in-game taint error "TextStatusBar.lua:110: attempt to compare a secret number value (execution tainted by 'TerribleGroupFinder')": the row inserted into Blizzard's stats list was replaced by our own row.) `/console taintLog 1`, then open the sheet: our "Item Level N" row sits in the strip at the bottom of the stats pane (label gold left, value right; hover shows equipped / best owned); opening the sheet, equipping gear, scrolling, switching tabs, entering and leaving combat with it open, `/reload` with it open: no Lua errors and nothing "tainted by TerribleGroupFinder"; tune `SHEET_INSET` / `SHEET_Y` in `ItemLevelUI.lua` if the row sits badly
result: pass

### 4. Inspect window text
expected: Inspecting a player shows gold "Item Level N" at the top right of the gear panel (not over the level text), also on the first inspect after login; empty while unknown; tune `INSPECT_X` / `INSPECT_Y` in `ItemLevelUI.lua` if misplaced
result: pass

### 5. Settings off (live)
expected: `/run TerribleGroupFinderDB.ilvlCharacterSheet=false` (and the other three keys) then reopening the sheet / Inspect window / hovering hides that spot without a reload (the settings page arrives in Phase 10)
result: pass

## Summary

total: 5
passed: 5
issues: 0
pending: 0
skipped: 0
blocked: 0

## Gaps
