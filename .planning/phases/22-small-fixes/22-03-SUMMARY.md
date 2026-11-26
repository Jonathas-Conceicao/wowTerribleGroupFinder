---
phase: 22-small-fixes
plan: 03
subsystem: group-finder-search
tags: [lua, search, narrowing, dynamic-refresh]
requires: []
provides:
  - "Listings.Read(previous, only): narrows results to a set of activity IDs"
  - "InPlace narrowTo: an answer wider than the picked activities shows only the picked ones"
affects: [UI/InPlace.lua, Listings.lua]
tech-stack:
  added: []
  patterns: ["read-only dropdown reads, type-checked; no C_LFGList.Search"]
key-files:
  modified: [UI/InPlace.lua, Listings.lua]
key-decisions:
  - "Picks not a subset of a non-empty searched set are read unchanged (not derivable)"
requirements-completed: [SRCH-01]
duration: 10min
completed: 2026-11-26
---

# Phase 22 Plan 03: First search after a reload Summary

The first (slow) search after a reload, still out when the player picks an activity, is narrowed to the picked activities when its answer arrives, with no second search.

## What changed
- `Listings.Read(previous, only)` drops listings with no activity in `only` (never your own), before the delisted/dropped loop.
- `UI/InPlace.lua`: `OnSearch` records `issuedCategory` / `issuedSet`; `NarrowSet` computes the picked set when it differs from the searched one (same category, picks a subset of the searched set or the search was category-wide); the answer handler sets `narrowTo` and `shownFilter = FilterKey()` when narrowing, so the next refresh is a normal Dynamic refresh. `Read` passes `narrowTo`; it is held until the next answer, cleared on a failed new search and in the preview.

## Deviations from Plan
None. Dropdown reads are type-checked and the category `GetValue` is under pcall.

## Verification
`stylua .` clean. No `C_LFGList.Search` call added; no writes on Blizzard frames. In-game check (reload, pick category then activity group) goes to 22-HUMAN-UAT.md (Plan 04).

## Commits
- 41ff50c: feat(22-03): Listings.Read can narrow to a set of activities
- 7e61995: fix(22-03): narrow the first search's wider answer to the picked activities

## Self-Check: PASSED
