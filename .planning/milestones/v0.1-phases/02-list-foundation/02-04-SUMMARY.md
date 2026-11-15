---
phase: 02-list-foundation
plan: 04
subsystem: ui
tags: [row-art, fonts, colours, greyed-rows, leader-icon, lua]

requires:
  - phase: 02-list-foundation
    provides: ScrollBox list, selection by id, layout and search states (plans 01-03)
provides:
  - Forever's row look (mid2 background / hover / selected art, highlightbar pair for your own row)
  - Stock fonts and colours, bright-blue activity on a match with the active listing
  - Greyed rows in stock grey with desaturated icons, reset on every fill
  - Leader icon on group rows
  - W.GRAY / W.BRIGHTBLUE / W.DELISTED / W.SetColor
affects: []

tech-stack:
  added: []
  patterns:
    - "Pooled row frames set every visual property on every fill (art, colours, desaturation, alpha)"
    - "Active activity ids are read once per Refresh (issecretvalue-guarded) and stored on the instance"

key-files:
  created: []
  modified: [UI/Table.lua, UI/Widgets.lua, CLAUDE.md]

key-decisions:
  - "Greyed rows drop inline colour codes (listed state, count, GS) so the stock grey applies to all text"
  - "Activity match reads ns.state.myListing.activities in the preview and C_LFGList.GetActiveEntryInfo().activityIDs in game"

requirements-completed: [UIP-06]

duration: ~25min
completed: 2026-11-11
---

# Phase 2 Plan 04: Stock Row Look Summary

**Rows now look like Forever's own list: mid2 button art, class-coloured names, grey level, blue matching activities, greyed rows in stock grey with desaturated icons, and the leader icon on groups.**

## Accomplishments

- D-20: `bg` (BACKGROUND, 3,-2 / -3,0), `hover` (HIGHLIGHT, ADD) and `selected` (OVERLAY, ADD, 3,-3 / -3,-1); `common-button-list-mid2` family for others, `groupfinder-highlightbar` / `-blue` for your own row; flat colour fallbacks. `W.RowHighlight` and the per-row line are gone from the table (the helper stays for UI/Listing.lua).
- D-21: name `GameFontNormal` in class colour (no colour codes in the text), level `GameFontDisable` grey, activity `GameFontHighlightSmall` GRAY or BRIGHTBLUE on a match; `+N` suffix kept.
- D-22: greyed rows draw all text in {0.3,0.3,0.3}, icons desaturated, role slots at alpha 0.5; reused frames get colours, desaturation and alpha back.
- D-23: group rows show `groupfinder-icon-leader` at atlas size (class icon fallback); solo rows the 16x16 class icon.
- D-24: "(you)" suffix kept.
- Task 3: CLAUDE.md `UI/Table.lua` bullet updated.

## Task Commits

1. Task 1: harness assertions (red, 6 failures in every mode) - no repo commit (harness outside the repo)
2. Task 2: row art, fonts, colours, greyed rows, leader icon - `38bcb8d`
3. Task 3: CLAUDE.md bullet - `b0c2681`

## Verification

- Harness, final: default, `--gs`, `--fallback`, `--attach` each `SUMMARY: 0 failed`; `stylua --check .` passes.
- Install: `./scripts/install.bat` output: "Deploying 13 files derived from TerribleGroupFinder.toc: ... UI\Templates.xml ..."; "Deployed version: b0c2681-dev"; "Installed to C:\Program Files (x86)\World of Warcraft\_forever_\Interface\AddOns\TerribleGroupFinder"; "Done!".

## Deviations from Plan

**1. [Choice] Harness stub** - added a `GetTextColor` stub to the harness (the table now captures each text's default colour at build time).

**2. [Choice] Inline codes on greyed rows** - the delisted / invited / sent words, role count and GS text drop their colour codes while a row is greyed, so the stock grey applies to every text (a text with an embedded code ignores SetTextColor).

**3. [Choice] Own row activity colour** - stock turns it light green; the plan did not ask for it, so it follows the plain GRAY / BRIGHTBLUE rule.

No rule-based fixes were needed.

## Known Stubs

None.

## Threat Flags

None. T-02-11: `issecretvalue` guards on the active entry, its `activityIDs` and each id (harness secret-mode check in attach mode). T-02-12: only our pooled row frames carry `bg`, `hover`, `selected`, `__tgfColor`. T-02-13: install output lists `UI\Templates.xml`.

## Human verification (in game, not blocking)

After `/reload`:

- UAT-1 `/dump C_XMLUtil.GetTemplateInfo("TerribleGroupFinderListRowTemplate")` non-nil.
- Scroll wheel, bar drag, bar hides when the list fits, position kept on re-sort.
- Header hover brightens only the header (the reported bug).
- Q5: mid2 art looks right at 40 px per row (fallback: highlightbar trio).
- Q7: sort arrow direction. Q1 width. Q2 search box fits. Q3 BarTop clear. Q8 Blizzard spinner / NoResultsFound stay hidden.
- No ADDON_ACTION_BLOCKED when clicking rows, searching, switching tabs or opening Listing.
- Checkbox / hide / select sounds.
- Row look: leader icon size on group rows, matching activity turns blue after listing, hidden / delisted rows fully grey with desaturated icons, normal rows recover their look after unhide.

## Self-Check: PASSED

- Commits `38bcb8d` and `b0c2681` exist; four harness modes 0 failed; `stylua --check .` passes; install succeeded.
