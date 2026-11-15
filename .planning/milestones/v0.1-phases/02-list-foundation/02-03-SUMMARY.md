---
phase: 02-list-foundation
plan: 03
subsystem: ui
tags: [layout, column-headers, search-states, spinner, lua]

requires:
  - phase: 02-list-foundation
    provides: ScrollBox list and selection by id (plans 01, 02)
provides:
  - Single-inset layout in Forever's Browse geometry (header strip above BarTop, list between BarTop and BarMiddle)
  - ColumnDisplayButtonShortTemplate column headers with the auctionhouse-ui-sortarrow arrow
  - Search box beside the refresh button, Needs my role and status in the bottom bar
  - Spinner, no-results, failed and no-match states; source.failed and source.refreshAnchor
affects: [02-04]

tech-stack:
  added: []
  patterns:
    - "Sources hand the table read-only anchors (refreshAnchor) and states (searching, failed); the table writes nothing on Blizzard frames"
    - "Header strip right edge is driven by one PlaceStrip(barShown) shared with the ScrollBox visibility callback"

key-files:
  created: []
  modified: [UI/Table.lua, UI/InPlace.lua, UI/MainFrame.lua]

key-decisions:
  - "band is a 1 px non-mouse helper at the art top (only its OnShow matters); the search box, Needs my role and the strip are parented to the host"
  - "Without the template's Text or the sort-arrow atlas, headers fall back to flat buttons and a ^ / v text suffix"
  - "The stand-in draws the common-insideframe border only when the atlas exists (no flat fallback box, the art is already flat)"
  - "Your GS (GS builds only) moved into the bottom bar, left of the status text"

requirements-completed: [UIP-04, UIP-10]

duration: ~40min
completed: 2026-11-11
---

# Phase 2 Plan 03: Layout and Search States Summary

**Browse table laid out like Forever's own (one inset, column headers above BarTop, search box in the stone band, controls in the bottom bar) with the stock spinner, no-results, failed and no-match states**

## Accomplishments

- D-13: `W.Inset` is gone from `T.Attach`; `back` keeps the mouse and draws nothing. The stand-in gets the `common-insideframe` border, `BarTop` (art top -20) and `BarMiddle` (frame bottom +61).
- D-14: search box (150, "Name, activity or note") anchors LEFT of `source.refreshAnchor` (+10); without it, TOPRIGHT of the host (-48, -38). In game `refreshAnchor` is `LFGBrowseFrame.RefreshButton` (read only), in the preview the stand-in's refresh button.
- D-15/D-16: header strip (20 px) with `ColumnDisplayButtonShortTemplate` buttons and the sort arrow (texcoord 0,1,1,0 ascending, 0,1,0,1 descending), right edge -22 / -6 following the ScrollBox; ScrollBox from `back` (3,-6) to (-22 or -6, 2).
- D-17/D-18: Needs my role right of Send Message, status right-aligned left of Group Invite; Roles 92, Activity at 284 (334 with GS).
- D-25..D-27: `LoadingSpinnerTemplate` spinner plus SEARCHING label while searching (list cleared); `stateText` shows search failed / no results / "No listings match your search."; the "Nothing listed here" line is removed. `source.failed` reads `LFGBrowseFrame.searchFailed`; false in the preview.
- D-19: width stays 620.

## Task Commits

1. Task 1: harness assertions (red) - no repo commit (harness outside the repo)
2. Task 2: table layout and search states - `7cbd874`
3. Task 3: sources and preview layers - `7c5962e`

## Smoke harness

Red after task 1: 8 failed (default, `--gs`, `--fallback`), 10 failed (`--attach`). After task 2: 2 / 2 / 2 / 3 failed (anchor and source pieces of task 3). Green after task 3: default, `--gs`, `--fallback`, `--attach` all `SUMMARY: 0 failed`; `stylua --check .` passes. Taint grep gate on `UI/InPlace.lua` empty.

## Deviations from Plan

**1. [Choice] Your GS placement** - the GS-only "Your GS" label lived in the old band; with the band gone it sits in the bottom bar left of the status text (GS is off in v0.1, so this only matters for GS builds).

**2. [Choice] Harness stub cannot see the template's `Text`** - the stub never defines `.Text` on the header buttons, so the harness exercises the flat-button fallback text path; the template-text path is covered only in game.

No rule-based fixes were needed.

## Known Stubs

None.

## Threat Flags

None. T-02-08: only reads on `LFGBrowseFrame` (`searching`, `searchFailed`, `RefreshButton`, `BackgroundArt`); `refreshAnchor` is stored on our own source table. T-02-09: `band` no longer takes the mouse. T-02-10: TOPRIGHT fallback, harness checks both branches.

## In-game checks

- Q1 width: Browse is 620 wide and the columns fit.
- Q2: the search box fits between the refresh button and the options gear without covering either.
- Q3: the column headers stay above BarTop; rows do not cross it or BarMiddle.
- Q7: sort arrow points up on ascending, down on descending.
- Q8: Blizzard's own hidden spinner and NoResultsFound stay hidden; only ours show.

## Self-Check: PASSED

- Commits `7cbd874` and `7c5962e` exist; four harness modes 0 failed; `stylua --check .` passes.
