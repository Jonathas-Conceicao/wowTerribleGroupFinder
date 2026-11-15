---
phase: 09-dynamic-refresh
plan: 03
subsystem: ui
tags: [dynamic-refresh, preview, motion]
requires: [09-01, 09-02]
provides:
  - "Preview reserve, P.Churn and P.Refresh: a simulated Dynamic refresh in the stand-in and in game with /tgf preview"
affects: []
key-files:
  modified: [Preview.lua, Core.lua, UI/MainFrame.lua, UI/InPlace.lua, CLAUDE.md]
key-decisions:
  - "P.Churn returns empty sets (no math.random(1, 0)) when nothing shown qualifies or the reserve is empty"
  - "Reserve: 8 Dungeons listings (5 groups, 3 solo players); a delisted turn on about one press in three; P.SEARCH_TIME = 0.5 s"
requirements-completed: [REF-04]
completed: 2026-11-14
---

# Phase 9 Plan 03: Preview Dynamic refresh Summary

**The preview's refresh button (and Forever's own with `/tgf preview`) churns the sample list: 1-3 listings leave, 1-3 arrive from a reserve, sometimes one turns delisted, through the same `ns.Motion.Show` path as the game and honouring both settings.**

## Accomplishments
- `Preview.lua`: `P.reserve` (8 Dungeons listings), `P.SEARCH_TIME`, `P.Churn(state, shownKeys)`, `P.Refresh()`. `Churn` guards the empty candidate / empty reserve cases. `Refresh` with `dynamicRefresh` off shows a short spinner (token-guarded against `/tgf reset`) and clears the selection.
- `Core.lua`: `CopyListings` for samples and reserve, `nextId`, `previewSearching` in `ns.state`; `/tgf reset` cancels motion first.
- `UI/MainFrame.lua`: refresh button calls `ns.Preview.Refresh()`, new tooltip, `searching` in the table source. `UI/InPlace.lua`: preview branch in `OnSearch`, preview-aware `searching`, a real answer no longer clears the preview selection.
- Harness (outside the repo): 24 "preview churn" checks plus an in-game preview probe; three existing checks updated to the new behaviour. All three modes print `SUMMARY: 0 failed`; `stylua --check .` clean; deployed with install.ps1.

## Task Commits
1. Reserve, Churn, Refresh, Core state: `dac7fd2`
2. Refresh buttons and preview wiring: `5d46129`; CLAUDE.md: `5b3f90a`

## Deviations from Plan
None. Three existing harness checks (refresh button clears selection; real answer / new search clears selection in preview) were updated because the plan deliberately changes that behaviour.

## In-game checks (deferred to the milestone end)
- With `/tgf preview`, Forever's refresh button churns the sample list with swipes and slides; repeated presses keep churning; `/tgf reset` restores
- Both settings toggled with `/run` change the preview the same way as live; the author judges the animation speed in the preview

## Self-Check: PASSED
