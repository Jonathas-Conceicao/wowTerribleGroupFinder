---
phase: 06-gear-score-removal-and-settings-foundation
verified: 2026-11-14T00:00:00Z
status: human_needed
score: 4/4 must-haves verified (automated)
human_verification:
  - test: "Load the addon in Forever with a real v0.1 SavedVariables file that has gs data; /reload"
    expected: "No Lua errors; gs key gone from TerribleGroupFinderDB afterwards; no inspects after a ready check; Browse shows no GS column, GS sort, Your GS or GS tooltip lines"
    why_human: "Real client and real saved file cannot be run here"
---

# Phase 6 Verification

**Goal:** Gear score gone, old data cleaned, settings registry in place.
**Requirement:** GSR-01 (both plans declare it; REQUIREMENTS.md maps it to Phase 6, marked complete; no orphans).

| # | Truth | Status | Evidence |
|---|-------|--------|----------|
| 1 | No GS column, sort, "Your GS", tooltip lines | VERIFIED (code) | git grep for `GS column`, `Your GS`, `ns.GS`, `GEAR_SCORE`, `GS(`, `row.gs`, `myGS`, `GearScore` outside `.planning` and CHANGELOG returns nothing; smoke harness (default, `--fallback`, `--attach`) each `SUMMARY: 0 failed` |
| 2 | v0.1 `gs` data cleared, no errors, no ready-check inspects | VERIFIED (code), in-game human | `ns.Migrate` (Core.lua:33) sets `db.gs = nil` and `db.autoRefresh = nil` on every load, then schema 2; called at Core.lua:272 before `Settings.Init` at 278. No `READY_CHECK` handler remains in any Lua file; the remaining inspects are ItemLevel.lua's tooltip and probe inspects, which are unrelated to gear score |
| 3 | Grep clean, GearScore.lua gone from repo and TOC, notes kept | VERIFIED | File absent; TOC lists no GearScore; `.planning/research/GEARSCORE.md` exists |
| 4 | Registry with seven keys, all on, fresh or migrated DB reads correctly | VERIFIED | `Settings.lua` registers ilvlPlayerTooltip, ilvlItemTooltip, ilvlCharacterSheet, ilvlInspect, dynamicRefresh, swipeAnimations, regionFlags with `default = true`. `Get` returns the saved boolean, else the default. The keys `gs`, `autoRefresh` and others are reserved. Settings.lua is in the TOC. Smoke tests pass |

## Anti-patterns
No TBD, FIXME or XXX markers found in the files checked. The matches for `gs` and `autoRefresh` are only the migration clears and the reserved-key list.

## Human verification required
1. Load the addon with a real v0.1 SavedVariables file that has `gs` data, then run the game. Expected: no Lua errors, `gs` removed from the saved file, no GS UI, no inspects after a ready check.

## Gaps
None found in code.
