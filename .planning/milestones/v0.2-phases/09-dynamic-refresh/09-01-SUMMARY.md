---
phase: 09-dynamic-refresh
plan: 01
subsystem: ui
tags: [animation, scrollbox, dynamic-refresh]
requires: []
provides:
  - "ns.Motion: swipe out / in, slide-up by recorded GetTop(), Show / Cancel / Busy / ResetRow, gated by swipeAnimations"
affects: [09-02, 09-03]
tech-stack:
  added: []
  patterns: ["AnimationGroup Translation + Alpha only, render-time offsets, anchors of pooled rows never touched"]
key-files:
  created: [UI/Motion.lua]
  modified: [UI/Table.lua, UI/InPlace.lua, TerribleGroupFinder.toc, CLAUDE.md]
key-decisions:
  - "Constants SWIPE_OUT = SWIPE_IN = 0.4, SLIDE = 0.3, SWIPE_X = 40, MIN_DELTA = 1, smoothing OUT in one place"
  - "Motion.Show cancels a pending Show first, so a new search shows its state at once"
requirements-completed: [REF-02, REF-03]
duration: ~40 min
completed: 2026-11-14
---

# Phase 9 Plan 01: Motion Summary

**`ns.Motion` takes over the row animations: calmer 0.4 s swipes, rows below a removed one slide up from their recorded positions, pooled rows are reset on release, and clicks wait during the swipe-out.**

## Accomplishments
- `UI/Motion.lua` (loaded after `UI/Templates.xml`, before `UI/Table.lua`): `Enabled`, `KeyOf`, `Keys`, `ResetRow`, `Busy`, `Show(previousKeys, selectedKey, after)`, `Cancel`. Swipe-out, then the list updates, then slide-up and swipe-in together; with `swipeAnimations` off the list updates in place with no timer.
- `UI/Table.lua`: prototype swipe block removed; `T.ForEachFrame`, `T.CurrentKeys`; `Motion.ResetRow` in the ScrollBox resetter and in `FillRow` / `FillHeader` when a frame shows another key; `Motion.Busy()` guard on row click, hide button, `Message`, `Invite`, `ContextMenu`.
- `UI/InPlace.lua`: `ShowRefresh` and the `swiping` flag gone; `Read` hands the refresh to `ns.Motion.Show`. `readAfterSwipe` and `ReadSoon` are declared above `OnSearch` (checker note, for plan 09-02).
- CLAUDE.md: `UI/Motion.lua` architecture line, Table line (resetter, click guard), InPlace line.
- Harness (outside the repo): positional `GetTop`, an animation recorder, and a "motion" probe with 29 checks; all three modes (default, `--fallback`, `--attach`) print `SUMMARY: 0 failed`.

## Task Commits
1. Task 1, Motion.lua and TOC: `ce54f8d`
2. Task 2, Table / InPlace hand-off: `79e5d89`
3. Task 3, CLAUDE.md (harness changes live outside the repo): `3c73e5e`

## Deviations from Plan
None. The TOC is stored with LF in the working tree, so its new line uses LF (the new Lua file is CRLF).

## Issues Encountered
My first probe left `swipeAnimations` written in the saved DB, which failed the existing "migrated DB reads defaults" check; the probe now clears it after the toggle.

## In-game checks (deferred to the milestone end)
- `GetTop()` right after the update gives the new layout in the same frame (else wait one frame)
- Rows below a removed one slide up with the list scrolled and with a section collapsed
- No stuck invisible rows after scrolling mid-swipe or after a second refresh mid-swipe; no wrong-row animation after pooled reuse
- Swipe speed feels calmer than the prototype (author)

## Next
Plan 09-02 (gates, naming, `readAfterSwipe` reset from `OnSearch`) and 09-03 (preview refresh) build on `Motion.Show`.

## Self-Check: PASSED
