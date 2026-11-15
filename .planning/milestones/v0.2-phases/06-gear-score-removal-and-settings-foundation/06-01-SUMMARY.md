---
phase: 06-gear-score-removal-and-settings-foundation
plan: 01
subsystem: ui
tags: [gear-score, removal, table, preview]
requires: []
provides:
  - "Addon with no gear score code (GearScore.lua, GS column, sort, Your GS, tooltip lines, ready-check inspects)"
affects: [06-02, 08, 09]
tech-stack:
  added: []
  patterns: []
key-files:
  created: []
  modified: [Core.lua, Preview.lua, TerribleGroupFinder.toc, UI/Table.lua, UI/Widgets.lua, CLAUDE.md]
  deleted: [GearScore.lua]
key-decisions:
  - "Saved gs data left untouched here; Plan 02's schema-2 migration clears it"
requirements-completed: [GSR-01]
duration: 20min
completed: 2026-11-14
---

# Phase 6 Plan 1: Gear Score Removal Summary

Gear score is deleted from the addon: `GearScore.lua` and its TOC line are gone, along with every `ns.GS` / `GEAR_SCORE` reference in Core, Widgets, Table and Preview. `.planning/research/GEARSCORE.md` is kept as history.

## Tasks

1. Delete GearScore.lua and strip Core, Widgets, Preview, TOC (commit 4d27df6)
2. Strip gear score from UI/Table.lua: column, sort, tooltip lines, Your GS; Activity now fixed at x = 292; tooltip right text is zone-only (commit 4d27df6)
3. Harness updated (`--gs` mode dropped, new removal checks), CLAUDE.md updated, install verified (commit 4d27df6)

All three tasks went into a single commit, `4d27df6`, because the plan asks for the removal as one change.

## Verification

- Smoke harness: default, `--fallback`, `--attach` each `SUMMARY: 0 failed`, including the new checks (ns.GS gone, GearScore.lua not in the TOC, no READY_CHECK listener, preview samples carry no gs).
- `git grep` for `ns.GS|GEAR_SCORE|GS(|row.gs|myGS` over lua/toc/xml is clean.
- `stylua --check .` clean; `scripts/install.ps1` deployed and pruned the stale `GearScore.lua`.
- Preview sample count unchanged (35 listings).
- In-game UAT (no GS column, no Your GS, zones on group tooltips, no inspects on ready check) is still to be done by the author.

## Deviations from Plan

None. The plan was executed as written.

## Known Stubs

None.

## Self-Check: PASSED
