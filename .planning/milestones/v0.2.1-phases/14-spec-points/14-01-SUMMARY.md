---
phase: 14-spec-points
plan: 01
subsystem: item-level-data
tags: [talents, inspect, C_Traits, ItemLevel]
requires: []
provides:
  - "ns.ILvl.TalentsOf(unit), ns.ILvl.TalentsKnown(unit)"
  - "known[guid].talents in the item level GUID cache"
affects: [14-02]
key-files:
  modified:
    - ItemLevel.lua
    - CLAUDE.md
requirements-completed: [SPC-01]
completed: 2026-11-16
---

# Phase 14 Plan 01: Talent data in ns.ILvl Summary

Talent points per tree are read live for you and, for others, in the same guarded `INSPECT_READY` pass item level uses, cached per GUID, and exposed as `ILvl.TalentsOf` / `ILvl.TalentsKnown`.

## DATA SOURCE CHANGE (for the author)

The locked decision named `C_SpecializationInfo.GetSpecializationInfo(i, isInspect).pointsSpent`. Research found Forever's own talent frame reads `C_Traits.GetGroupCurrencyInfo(configID, groupIDs)[i].currencyInfos[1].spent` (groups from `GetGroupDisplayInfoByTreeID`, tree from `GetConfigInfo(configID).treeIDs[1]`), no Camelot file reads `pointsSpent`, and Forever has one spec per class. So the tooltip source is the C_Traits group currency read: `isInspect = true` became the inspect config `Constants.TraitConsts.INSPECT_TRAIT_CONFIG_ID` (-1), `false` became your active combat config. `pointsSpent` is still printed by `/tgf ilvl` next to the C_Traits figure so you can compare in game. Everything else in the decisions stands.

## What was built

- `ReadTalents(configID)`: pcall'd, every value `Secret()`-checked (any secret gives nil), groups in `ipairs` order, a group with no currency entry counts 0.
- `OwnConfigID()`: `GetCombatConfigIDForSpecGroup(GetActiveSpecGroup())`, then `GetActiveConfigID()`, rejecting a candidate whose readable type differs from `CamelotCombat`.
- `Remember(unit, r, talents)` stores talents even when items never load (keeps an earlier ilvl); observers still get `(guid, ilvl)`, `ilvl` may be nil. `ILvl.Inspected` is nil-safe for entries without `ilvl`.
- Capture only on the first pass: `ReadCurrent(0)` after the serial / lastTarget check, and the foreign `Try()` first pass. `false` records "answered, nothing readable" so no re-inspect.
- Guard: `TalentsInspecting()` (`PlayerSpellsFrame:IsInspecting()`, read only, unreadable counts as busy) added to `Busy()` and to the `ClearInspectPlayer` condition in `Done`.
- Probe: `PrintTalents` (config, type, tree, per-group spent, C_Traits figure, `GetSpecializationInfo` pointsSpent for 1..3), own-config lines in `ProbeSelf`, per-member lines plus "talents captured", and an "after clear" read in `Done` (non-quiet only).
- CLAUDE.md `ItemLevel.lua` line updated.

## Verification

- `stylua --check .` clean. Greps: no `SetInspectUnit` / `ClearInspectUnit` / `GetTalentTabInfo`; `ReadTalents(INSPECT_CONFIG)` appears at 3 sites (first-pass capture, foreign first pass, probe after-clear read); guard constants unchanged; no new `NotifyInspect` call sites.
- Smoke harness (session scratchpad `smoke/`, not shipped) extended with a "talents 14-01" block: own `31/20/0`, all zero / missing API / secret `spent` give nothing, live follows changes, `IsInspecting()` blocks the quiet inspect, inspected talents stored even though items never load, `TalentsKnown` true after the answer, nil-safe `Inspected`. Full run: 0 failed. The existing `/tgf ilvl` smoke call now stubs `UnitIsPlayer` locally since the probe calls `TalentsOf("player")`.

## Deviations from Plan

- The two tasks were committed as one code commit (`ItemLevel.lua`, the probe uses helpers from Task 1 and was written in the same pass) plus a docs commit for CLAUDE.md and this summary.
- The `ClearInspectPlayer` block in `Done` reads the "after clear" figure in the same edit as the guard change.

## Known Stubs

None.

## Self-Check: PASSED
