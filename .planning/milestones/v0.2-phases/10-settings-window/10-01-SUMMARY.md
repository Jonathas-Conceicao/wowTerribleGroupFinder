---
phase: 10-settings-window
plan: 01
subsystem: ui
tags: [settings, blizzard-settings-api, proxy-settings]
requires: []
provides:
  - ns.SettingsPanel (Init, ID): the addon's page under AddOns in the game's Settings
  - IP.OpenMessages(): opens the finder on the Messages tab
  - registry metadata (section, tooltip, parent) on every option
affects: [10-02]
key-files:
  created: [UI/SettingsPanel.lua]
  modified: [Settings.lua, UI/InPlace.lua, Core.lua, TerribleGroupFinder.toc]
requirements-completed: [SET-01, SET-02, SET-03, SET-04, SET-05, SET-06, SET-07]
duration: short
completed: 2026-11-14
---

# Phase 10 Plan 01: Settings page Summary

A TerribleGroupFinder page in the game's Settings (AddOns), built from `ns.Settings.List()` with proxy settings (`TGF_<key>`), three sections, Swipe animations as a child of Dynamic refresh, and an "Edit whisper messages" button that opens the finder on the Messages tab.

## Task commits
1. Task 1 (registry metadata, IP.OpenMessages, SettingsPanel, TOC, Core init): 745367f
2. Task 2 (harness stubs and checks): outside the repo (smoke folder; backups harness.pre-10.bak, tail.pre-10.bak); no commit

## Verification
`stylua --check .` clean; smoke harness `""`, `--fallback`, `--attach` all `SUMMARY: 0 failed` (47 / 3 / 48 settings and OpenMessages checks).

## Deviations from Plan
None. D-10-01: the Settings API on the `forever` branch has no category icon call, so none is set.

## Deferred in-game checks (milestone end)
- Category appears under AddOns with three sections; each checkbox flips its feature at once and survives /reload and relog
- Swipe animations greys out and indents under Dynamic refresh when that is off
- Edit whisper messages opens the finder on Messages with Settings still open (note any overlap); combat prints the message
- `/console taintLog 2` shows no TerribleGroupFinder taint on the Settings panel

## Self-Check: PASSED
