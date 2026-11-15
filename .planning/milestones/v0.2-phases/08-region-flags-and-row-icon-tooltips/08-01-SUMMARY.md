---
phase: 08-region-flags-and-row-icon-tooltips
plan: 01
subsystem: region
tags: [region, flags, tooltip, settings]
requires: []
provides: [R.ForListing, R.Line, R.Flag, R.MarkupFor, R.Enabled]
affects: [UI/Table.lua, Core.lua, Region.lua, CLAUDE.md]
key-files:
  modified: [Region.lua, Core.lua, UI/Table.lua, CLAUDE.md]
decisions:
  - One US flag for US1 and US2; no E / W letter
  - Seeded shards win; learned ones only fill gaps and are sanitized on load
  - Own listing = leader's region (yours when solo or leading)
metrics:
  completed: 2026-11-14
---

# Phase 8 Plan 01: Region flags Summary

Region flags finished: one US flag for both US groups, a plain-word region line in the row tooltip, a flag on your own listing (the leader's region), seeded-first lookup with saved learned shards, all gated live by `regionFlags`.

## Commits
- 423adad: Region.lua rework (ForListing, Line, Flag, MarkupFor, Enabled; Init sanitizes DB.shards and hooks the regionFlags redraw)
- cb22d74: Table wiring (FillRow, ExtrasTooltip), preview own entry `shard = 6934`, CLAUDE.md Region line

## Deviations from Plan
None. The smoke harness (outside the repo) got 30+ "region:" checks; all three modes (default, --fallback, --attach) print `SUMMARY: 0 failed`; `stylua --check .` passes.

## Deferred in-game checks (milestone end)
- Own shard from `GetRealmID()` / `UnitGUID("player")` matches the probe; as a party member the own row shows the leader's region
- Solo listings' `partyGUID` gives a flag; unknown shard shows nothing
- Confirm US1 = West / US2 = East with an independent signal
- `/reload` keeps learned shards; toggling `regionFlags` redraws without a reload (Phase 10's page)
- Flag textures present in the packaged zip (`scripts/package.bat`)

## Known Stubs
None.

## Self-Check: PASSED
