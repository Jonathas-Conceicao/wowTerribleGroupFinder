---
phase: 07-item-level-spots
verified: 2026-11-14T00:00:00Z
status: human_needed
score: 5/5 must-haves verified (code level); in-client behaviour deferred
overrides_applied: 0
human_verification:
  - test: "Hover friendly players (self, group, stranger) and an enemy / attackable player"
    expected: "Friendly: gold 'Item Level N' appears, filled in after a quiet inspect; enemy/attackable: never a line"
    why_human: "Needs the live client (inspect results, UnitCanAttack)"
  - test: "Hover items in bags, character sheet, chat links, merchant, loot, comparison tooltips, for several seconds"
    expected: "'Item Level N' in gold right under the item name, exactly once; no duplicate with stock type-31 line"
    why_human: "Stock type-31 line presence and line order only visible in the client"
  - test: "Open character sheet with /console taintLog 1, in and out of combat, scroll stats, switch Character/Reputation/Currency tabs"
    expected: "Item Level row directly under Movement Speed with Blizzard's tooltip; no ADDON_ACTION_BLOCKED/FORBIDDEN blamed on TerribleGroupFinder (REVIEW WR-03 still open)"
    why_human: "Taint cannot be observed outside the client; the row is an insecure entry in Blizzard's elementData and is kept in combat after review fix WR-02"
  - test: "Fresh login, inspect another player"
    expected: "Inspect window shows 'Item Level N' at top right on the first inspect; own Inspect window is never blanked by quiet inspects"
    why_human: "Window geometry and first-load hook timing need the client"
---

# Phase 7: Item Level Spots Verification Report

**Phase Goal:** Players see item level, from the game's own figures, wherever they look at gear or at a player
**Status:** human_needed (no code gaps found)
**Re-verification:** No

## Observable Truths

| # | Truth (ROADMAP SC) | Status | Evidence |
|---|--------------------|--------|----------|
| 1 | Friendly player tooltip shows "Item Level N" once known; enemies/attackable never | VERIFIED (code) | `ItemLevelUI.lua:157` registers a Unit tooltip post call; `ItemLevel.lua` has `Hostile` (l.558, UnitCanAttack, fails closed on secret), `RequestInspect` (l.569), `Of` (l.256); setting `ilvlPlayerTooltip` read live |
| 2 | Weapon/armor tooltips show gold "Item Level N" under the name, exactly once | VERIFIED (code) | `ItemLevelUI.lua:486` AddLinePostCall on ItemName, `lastAdd` dedupe per build, skips when stock `LINE_LEVEL` (31) is present, uses `overrideItemLevel`/`GetDetailedItemLevelInfo`, pcall-wrapped. Actual line order and stock type-31 behaviour need the client |
| 3 | Sheet General stats row under Movement Speed, Blizzard tooltip, no taint | VERIFIED (code) / taint UNCERTAIN | `ItemLevelUI.lua:311-331` inserts `ITEMLEVEL` after `MOVESPEED` and calls `SetDataProvider`; gamepad path excluded. Taint is review WR-03, explicitly open |
| 4 | Inspect window shows item level at top right, also first inspect after login | VERIFIED (code) | `ItemLevelUI.lua:233-274` FontString anchored TOPRIGHT of InspectFrame; hooks installed on Blizzard_InspectUI load; reads `ILvl.Inspected(unit)` |
| 5 | Quiet inspects never disturb the player's Inspect window; no wrong-player value | VERIFIED (code) | `ItemLevel.lua:407-417` `InspectOpen` (shown or pending within INSPECT_WAIT), `ClearInspectPlayer` at l.454 only when not open and serial/othersAt match (CR-01 fix); `Inspected` answers only for the answered GUID; IN-04 late answers dropped |

**Score:** 5/5 truths verified at code level.

## Required Artifacts

| Artifact | Status | Details |
|----------|--------|---------|
| `ItemLevel.lua` (736 lines) | VERIFIED | Substantive; in TOC; `ILvl.Init()` called from `Core.lua:280` |
| `ItemLevelUI.lua` (495 lines) | VERIFIED | Substantive; in TOC; `ILvlUI.Init()` called from `Core.lua:281`; four spots installed via `UI.Install` |
| `Settings.lua` toggles | VERIFIED | `ilvlPlayerTooltip`, `ilvlItemTooltip`, `ilvlCharacterSheet`, `ilvlInspect` present (l.120-123) |

## Behavioral Spot-Checks

| Check | Command | Result | Status |
|-------|---------|--------|--------|
| Smoke harness default | `node run.js <repo> ""` | SUMMARY: 0 failed | PASS |
| Smoke harness fallback | `node run.js <repo> --fallback` | SUMMARY: 0 failed | PASS |
| Smoke harness attach | `node run.js <repo> --attach` | SUMMARY: 0 failed | PASS |

## Requirements Coverage

| Requirement | Plan | Status | Evidence |
|-------------|------|--------|----------|
| ILV-01 | 07-01 | SATISFIED (code) | Player tooltip + quiet inspect queue |
| ILV-02 | 07-03 | SATISFIED (code) | Item tooltip line post-call |
| ILV-03 | 07-02 | SATISFIED (code), taint pending | Character sheet row |
| ILV-04 | 07-02 | SATISFIED (code) | Inspect window text |
| ILV-05 | 07-01 | SATISFIED (code) | InspectOpen guard, ClearInspectPlayer guard, GUID-bound `Inspected` |

All five IDs are claimed by plans and none are orphaned. Housekeeping: REQUIREMENTS.md traceability still shows ILV-02, ILV-03 and ILV-04 as "Pending" (l.83-85), and their checkboxes at l.18-22 are marked `[x]`, so the table should be updated to Complete.

## Anti-Patterns

No TBD/FIXME/XXX markers in `ItemLevel.lua` or `ItemLevelUI.lua`. No stubs found.

## Gaps Summary

No code gaps. Remaining risk is in-client only: sheet row taint (WR-03 open, with fallback options recorded in 07-REVIEW.md), item tooltip duplicate/ordering against stock type-31 lines, and Inspect text positioning. These are deferred by the author to milestone end.
