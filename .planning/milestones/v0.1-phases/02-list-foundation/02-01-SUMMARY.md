---
phase: 02-list-foundation
plan: 01
subsystem: ui
tags: [scrollbox, wowscrollboxlist, minimalscrollbar, templates, lua, xml]

requires:
  - phase: 01-gear-score-off-and-release-plumbing
    provides: GS-off table and the smoke harness baseline
provides:
  - Browse list in a Blizzard ScrollBox with separate header (36) and row (40) frames
  - UI/Templates.xml with two scriptless virtual Buttons, loaded before Table
  - W.List with one pool per item kind (fallback where the ScrollBox API is missing)
  - Section header frame with the finder's grouping look and its own hover
affects: [02-02, 02-03, 02-04]

tech-stack:
  added: []
  patterns:
    - "Build once behind frame.tgfBuilt, then Fill on every initializer call; initializers never refresh"
    - "Capability gate (API + C_XMLUtil.GetTemplateInfo) chooses ScrollBox host or W.List fallback; both share BuildX/FillX"

key-files:
  created: [UI/Templates.xml]
  modified: [UI/Table.lua, UI/Widgets.lua, TerribleGroupFinder.toc, CLAUDE.md]

key-decisions:
  - "Cell height stays 32 inside the 40 px row (centred), until plan 04 reworks the row look"
  - "Column header strip moved to TOPRIGHT -6 and shifts a further 16 px when the bar shows, so it lines up with rows in both states"
  - "W.List pools expose a height field next to the frame array (list.pools[kind].height)"

requirements-completed: [UIP-05, UIP-02]

duration: ~40min
completed: 2026-11-11
---

# Phase 2 Plan 01: ScrollBox Host and Header Frames Summary

**Browse list on Blizzard's WowScrollBoxList + MinimalScrollBar with separate 36 px header and 40 px row frames, collapsible grouping-style headers, and a per-kind W.List fallback**

## Performance

- **Tasks:** 3 (task 1 changed only the out-of-repo harness, so it has no commit)
- **Files modified:** 5 in the repo (1 created)

## Accomplishments

- `T.Attach` builds the list through `Instance:BuildList`: scriptless `TerribleGroupFinderListHeaderTemplate` / `TerribleGroupFinderListRowTemplate` (UI/Templates.xml), a pure element factory keyed by `item.header`, extent 36 / 40, flat `CreateDataProvider` fed with exactly what `Collect()` produces, `RetainScrollPosition` on every refresh, managed bar visibility (box right -22 with bar, -6 without).
- Header frames: label plus count in `GRAY_FONT_COLOR`, plus/minus atlas swap, click toggles `view.collapsed`, no sound, no tooltip, no `selected`, and the only HIGHLIGHT texture is the header's own `common-button-list-collapseExpand` (the hover bug is gone structurally). In game the stock `LFGBrowseSearchEntryGroupingTemplate` is used when `C_XMLUtil.GetTemplateInfo` finds it.
- `W.List(parent, kinds, kindOf, fillItem)` with per-kind pools; the old numeric signature (UI/Listing.lua) is untouched and works.
- CLAUDE.md architecture names UI/Templates.xml; install/package derive files from the TOC, so the XML ships.

## Task Commits

1. Task 1: harness stubs and run modes (D-30) - no repo commit (harness lives outside the repo)
2. Task 2: templates, TOC, CLAUDE.md, per-kind W.List - `e51f4b5`
3. Task 3: ScrollBox host, Build/Fill split, header frames - `cadad79`

## Smoke harness

Directory: `C:\Users\jonat\AppData\Local\Temp\claude\3a677a53f55271b6\8039163f-18e8-4930-88a2-d8efcca63b25\scratchpad\smoke\` (never committed).

Run commands (from that directory):

```
node run.js "C:/Users/jonat/Repositories/TerribleGroupFinder"
node run.js "C:/Users/jonat/Repositories/TerribleGroupFinder" --gs
node run.js "C:/Users/jonat/Repositories/TerribleGroupFinder" --fallback
node run.js "C:/Users/jonat/Repositories/TerribleGroupFinder" --attach
```

Red baseline (after task 1, repo unchanged): default 3 failed (table probe, no WowScrollBoxList box, list probe), `--gs` 2 failed, `--fallback` 3 failed, `--attach` 3 failed.
Green (after task 3): all four print `SUMMARY: 0 failed`. `stylua --check .` passes.

## Deviations from Plan

None in behaviour. Small choices where the plan left room:

- Fallback W.List caps the offset by accumulated item heights (not a fixed row count), since headers (36) and rows (40) differ.
- Harness collapse check counts `#inst.items` instead of visible frames, because the fallback window refills with the next items after a collapse.
- Header strip right edge changed from -12 to -6 (plus 16 with the bar) so columns stay aligned with the new box geometry; plan 03 revisits the geometry.

## Known Stubs

None.

## Threat Flags

None. No new network, auth or file surface; rows never inherit the finder's scripted entry templates (grep gate: 0 hits), fields are written only on our own pooled frames.

## In-game check (UAT-1)

In Forever, `/dump C_XMLUtil.GetTemplateInfo("TerribleGroupFinderListRowTemplate")` must be non-nil. If it is nil, the list silently runs on the W.List fallback (still usable, no scroll bar). Also eyeball: the scroll bar appears only with enough results, the section headers swap plus/minus on click, and hovering a header lights only its own band.

## Self-Check: PASSED

- UI/Templates.xml exists; commits `e51f4b5` and `cadad79` exist; all four harness modes 0 failed.
