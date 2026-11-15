---
phase: 09-dynamic-refresh
verified: 2026-11-14T00:00:00Z
status: human_needed
score: 4/4 must-haves verified (code level); feel/timing deferred to human
human_verification:
  - test: "In game, press Forever's refresh button for the same category and activities with a list on screen"
    expected: "No spinner or blank; new listings sort in, delisted ones swipe out and stay out, selection and whisper/invite marks stay; a failed search leaves the list as it was"
    why_human: "Needs the live Forever client and a live search answer"
  - test: "Watch swipe-out/in (0.4 s) and slide (0.3 s), including with the list scrolled"
    expected: "Visibly calmer than the prototype's 0.25 s; rows below a removed row slide up, not jump, with scroll offset"
    why_human: "Visual feel and real ScrollBox frame timing"
  - test: "Preview: press refresh repeatedly, then /tgf reset; toggle dynamicRefresh and swipeAnimations"
    expected: "Listings leave and arrive with the same animations; reset restores samples and reserve; off settings behave as described"
    why_human: "Animation appearance"
---

# Phase 9: Dynamic Refresh Verification Report

**Phase Goal:** Refreshing the finder keeps the list on screen and updates it in place, with calm animations the author can also try in the preview
**Status:** human_needed (no code gaps found)
**Re-verification:** No, initial

## Observable Truths

| # | Truth | Status | Evidence |
|---|-------|--------|----------|
| 1 | Same-filter refresh keeps list, merges new/delisted, keeps selection and marks, failed refresh leaves list untouched | VERIFIED | `UI/InPlace.lua` OnSearch: `same` requires `shownFilter` match, items present and `dynamicRefresh`; snapshot taken, `Motion.Show(previous, selected)`, failed-refresh path keeps list; new filter clears selection and `ClearDropped()`. `Listings.lua` `dropped` set keeps swiped-out delisted rows out on later plain reads (CR-01 fixed). |
| 2 | Leaving rows swipe out, new rows swipe in, calmer | VERIFIED (feel: human) | `UI/Motion.lua`: SWIPE_OUT = 0.4, SWIPE_IN = 0.4 (prototype 0.25) |
| 3 | Rows below a removed row slide up, also when scrolled | VERIFIED (feel: human) | `Motion.lua`: slide recorded via `GetTop()` by key before the update, offset-only translation (`Slide`, 0.3 s, MIN_DELTA), so scroll offset is accounted for; pooled rows reset in resetter and FillRow |
| 4 | Preview refresh simulates churn with same animations; `/tgf reset` restores sample data | VERIFIED | `Preview.lua` `P.Refresh` -> `P.Churn` + `ns.Motion.Show`; `Core.lua` reset: `Motion.Cancel()`, `ResetState` (copies samples and `reserve`), `Table.RefreshAll()`; `MainFrame.lua` button calls `ns.Preview.Refresh()` |

Plan-level extras confirmed: clicks ignored while `Motion.Busy()` (Table.lua guards at rows/buttons); no `C_LFGList.Search` call anywhere in the Lua; no timer-driven refresh; `dynamicRefresh` off falls back to the stock path; a new search cancels a swipe in progress (`Motion.Cancel()` in OnSearch, `readAfterSwipe` reset before it).

## Requirements Coverage

| Req | Plan | Status | Evidence |
|-----|------|--------|----------|
| REF-01 | 09-02 | SATISFIED | Truth 1 |
| REF-02 | 09-01 | SATISFIED | Truth 2 |
| REF-03 | 09-01 | SATISFIED | Truth 3 |
| REF-04 | 09-03 | SATISFIED | Truth 4 |

No orphaned IDs. REQUIREMENTS.md traceability still lists REF-02 and REF-03 as "Pending" with unchecked boxes; the tracking file needs updating (documentation only).

## Behavioral Spot-Checks / Probes

| Check | Result |
|-------|--------|
| Smoke harness default, `--fallback`, `--attach` | each `SUMMARY: 0 failed` (re-run by verifier) |

## Anti-Patterns

No TBD/FIXME/XXX in modified Lua files. Review findings CR-01 and WR-01..07 were fixed (commits 7484fc3..7f3a4a4); the dropped-listing behaviour is a recorded author decision (CLAUDE.md exception).

## Gaps Summary

None in code. Remaining items are live-client feel and timing checks, which the author defers to milestone end. Housekeeping: tick REF-02 and REF-03 in REQUIREMENTS.md.
