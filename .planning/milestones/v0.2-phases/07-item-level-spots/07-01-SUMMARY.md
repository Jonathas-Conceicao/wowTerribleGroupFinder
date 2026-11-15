---
phase: 07-item-level-spots
plan: 01
subsystem: item-level
tags: [lua, inspect, tooltip, guard]
requires:
  - phase: 06-gear-score-removal-and-settings-foundation
    provides: ns.Settings.Get with the ilvl* keys
provides:
  - ns.ILvl.OnLearned, ns.ILvl.Inspected, ns.ILvl.RequestInspect (public data API)
  - ns.ILvlUI framework: Text, Gold, Install, Init, failed
  - player tooltip spot behind ilvlPlayerTooltip
affects: [07-02, 07-03]
tech-stack:
  added: []
  patterns: [independent pcall-guarded spot installers, hooksecurefunc-only inspect tracking]
key-files:
  created: [ItemLevelUI.lua]
  modified: [ItemLevel.lua, TerribleGroupFinder.toc, Core.lua]
key-decisions:
  - "An INSPECT_READY for a GUID that is not the latest inspect's target is ignored (it does not displace our pending inspect)"
requirements-completed: [ILV-01, ILV-05]
duration: 40min
completed: 2026-11-14
---

# Phase 7 Plan 01: Item level data split, inspect guard, player tooltip spot Summary

ItemLevel.lua is now data only (read, average, queue, probe, OnLearned observers); the quiet inspect cannot disturb the player's Inspect window or store another player's value; the friendly player tooltip line moved to the new ItemLevelUI.lua behind `ilvlPlayerTooltip`.

## Accomplishments
- Guard: busy while `InspectFrame` is shown or `InspectFrame.unit` is set, in combat, or within 2 s of a `NotifyInspect` / `InspectUnit` that is not ours (hooksecurefunc only). Serial counter plus latest-target GUID: a displaced inspect stores nothing, clears nothing and is not marked tried; `ClearInspectPlayer` only when the window is closed and no later inspect started. GUID checked at answer and read time.
- `ILvl.Inspected(unit)`: the game's figure only while the latest inspect answered for that GUID, else the session cache, yours rounded down.
- `ItemLevelUI.lua`: `Text`, `Gold`, `Install` (records `failed[name]`), `Init`; player tooltip spot reads the setting live, refreshes the open tooltip via `OnLearned`.
- `/tgf ilvl` also prints `spot <name> failed: <error>` for failed installers.
- Harness: 29 new `ilvl guard:` checks; default, `--fallback`, `--attach` all `SUMMARY: 0 failed`. stylua clean, deployed with install.ps1.

## Task Commits
1. Tasks 1-3 (one commit, the tooltip moved between files): b1fe943 `feat(07-01): item level data split, quiet inspect guard, player tooltip spot`

## Deviations from Plan
- A stale INSPECT_READY (GUID not the latest target and not ours) returns early instead of displacing our pending inspect; the plan's literal wording would have dropped a good pending inspect. Minimal and safer.
- Tasks committed together (the tooltip code moves across both files, so a split commit would have no working tooltip). The harness test restores `ilvlPlayerTooltip` to unset so the settings "nothing written" check still holds.

## Known Stubs
None.

## In-game checks (deferred to milestone end)
1. Hover a friendly player: line appears after the quiet inspect; an enemy / attackable player never gets one.
2. Hover several players, then click Inspect on one right away: the window shows that player's gear, never blank.
3. Close the Inspect window while a quiet inspect is pending: no error, window data not wiped.
4. `/tgf ilvl` in a group: probe output as before, no "spot ... failed" lines.
5. `/run TerribleGroupFinderDB.ilvlPlayerTooltip=false` then hover: no line, no inspect.

## Self-Check: PASSED
ItemLevelUI.lua exists; commit b1fe943 exists.
