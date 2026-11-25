---
phase: 18-opt-in-defaults-and-settings-sections
plan: 01
subsystem: settings
tags: [settings, migration, defaults]
requires: []
provides:
  - "Opt-in defaults (4 on, 9 off), explicit on every option"
  - "ns.Migrate schema 4 from a frozen v0.2.2 list"
  - "eliteQuestButton, slotItemLevel, slotEnchants registered"
  - "Page sections: Group finder, Player inspection, Damage meter, Messages"
affects: [19, 20]
key-files:
  modified: [Settings.lua, Core.lua, CLAUDE.md]
key-decisions:
  - "Frozen V022_ON list in Core.lua; Migrate never reads the registry"
metrics:
  tasks: 3
  files: 3
  completed: 2026-11-24
---

# Phase 18 Plan 01: Opt-in Defaults and Settings Sections Summary

Registry now defaults only Elite quest button, Dynamic refresh, Swipe animations and Region flags on; Migrate schema 4 keeps the six v0.2.2-on options for players with saved data; the page lists Group finder, Player inspection, Damage meter, Messages.

## Commits
- 08cb213 feat(18-01): registry (Task 1)
- ca19fd0 feat(18-01): Migrate schema 4 (Task 2)
- c5507c1 docs(18-01): CLAUDE.md (Task 3)

## Migrate fixture walk (no Lua available; walked against the finished code)
`existing` is computed once first; schema 3 branch unchanged; schema 4 branch sets the six `V022_ON` keys true only when `existing` and not already a boolean, then `schema = 4`.

| Fixture | Result |
|---|---|
| `{}` | existing false; only `schema = 4` saved; Get: eliteQuestButton, dynamicRefresh, swipeAnimations, regionFlags on, rest off. OK |
| `{gs = 1}` | gs cleared; schema 3 saves meterResetOnGroup = true; schema 4 saves the six; six + meterResetOnGroup on, new keys at new defaults. OK |
| `{schema = 3}` | schema 3 skipped; six = true; schema 4; meterResetOnGroup off, slot keys off, eliteQuestButton on. OK |
| `{schema = 3, specPoints = false}` | five = true; specPoints stays false. OK |
| `{schema = 3, meterResetOnGroup = true}` | six = true; meterResetOnGroup stays on. OK |
| `{schema = 2, ilvlInspect = false, shards}` | schema 3 saves meterResetOnGroup; schema 4 saves five; ilvlInspect stays false; shards untouched; ends at 4. OK |
| `{schema = 4}` | both branches skipped; new defaults. OK |
| `{schema = 3, ilvlInspect = "x"}` | not a boolean, so saved true; on. OK |

Accepted (PITFALLS 7.6, 8): a v0.1 table saved empty looks new and gets the new defaults; the page's Defaults button saves the new defaults, turning existing players' preserved options off.

## Deviations from Plan
None - plan executed as written. `stylua --check .` clean; CHANGELOG.md and README.md untouched. Acceptance greps confirmed (13 keys in order, 4 true / 9 false defaults, fill loop gone, `next(db)` once in Migrate, no `ns.Settings` in Migrate).

## Deferred human checks (end of milestone)
1. Fresh install: no item level on tooltips, sheet or Inspect, no meter prompt; finder features work.
2. v0.2.2 saved file: item level / talents / meter-on-instance as before; options saved off stay off.
3. Settings page sections and order as above; Swipe animations under Dynamic refresh.
4. `/tgf set slotEnchants|eliteQuestButton|slotItemLevel on|off` prints the change and the checkbox follows.

## Known Stubs
The three new keys are read by no feature yet (Phases 19 / 20), by design.

## Self-Check: PASSED
