---
phase: 06-gear-score-removal-and-settings-foundation
plan: 02
subsystem: core
tags: [settings, migration, saved-variables]
requires: [06-01]
provides:
  - "ns.Settings registry (Register, List, Init, Get, Set, OnChange) with seven flat boolean keys, all default on"
  - "ns.Migrate: schema 2, clears v0.1 gs and prototype autoRefresh in place"
affects: [08, 09, 10]
tech-stack:
  added: []
  patterns: ["live Get at the point of use (never cached)", "in-place saved-data migration before every module Init"]
key-files:
  created: [Settings.lua]
  modified: [Core.lua, TerribleGroupFinder.toc, CLAUDE.md]
key-decisions:
  - "Old autoRefresh key is cleared by the migration, not mapped (it never shipped)"
  - "Settings live on ns.Settings; Blizzard's global Settings is never touched"
requirements-completed: [GSR-01]
duration: 15min
completed: 2026-11-14
---

# Phase 6 Plan 2: Settings Registry and Schema-2 Migration Summary

`Settings.lua` adds `ns.Settings` with the seven toggles (`ilvlPlayerTooltip`, `ilvlItemTooltip`, `ilvlCharacterSheet`, `ilvlInspect`, `dynamicRefresh`, `swipeAnimations`, `regionFlags`), and `Core.lua` migrates saved data to schema 2 before any module initialises.

## Tasks

1. Settings.lua, TOC line after Core.lua, `ns.Migrate` and the new ADDON_LOADED order: Migrate, defaults, `Settings.Init`, modules (commit in the single feat commit below)
2. Harness checks (migration, settings, `/tgf reset`), CLAUDE.md lines, install verified

Both tasks went into one commit: `feat(06-02): settings registry and schema-2 migration` (see git log).

## Verification

- Harness default, `--fallback`, `--attach`: `SUMMARY: 0 failed`, including in-place migration, gs and autoRefresh cleared, seven defaults on fresh and migrated DBs, Get before Init, live Get, listener isolation, `/tgf reset` keeping the same DB.
- `stylua --check .` clean; `scripts/install.ps1` deployed `Settings.lua`.
- Only one assignment of `TerribleGroupFinderDB` remains (the guarded first-load one).
- In-game UAT (v0.1 SavedVariables file loses `gs`, seven keys true) is still for the author.

## Deviations from Plan

None. The plan was executed as written.

## Known Stubs

None. No settings UI yet by design (Phase 10).

## Self-Check: PASSED
