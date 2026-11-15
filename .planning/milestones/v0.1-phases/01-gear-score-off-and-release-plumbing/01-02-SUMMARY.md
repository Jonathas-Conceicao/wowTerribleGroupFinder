---
phase: 01-gear-score-off-and-release-plumbing
plan: 02
subsystem: docs
tags: [gear-score, design-notes]
requires: []
provides:
  - ".planning/research/GEARSCORE.md: gear score design and one-step re-enable"
affects: [backlog-999.1]
key-files:
  created: [.planning/research/GEARSCORE.md]
  modified: [.planning/research/DESIGN-NOTES.md]
decisions:
  - "GEARSCORE.md describes the re-enable as the single edit ns.GEAR_SCORE = true, matching the code from plan 01"
metrics:
  tasks: 2
  completed: 2026-11-11
requirements-completed: [GS-02]
---

# Phase 1 Plan 02: Gear Score Design Notes Summary

`.planning/research/GEARSCORE.md` now holds the full gear score design (formula, slot weights, quality factors, cache, fresh vs outdated colours, inspect queue, display rules, addon-whisper sharing idea, open in-game checks) and the one-edit re-enable (`ns.GEAR_SCORE = true` in Core.lua) with what comes back and what does not.

## Commits
- `7b44fe9` GEARSCORE.md
- `35940c2` DESIGN-NOTES.md pointer on the Gear score bullet
- A follow-up commit fixes one wording line ("The shirt and tabard") found by the verify loop.

## Verification
All numbers were copied from GearScore.lua, UI/Widgets.lua, UI/Table.lua and Messages.lua as they are now (after plan 01). The verify loop prints no MISSING; the word count check for forbidden words is 0; the DESIGN-NOTES diff is 3 lines.

## Deviations from Plan
None. Backlog 999.1 "Gear score: finish or drop" with Source GS-02 already exists in ROADMAP.md, so nothing was changed there.

## Known Stubs
None.

## Self-Check: PASSED
