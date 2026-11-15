---
phase: 01-gear-score-off-and-release-plumbing
plan: 01
subsystem: gear-score
tags: [lua, wow-addon, gear-score, feature-switch]
requires: []
provides:
  - "ns.GEAR_SCORE = false single switch (Core.lua)"
  - "ns.Short realm-suffix helper"
  - "GS-free Browse table, tooltips and Messages"
affects: [phase-02-table-layout, phase-04-messages]
tech-stack:
  added: []
  patterns: ["load-time column list filtered by one switch", "frame and events created inside Init"]
key-files:
  modified: [Core.lua, GearScore.lua, Messages.lua, Listings.lua, UI/Table.lua]
decisions:
  - "Harness stub frame default height raised to 600 so the pooled list builds enough rows to hover both solo and group listings"
  - "M.TOKENS evaluated at Messages.lua load (Core.lua loads first, so the switch is already set)"
metrics:
  tasks: 3
  completed: 2026-11-11
requirements-completed: [GS-01]
---

# Phase 1 Plan 01: Gear Score Off Summary

Gear score is switched off behind one `ns.GEAR_SCORE = false` in Core.lua: no GS column, "Your GS", tooltip line or `{gs}` key, and GearScore.lua creates no frame, registers no event and starts no inspects. Setting the switch to true restores all of it.

## Commits
- Task 1: harness only (outside the repo), no commit
- Task 2: `991045a` switch, ns.Short, GS.Init early return, Messages and Listings
- Task 3: `9b67b51` Table column/band/tooltip guards (CELL_KEYS, ACTIVITY_X 268 when off)

## Verification harness (not in the repo)
Directory: `C:\Users\jonat\AppData\Local\Temp\claude\3a677a53f55271b6\8039163f-18e8-4930-88a2-d8efcca63b25\scratchpad\smoke\`

Run from that directory:
```
node run.js "C:/Users/jonat/Repositories/TerribleGroupFinder"
node run.js "C:/Users/jonat/Repositories/TerribleGroupFinder" --gs
```

Baseline (unchanged repo, default run): exit 1, "SUMMARY: 35 failed" (GearScore.lua loaded with frames+1, 4 GS events registered, "GS" UI text, TOKENS has {gs}, old request default, no ns.Short, header.gs/myGS/row GS cells present, tooltip line "GS ...").

Final default run: exit 0, GearScore.lua `frames+0 events+0`, all PASS, "SUMMARY: 0 failed".
Final `--gs` run: exit 0; 4 GS events registered, "GS" header text, TOKENS has {gs}, "SUMMARY: 0 failed".
Default run also proves: old saved request text migrated, `db.gs` same table with `Sample.at == 0` (no prune), typed `{gs}` stays literal, READY_CHECK triggers no NotifyInspect, ns.Me().gs nil, 162 tooltip lines captured with none mentioning GS.

## Deviations from Plan
None of substance. `stylua --check .` passes. Edits were applied with a node helper preserving CRLF line endings. Preview.lua untouched (D-08).

## Notes for later phases
- README.md still mentions gear score (lines ~7 and ~12); left for the Phase 5 Release Review (README/CHANGELOG not edited here).
- Known stubs: none.

## Self-Check: PASSED
