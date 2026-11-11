---
phase: 03-rows-tooltip-and-own-listing
plan: 03
subsystem: ui-tooltip
tags: [tooltip, playstyle, voice, activities, bosses]
requires: ["03-02"]
provides:
  - "W.AtlasMarkup (empty when the atlas is missing) and W.Playstyle (game string, global, preview names)"
  - "Row tooltip in Forever's stock order and wording (StockTooltip), our extras after it (ExtrasTooltip), pending-blank line writer"
affects: [03-04]
tech-stack:
  added: []
  patterns: ["pending-blank tooltip writer: no leading, trailing or double blank lines", "show-time pcall reads for bosses and activity groups"]
key-files:
  created: []
  modified: [UI/Widgets.lua, UI/Table.lua]
key-decisions:
  - "Bosses and activity group names are read only when the tooltip opens, under pcall and the secret guard; any failure skips the block (flat activity list for groups)"
  - "Comment is only ever the argument of LFG_LIST_COMMENT_FORMAT, never the format string"
requirements-completed: [UIP-07, UIP-09, UIP-13]
duration: 35min
completed: 2026-11-11
---

# Phase 3 Plan 03: Tooltip in stock order Summary

The row tooltip now reads like Forever's own: Delisted / New player friendly, the leader line (leader icon for groups, class-coloured name and marks, grey level, micro role icons for solo players or the leader's large role), member lines for 2 to 10 members, the light grey comment, member count, stock voice wording, activities grouped by activity group (bright blue for those in your listing), and bosses defeated. Our extras follow after one blank line: playstyle in green, solo spec / area, friends in group, listed age, hidden note last.

## Tasks

1. Harness probes tip-order, tip-solo, tip-colours, tip-fallbacks (outside the repo, not committed). Red first (32 failures).
2. and 3. Helpers, stock blocks and extras: commit d80b7b1.

## Harness results (final)

- default: SUMMARY: 0 failed
- --gs: SUMMARY: 0 failed
- --fallback: SUMMARY: 0 failed
- --attach: SUMMARY: 0 failed
- `stylua --check .` clean; grep gate (no Can play, Looking for, LFGBrowseSearchEntryTooltip_UpdateAndShow in Table.lua code) = 0; forbidden-call counter 0.

## Deviations from Plan

**1. Tasks 2 and 3 committed together.** The stock blocks and the extras were written as one tooltip rewrite and share the line writer, so they are one commit (d80b7b1).

**2. [Harness] Probe adjustments (outside the repo).** The secret-encounter probe installs its own `issecretvalue`; the atlas-missing probe checks only the atlases the tooltip adds (newplayerchat, groupfinder), because the friend/Battle.net mark icons follow the existing cached `W.Rich()` decision.

**3. Requirements:** UIP-07 (row half in 03-02, tooltip voice wording here), UIP-09 and UIP-13 ticked by hand in REQUIREMENTS.md.

## Known Stubs

None.

## Threat Flags

None. The tooltip uses `GameTooltip` only; `GetSearchResultEncounterInfo` and `GetActivityGroupInfo` are read under pcall with secret guards at show time.

## Self-Check: PASSED

UI/Widgets.lua and UI/Table.lua modified; commit d80b7b1 present.
