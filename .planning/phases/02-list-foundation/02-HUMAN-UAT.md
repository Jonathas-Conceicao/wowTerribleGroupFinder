---
status: complete
phase: 02-list-foundation
source: [02-VERIFICATION.md, 02-01..04-SUMMARY.md, 02-REVIEW-FIX.md]
started: 2026-11-11T18:05:00Z
updated: 2026-11-11T18:05:00Z
---

## Current Test

[awaiting human testing — in game on Forever, after `./scripts/install.bat` and `/reload`]

## Tests

### 1. Our XML templates resolve (UAT-1, check first)
expected: `/dump C_XMLUtil.GetTemplateInfo("TerribleGroupFinderListRowTemplate")` is non-nil. If nil, the table silently uses the fallback list (no Blizzard scroll bar).
result: pass — author, 2026-11-12

### 2. ScrollBox scrolling
expected: With enough results, the list scrolls with Blizzard's MinimalScrollBar (wheel, drag, arrows); the bar hides when everything fits; scroll position is kept on re-sort / refresh.
result: pass — author, 2026-11-12

### 3. Section headers (author-reported hover bug)
expected: Solo players / Groups headers use the finder's collapse/expand bar with plus/minus; clicking folds/unfolds; hovering brightens only the header, never the blue row highlight.
result: pass — author, 2026-11-12

### 4. Selection
expected: Clicking a row plays the checkbox sound and shows the selected art; a second click clears it; your own and delisted rows do nothing (no sound); right- and double-click do nothing. Selection survives a re-sort and clears on a new search, results arriving, a failed search, and when Browse is re-shown (tab switch / reopen). Send Message / Group Invite are disabled while the selected row is folded or filtered out.
result: pass — author, 2026-11-12

### 5. Layout (Q1, Q2, Q3)
expected: One inset only (Forever's). Search box in the stone band right of the refresh button, not covering the options gear. Column headers in the strip above BarTop; rows never cross BarTop or BarMiddle. Needs my role and the status text sit in the bottom bar between Send Message and Group Invite. 620 wide reads well (Activity readable).
result: pass — author, 2026-11-12

### 6. Column header sort arrow (Q7)
expected: `ColumnDisplayButtonShortTemplate` headers; the `auctionhouse-ui-sortarrow` points up on ascending and down on descending; the Listed label and arrow stay inside their column.
result: pass — author, 2026-11-12

### 7. Row look (Q5)
expected: `common-button-list-mid2` background / hover / selected art looks right at 40 px (else switch to the highlightbar trio); own row uses the highlightbar set; names class-coloured; level grey; activity grey, bright blue when it matches your active listing; group rows show the leader icon at its atlas size; hidden / delisted / no-slot rows fully grey with desaturated icons; rows recover their look after unhide.
result: pass — author, 2026-11-12

### 8. Search states (Q8)
expected: Stock spinner with "Searching" while a search runs (list empty); "No results found" / "Search failed" texts; "No listings match your search." when our search box filters everything; Blizzard's own spinner and NoResultsFound stay hidden.
result: pass — author, 2026-11-12

### 9. Sounds
expected: Row select / deselect, hide (X) / show (+) play the checkbox-on sound; Needs my role and the Messages tab checkboxes play on / off and show at 26x26 with the template label.
result: pass — author, 2026-11-12

### 10. No taint
expected: No ADDON_ACTION_BLOCKED or taint warning when clicking rows, searching, switching tabs, opening Listing, or using Unlist (now only enabled while solo or leader; it still calls `C_LFGList.RemoveListing()` directly — check Blizzard's Listing tab updates afterwards; stock delist button is Phase 3 / UIP-08).
result: pass — author, 2026-11-12

### 11. Whispers by plain name
expected: Whisper / Send Message targets the plain character name; with Auto-send on during chat messaging lockdown, the whisper box opens prefilled instead of sending.
result: pass — author, 2026-11-12

## Summary

total: 11
passed: 11
issues: 0
pending: 0
skipped: 0
blocked: 0

## Gaps
