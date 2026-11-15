---
phase: 09-dynamic-refresh
plan: 02
subsystem: ui
tags: [dynamic-refresh, settings, taint]
requires: [09-01]
provides:
  - "OnSearch gated by dynamicRefresh, ns.Motion.Cancel on every search, Dynamic refresh naming"
affects: [09-03]
key-files:
  modified: [UI/InPlace.lua, Listings.lua, CLAUDE.md]
key-decisions:
  - "A search resets readAfterSwipe after Motion.Cancel so a deferred read of the old answer never runs over the new search"
requirements-completed: [REF-01]
completed: 2026-11-14
---

# Phase 9 Plan 02: Dynamic refresh gates Summary

**The in-place merge runs only for the same filter with `dynamicRefresh` on (off is stock), every search cancels a pending swipe, and the feature is named "Dynamic refresh" in code and CLAUDE.md.**

## Accomplishments
- `UI/InPlace.lua`: `OnSearch` calls `ns.Motion.Cancel()` and clears `readAfterSwipe`, then merges only when `ns.Settings.Get("dynamicRefresh") ~= false`; section comment rewritten (no refresh on a timer, `Search` never called).
- `Listings.lua`: comment block renamed.
- CLAUDE.md: taint bullet and `UI/InPlace.lua` line describe what ships (the earlier fix's changes kept).
- Harness (outside the repo): probe renamed "dynamic-refresh", 25 checks named "dynamic refresh: ..." (invite mark, no spinner, swipe-out on the vanished row, cancel, setting off = stock, `swipeAnimations` off in place, static no-`Search`/no-ticker check). All three modes print `SUMMARY: 0 failed`. `stylua --check .` clean; deployed with install.ps1.

## Task Commits
1. OnSearch gates and naming: `68b9bf3`
2. CLAUDE.md: see git log (`docs(09-02): describe Dynamic refresh in CLAUDE.md`)

## Deviations from Plan
None. The taint bullet no longer carried the prototype exception, so only the Dynamic refresh sentence was added.

## In-game checks (deferred to the milestone end)
- Refresh button with the same filter keeps the list with no spinner and merges (scrolled list, hovered tooltip, selection and whisper/invite marks kept)
- A failed refresh keeps the list; changing activities is a new list
- `dynamicRefresh` off (via `/run`) restores the stock spinner and blank list
- Pressing refresh mid-swipe shows the new state at once; no `ADDON_ACTION_BLOCKED`

## Self-Check: PASSED
