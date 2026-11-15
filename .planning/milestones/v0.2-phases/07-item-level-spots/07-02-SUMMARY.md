---
phase: 07-item-level-spots
plan: 02
subsystem: item-level
tags: [lua, inspect-ui, character-sheet, hooks]
requires:
  - phase: 07-item-level-spots
    provides: ns.ILvlUI installers, ns.ILvl.Inspected, ns.ILvl.OnLearned
provides:
  - Inspect window item level text (installer "inspect")
  - Character sheet Item Level row under Movement Speed (installer "sheet")
affects: [07-03]
tech-stack:
  added: []
  patterns: [EventUtil.ContinueOnAddOnLoaded for load-on-demand UI, post-hook on a stats pane's UpdateStats]
key-files:
  created: []
  modified: [ItemLevelUI.lua, .planning/PROJECT.md]
key-decisions:
  - "Character sheet row is a narrow exception to never writing Blizzard frame fields (elementData + SetDataProvider), logged in PROJECT.md; Option B is the fallback if it taints"
requirements-completed: [ILV-03, ILV-04]
duration: 35min
completed: 2026-11-14
---

# Phase 7 Plan 02: Inspect window text and character sheet row Summary

Gold "Item Level N" at the top right of the Inspect window (the game's own figure, never another player's, empty while unknown) and Blizzard's own Item Level stat under Movement Speed on the player's character sheet, both live-toggled by their settings.

## Accomplishments
- Inspect: FontString (GameFontNormalSmall, gold) on `InspectPaperDollFrame`, created in `ContinueOnAddOnLoaded("Blizzard_InspectUI")`, refreshed from `hooksecurefunc` on `UpdateButtons` and `SetLevel` (plus a 0 s timer), cleared on `OnHide`, up to 3 one-second retries per GUID while the value is unknown, reads only `ns.ILvl.Inspected`. Anchor offsets are named constants to tune in game.
- Sheet: post-hook on `CharacterStatsPaneScrollBox.UpdateStats` inserts `{ name = "ITEMLEVEL", unit = "player" }` after `MOVESPEED` in `elementData` and re-sets the data provider with RetainScrollPosition. In combat nothing is written; `PLAYER_REGEN_ENABLED` rebuilds. Pet pane never touched.
- PROJECT.md Key Decisions row for the sheet exception (outcome pending the in-game check).
- Harness: 22 `ilvl inspect:` and 14 `ilvl sheet:` checks (fallback mode checks the sheet installer reports "missing" without the ScrollBox API); default, `--fallback`, `--attach` all `SUMMARY: 0 failed`. stylua clean, deployed with install.ps1.

## Task Commits
1. Tasks 1-3 (one commit; both spots share one file): 814095c `feat(07-02): item level in the Inspect window and on the character sheet`

## Deviations from Plan
- [Checker note] The sheet installer retries once on `PLAYER_LOGIN` when `CharacterStatsPaneScrollBox` is not defined at load.
- [Checker note] Toggle redraw does not call Blizzard's `pane:UpdateStats()`: `RedrawSheet` inserts into / removes from the existing `elementData` and calls `SetDataProvider` (the same documented exception), so no Blizzard method runs from our code. Plan acceptance `InCombatLockdown()` count of 2 is met by one shared `SyncSheet` guard used by both paths (1 occurrence).
- Harness: the sheet stubs reuse the existing `CreateDataProvider` / `ScrollBoxConstants` stubs (redefining them broke the table tests) and are absent in `--fallback` mode, where the Table's fallback list relies on their absence.

## Known Stubs
None.

## Threat Flags
None beyond the plan's threat model; the sheet write (T-07-06) is the documented exception.

## In-game checks (deferred to milestone end)
1. Sheet taint: `/console taintLog 2`; open the character sheet, equip / unequip, scroll the stats, switch Stats / Equipment / Titles / Pet, enter and leave combat with the sheet open, `/reload` with it open: no `ADDON_ACTION_BLOCKED` or Lua errors naming the addon. Row under Movement Speed for the player only. If it taints, switch to Option B and update the PROJECT.md row.
2. The `SetDataProvider` call from our hook / toggle (we no longer call `UpdateStats`): confirm no taint from it either.
3. Label: row and Inspect text read "Item Level"; the row's tooltip is Blizzard's.
4. Inspect: first inspect after login shows the text; position at the top right does not collide with the level line or close button (tune `INSPECT_X` / `INSPECT_Y`); hover-inspect then click Inspect: right number; yourself: rounded-down figure; PvP / Guild tabs hide the text.
5. Toggle `ilvlInspect` / `ilvlCharacterSheet` (DB edit plus a redraw, or Phase 10 settings): text and row go and come back without a reload.

## Self-Check: PASSED
ItemLevelUI.lua modified, commit 814095c exists, harness 0 failed in all three modes.
