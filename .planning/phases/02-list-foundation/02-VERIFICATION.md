---
phase: 02-list-foundation
verified: 2026-11-11T18:00:00Z
status: human_needed
score: 5/5 must-haves verified (code level)
overrides_applied: 0
human_verification:
  - test: "Open Browse in Forever, run a search with enough results to overflow"
    expected: "The list scrolls with Blizzard's scroll bar (ScrollBox), the bar hides when everything fits, no ADDON_ACTION_BLOCKED or taint"
    why_human: "Real ScrollBox behaviour and taint cannot be exercised in the harness"
  - test: "Click Solo players / Groups headers; hover them and hover rows"
    expected: "Sections collapse/expand with the stock plus/minus atlas; the header shows its own hover look, not the row highlight"
    why_human: "Atlas appearance and hover art are visual"
  - test: "Click rows (normal, own, delisted); re-sort; run a new search"
    expected: "Normal row selects with the click sound and clears on second click; own and delisted rows do nothing; selection survives sort, clears on new results"
    why_human: "Audible sound and live selection art"
  - test: "Check Browse layout"
    expected: "Single inset, search box in the stone band, column headers above the bar, Needs my role and status text in the bottom bar; rows use stock background, hover, selected art, grey rows desaturated, groups show the leader icon"
    why_human: "Visual fidelity to Forever's finder"
  - test: "Search, empty search, failed search, filter with no matches; toggle hide (X) and Needs my role"
    expected: "Stock spinner while searching; each state shows its text; stock checkbox sounds play"
    why_human: "Spinner visuals, audible sounds"
  - test: "Load the addon in the real client"
    expected: "UI/Templates.xml virtual templates (TerribleGroupFinderListHeaderTemplate / ListRowTemplate) resolve and the ScrollBox pools build"
    why_human: "Template resolution happens in the game's XML loader"
---

# Phase 2: List Foundation Verification Report

**Phase Goal:** The Browse list is built like the stock one: it scrolls with Blizzard's ScrollBox, and headers, selection, layout and row look match Forever's finder
**Status:** human_needed (all code-level checks pass; visual and in-game checks remain)
**Re-verification:** No, initial verification

## Observable Truths

| # | Truth | Status | Evidence |
|---|-------|--------|----------|
| 1 | Scrolls with Blizzard's scroll bar; headers collapse/expand with stock atlas plus/minus; header hover is not the row highlight | VERIFIED (code) | `UI/Table.lua` ~996-1060 builds `CreateScrollBoxListLinearView` + `ScrollUtil.InitScrollBoxListWithScrollBar` + `AddManagedScrollBarVisibilityBehavior`, with a fallback when absent. `BuildHeader` uses `common-button-list-plus/minus`, `common-button-list-collapseExpand`, and a HIGHLIGHT texture only. OnClick toggles `view.collapsed[key]` and calls `RefreshAll`. |
| 2 | Row click selects/clears; delisted and own rows not selectable; survives re-sort, clears on new results; click sound | VERIFIED (code) | Row OnClick (~620-635) returns on `l.mine or l.delisted`, toggles `selectedID` by listing id (so it survives re-sort), calls `W.PlayCheckbox`. `T.ClearSelection` clears on new results. `ValidateSelection` drops gone/delisted selections before rows fill. |
| 3 | Single inset with search box in the stone band, column headers above the bar, Needs my role and status in the bottom bar | VERIFIED (code) | `Table.lua` builds the search box (`SearchBoxTemplate`), `ColumnDisplayButtonShortTemplate` headers, and `self.fits` (Needs my role) and `self.status` in the bottom bar. `InPlace.lua` hides the stock parts via `Hide()` only. Visual placement needs a human. |
| 4 | Stock row background, hover and selected art, fonts and colours; grey rows use stock grey and desaturated icons; groups show the leader icon | VERIFIED (code) | `FillRow` uses `common-button-list-mid2`, `-hover`, `-selected` (own row: `groupfinder-highlightbar` pair), `groupfinder-icon-leader` for groups. Plain-colour fallbacks exist where atlases are missing. |
| 5 | Stock spinner while searching; empty, failed and own-filter states show text; hide and checkboxes play stock sounds | VERIFIED (code) | `LoadingSpinnerTemplate` spinner shown while `source.searching()`. `LFG_LIST_SEARCH_FAILED` and `LFG_LIST_NO_RESULTS_FOUND` set the state text, and a separate "No listings match your search." covers our filter. `W.PlayCheckbox` uses `SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON/OFF` on hide, rows and checkboxes. |

**Score:** 5/5 verified at code level.

## Required Artifacts

| Artifact | Status | Details |
|----------|--------|---------|
| `UI/Table.lua` (1301 lines) | VERIFIED | Substantive and wired from `InPlace.lua` and `MainFrame.lua` |
| `UI/Widgets.lua` | VERIFIED | Inset, atlas, sound and checkbox helpers in use |
| `UI/Templates.xml` | VERIFIED | Listed in the TOC before `Table.lua`; the two virtual templates exist |
| `TerribleGroupFinder.toc` | VERIFIED | Load list includes the XML |

## Behavioral Spot-Checks

| Check | Command | Result | Status |
|-------|---------|--------|--------|
| Smoke harness default | `node run.js <repo>` | `SUMMARY: 0 failed` | PASS |
| `--gs` | same with `--gs` | `SUMMARY: 0 failed` | PASS |
| `--fallback` | same with `--fallback` | `SUMMARY: 0 failed` | PASS |
| `--attach` | same with `--attach` | `SUMMARY: 0 failed` | PASS |
| Formatting | `stylua --check .` | clean | PASS |

## Probe Execution

SKIPPED, no `probe-*.sh` scripts declared.

## Requirements Coverage

| Requirement | Source Plan | Status | Evidence |
|-------------|-------------|--------|----------|
| UIP-02 | 02-01 | SATISFIED (code) | ScrollBox list, selection |
| UIP-05 | 02-01 | SATISFIED (code) | Header collapse/expand and hover |
| UIP-03 | 02-02 | SATISFIED (code) | Single inset, bands, bottom bar |
| UIP-12 | 02-02 | SATISFIED (code) | Spinner and state texts |
| UIP-04 | 02-03 | SATISFIED (code) | Row art, fonts, greys, leader icon |
| UIP-10 | 02-03 | SATISFIED (code) | Stock sounds |
| UIP-06 | 02-04 | SATISFIED (code) | Selection behaviour |

All 7 phase IDs (UIP-02, 03, 04, 05, 06, 10, 12) are claimed by a plan and appear in REQUIREMENTS.md. No orphaned requirements. The traceability table in REQUIREMENTS.md still says "Pending" for these IDs, although the checklist boxes are ticked. This is a doc inconsistency for the orchestrator to update.

## Anti-Patterns Found

None blocking. No TBD, FIXME or XXX markers in Lua or XML. The 13 code-review warnings were fixed (see 02-REVIEW-FIX.md; WR-01 in iteration 2 is in commit `acf7199`). Info items IN-01 to IN-09 are open by decision. IN-06 belongs to Phase 3 (UIP-08).

## Gaps Summary

No code-level gaps. Every ROADMAP success criterion has substantive, wired implementation, and the harness passes in all four modes. Remaining work is in-game confirmation of the visual, audible and taint-related behaviour listed in the frontmatter.

---

_Verified: 2026-11-11_
_Verifier: Claude (gsd-verifier)_
