---
phase: 22-small-fixes
plan: 04
subsystem: docs
tags: [claude-md, uat]
requires: [22-01, 22-02, 22-03]
provides:
  - "CLAUDE.md entries for the eye guards, invite outcomes and search narrowing"
  - "22-HUMAN-UAT.md with 13 in-game checks"
key-files:
  modified: [CLAUDE.md]
  created: [.planning/phases/22-small-fixes/22-HUMAN-UAT.md]
metrics:
  completed: 2026-11-26
---

# Phase 22 Plan 04: Docs and UAT Summary

CLAUDE.md's QuestButton, Messages, Listings, Table and InPlace entries now describe the guarded eye, the invite outcomes and the first-search narrowing; 22-HUMAN-UAT.md lists 13 pending in-game checks.

## What changed
- CLAUDE.md: five entries extended in place, no new sections; CHANGELOG.md and README.md untouched.
- 22-HUMAN-UAT.md: eye checks, taint log, invite outcomes, and the SRCH-01 flow (reload, pick category, pick activity or group checkbox, Refresh while the first search is out) plus no-regression checks.
- `stylua --check .` clean; no Lua file changed.

## Deviations from Plan
None.

## Commits
- c19879e: docs(22-04): record eye guards, invite outcomes and search narrowing in CLAUDE.md
- UAT file committed with this summary.

## Self-Check: PASSED
