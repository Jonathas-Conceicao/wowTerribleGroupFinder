---
phase: 10-settings-window
plan: 02
subsystem: ui
tags: [settings, slash-commands]
requires: [10-01]
provides:
  - SP.Open / SP.PrintAll / SP.Command in UI/SettingsPanel.lua
  - /tgf settings, /tgf config, /tgf set <key> on|off
key-files:
  modified: [UI/SettingsPanel.lua, Core.lua, CLAUDE.md]
requirements-completed: [SET-01, SET-07]
duration: short
completed: 2026-11-14
---

# Phase 10 Plan 02: Settings slash commands Summary

`/tgf settings` (alias `config`) opens the addon's page out of combat (a printed message in combat); without the Settings API it prints every option and its state, and `/tgf set <key> on|off` changes and saves one (keys matched case-insensitively, only registered options, only on/off/true/false/1/0). Help and CLAUDE.md are current.

## Task commits
1. Task 1 (SP.Open / PrintAll / Command, slash dispatch, USAGE, CLAUDE.md): see git log, "feat(10-02)"
2. Task 2 (harness checks `settings-slash`): outside the repo (smoke folder; backup tail.pre-10-02.bak); no commit

## Verification
`stylua --check .` clean; smoke harness `""`, `--fallback`, `--attach` all `SUMMARY: 0 failed` (10 / 7 / 10 slash checks).

## Deviations from Plan
None.

## Deferred in-game checks (milestone end)
- `/tgf settings` and `/tgf config` land on the TerribleGroupFinder page with the finder closed, open, and right after `/reload` (`HasRestrictions` must not block a slash command)
- In combat they print the message
- `/tgf set regionflags off` hides the flags at once; the page shows the box unticked when opened next
- A typo such as `/tgf nonsense` prints the usage with `settings`

## Self-Check: PASSED
