---
phase: 02-list-foundation
plan: 02
subsystem: ui
tags: [selection, sounds, checkbox, lua]

requires:
  - phase: 02-list-foundation
    provides: ScrollBox list with separate header and row frames (plan 01)
provides:
  - Selection by listing id (inst.selectedID) with Instance:RefreshButtons and T.ClearSelection
  - W.PlayCheckbox and the 26x26 template-labelled W.Check with sounds
  - Stock clear points wired from InPlace events, the search hook, Browse OnShow and the preview
affects: [02-03, 02-04]

tech-stack:
  added: []
  patterns:
    - "Selection is an id resolved through inst.byID at click time, never a table reference"
    - "One clear function (T.ClearSelection) called from every stock clear point"

key-files:
  created: []
  modified: [UI/Widgets.lua, UI/Table.lua, UI/InPlace.lua, UI/MainFrame.lua, UI/Listing.lua]

key-decisions:
  - "Selection resolves against every listing of the read (inst.byID), so folding a section or filtering with the search box keeps the selection; it clears only when the id is gone from the read or delisted"
  - "The stand-in clears the selection when its Browse tab is selected, mirroring the in-game Browse OnShow hook (RESEARCH Open Question 3)"

requirements-completed: [UIP-03, UIP-12]

duration: ~35min
completed: 2026-11-11
---

# Phase 2 Plan 02: Selection by id and stock sounds Summary

**Row selection by listing id with every stock clear point (new results, failed search, search start, Browse shown, preview refresh), inert delisted and own rows, and the stock checkbox sounds on rows, hide/show and checkboxes**

## Accomplishments

- `inst.selectedID` replaces the table reference. `IsSelected` guards nil ids, so headers and your own listing (id 0) never show selected art. A click on a normal row toggles the selection, plays `IG_MAINMENU_OPTION_CHECKBOX_ON`, refreshes the bottom buttons and reinitializes the frames. Delisted rows and your own listing do nothing and stay silent; rows register `LeftButtonUp` only; the double-click whisper is gone.
- `Instance:RefreshButtons`: Send Message for any selection, Group Invite for a selected solo listing when `ns.CanInvite()`; both resolve the listing by id at click time. A selection whose id is gone or delisted is dropped.
- `T.ClearSelection()` is called from the events frame (`LFG_LIST_SEARCH_RESULTS_RECEIVED`, `LFG_LIST_SEARCH_FAILED`; other events only `ReadSoon`), the `LFGBrowse_DoSearch` post-hook, the Browse frame's OnShow hook, the preview refresh button and the stand-in's Browse tab select. Only Blizzard state is read; no field is written on `LFGBrowseFrame`.
- `W.PlayCheckbox(on)`; `W.Check` is 26x26, uses the template's `.Text` when present (`c.Label` aliased) with a fallback label otherwise, and plays ON/OFF before the caller's handler. The stand-in Listing rows play it too. Hide (X) and show (+) play ON; section and column headers stay silent.

## Task Commits

1. Task 1: harness assertions (red) - no repo commit (harness lives outside the repo)
2. Task 2: PlayCheckbox and W.Check - `1c01758`
3. Task 3: selection by id, ClearSelection, wiring - `4274d55`

## Smoke harness

Red after task 1 (plan 01 code): default and `--attach` 42 failed. Green after task 3: default, `--gs`, `--fallback` and `--attach` all `SUMMARY: 0 failed`; `stylua --check .` passes.

## Deviations from Plan

**1. [Rule 1 - Bug] Folding a section dropped the selection**
- **Found during:** Task 3 (harness: header clicks keep the selection)
- **Issue:** Resolving the selected id against the visible `inst.items` meant collapsing the selected row's section, or filtering it out with the search box, cleared the selection.
- **Fix:** `Collect` fills `inst.byID` with every listing of the read; `RefreshButtons` and the bottom buttons resolve through it. The selection clears only when the id is gone from the read or the listing is delisted (plan D-10).
- **Files modified:** UI/Table.lua
- **Commit:** `4274d55`

**2. [Rule 1 - Bug] `a and nil or b` toggle idiom** - the first click handler could never deselect; replaced with an explicit if/else before commit.

Also per the revised plan: Browse OnShow and the stand-in's Browse tab select clear the selection.

## Known Stubs

None.

## Threat Flags

None. T-02-05: only `hooksecurefunc` and our own events frame; grep gate for `LFGBrowseFrame.x =` in the diff is empty. T-02-06: listings resolved by id at click time, delisted and own rows are never selectable.

## In-game checks

- Click a row: checkbox-on sound, yellow selected bar, Send Message enabled (Group Invite for solo players); click again deselects.
- Clicking a greyed delisted row or your own listing: no sound, no change; right-click and double-click do nothing.
- Selection clears on a new search, search results arriving, a failed search, and when Browse is re-shown (tab switch / reopen).
- Hide (X) and show (+) click sounds; the Messages tab Auto-send and Needs my role checkboxes lay out at 26x26 with the template label and play ON/OFF.

## Self-Check: PASSED

- Commits `1c01758` and `4274d55` exist; all four harness modes 0 failed; `stylua --check .` passes.
