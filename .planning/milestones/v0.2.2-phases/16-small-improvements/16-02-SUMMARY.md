---
phase: 16-small-improvements
plan: 02
subsystem: settings, migration
tags: [meter-reset, settings, migration, schema]
requires: [16-01]
provides:
  - meterResetOnGroup default off (new installs only)
  - ns.Migrate schema 3 step (existing users keep meterResetOnGroup on)
affects: [Settings.lua, Core.lua, CLAUDE.md]
tech-stack:
  added: []
  patterns: [existing user decided by next(db) before any key is cleared or defaulted]
key-files:
  created: [.planning/phases/16-small-improvements/16-HUMAN-UAT.md]
  modified: [Settings.lua, Core.lua, CLAUDE.md]
decisions:
  - "Existing user = the saved table held any key at load (next(db) read first in Migrate); a non-boolean meterResetOnGroup counts as unset"
  - "Settings loop sets default = true only where an option has none; meterResetOnGroup carries default = false"
metrics:
  completed: 2026-11-19
  tasks: 2
  files: 4
requirements: [MTR-08]
---

# Phase 16 Plan 02: Reset-on-group-join off for new installs Summary

`meterResetOnGroup` now defaults to off. Players who already had saved data keep it on, because a one-time schema 3 step in `ns.Migrate` saves `true` for them. Whether a player already existed is decided by `next(db) ~= nil`, read before anything is cleared or defaulted.

## What changed

- **Settings.lua:** the `meterResetOnGroup` option has `default = false`. The registration loop now fills in `default = true` only when an option has no default of its own. The label and tooltip are unchanged.
- **Core.lua:** `DEFAULTS.schema = 3`. `ns.Migrate` reads `existing = next(db) ~= nil` first and still clears `gs` / `autoRefresh` on every load. Below schema 3, for an existing user whose `meterResetOnGroup` is not a boolean, it saves `meterResetOnGroup = true`. Then it sets schema to 3. The old `< 2` block is gone because this step covers it. The ADDON_LOADED order is unchanged (Migrate runs before DEFAULTS).
- **CLAUDE.md:** the Core.lua, Settings.lua and MeterReset.lua lines now describe schema 3 and the new default.
- **16-HUMAN-UAT.md:** 8 in-game checks for the author. They are not blockers.

## TDD

- RED: the harness checks were added first and the run gave `SUMMARY: 10 failed`: schema 3, existing user kept on, fresh table unset, schema-2 / saved false / saved true / junk / v0.1 cases, option defaults, and a fresh DB reading off.
- GREEN: after the code change, `SUMMARY: 0 failed` in the default, `--attach` and `--fallback` modes.

## Commits

- 51512b2 feat(16): reset-on-group-join prompt off for new installs

## Verification

- `stylua --check .` passes
- Harness: 0 failed in all three modes. `meterResetOnGroup` appears in tail.lua 21 times, up from 4
- Grep checks: `schema = 3` x2 and `schema = 2` x0 in Core.lua; `next(db)` x1; `default = false` x1 in Settings.lua; `o.default == nil` on one line. CLAUDE.md has `schema 2` x0, `schema 3` x2 and `all default on:` x0
- No README.md or CHANGELOG.md in the commit. Only the two Media/Screenshots files are untracked
- Deployed with `scripts/install.ps1` (exit 0, v0.2.1-11-g51512b2-dev)

## Deviations from Plan

**1. [Rule 1 - Harness expectation] "settings: nothing written on registration" check**
- **Found during:** Task 1 GREEN
- **Issue:** The harness seeds an existing user's DB, so Migrate now saves `meterResetOnGroup = true` before the settings panel registers. The check saw that key and failed, although registration wrote nothing.
- **Fix:** In the harness only (not committed), the check now accepts `meterResetOnGroup == true`, the value Migrate saved. Every other key must still be nil.

## Self-Check: PASSED
