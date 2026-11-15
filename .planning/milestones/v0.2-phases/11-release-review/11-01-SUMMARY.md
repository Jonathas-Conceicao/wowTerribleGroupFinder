---
phase: 11-release-review
plan: 01
subsystem: release
tags: [cleanup, claude-md, toc, package]
requires: []
provides:
  - cleaned v0.2 Lua comments, dead code removed
  - CLAUDE.md matching the shipped addon
  - verified TOC and local zip
affects: [11-02]
key-files:
  modified: [Region.lua, ItemLevelUI.lua, Core.lua, CLAUDE.md]
requirements-completed: [REL-05]
duration: short
completed: 2026-11-14
---

# Phase 11 Plan 01: Code cleanup, CLAUDE.md, TOC and package Summary

Removed the harness-only `R.MarkupFor`, rewrote the scaffolding comments in present tense, brought CLAUDE.md in line with v0.2 and verified the TOC and zip.

## Audit findings

Grep of shipped Lua / XML for review IDs, decision IDs, phase numbers, `.planning`, "prototype", TODO / FIXME, "taint" history and unused exports found only:
- `R.MarkupFor` (Region.lua): no shipped caller; removed.
- Region.lua header phrased as an open question; rewritten.
- ItemLevelUI.lua character sheet comment told a taint story; reworded to the rule.
- Core.lua migration comment said "prototype key"; neutral wording.
- `UI.sheetRow` kept, with its "read by the smoke tests" comment.
No mechanical helper merges were made (none found that were behaviour-neutral).

## Accomplishments
- Harness (outside the repo, tail.lua) now asserts on `R.Flag(l)` instead of `R.MarkupFor`; default, `--fallback` and `--attach` all end `SUMMARY: 0 failed`; `stylua .` clean.
- CLAUDE.md: "Prototype stage" now "Early release (v0.2)"; the Taint bullet states the character sheet row as a narrow exception without the bug story; migration and region lines are neutral; "prototype" removed from the workflow section. Gear score, `/tgf auto` and "gone" rows were already gone from it; Settings, SettingsPanel, Motion, ItemLevelUI and Region lines already present and accurate.
- TOC: `## Version: @project-version@` kept (tag v0.2.0 is for the author, not created); load list matches the shipped files, no GearScore.lua.
- `scripts/package.ps1` zip (21 files, no warnings): TOC, all 16 TOC files, `Media/Textures/tgf_icon_64x64.tga`, `flag_au.tga`, `flag_us.tga`, LICENSE; nothing from Media/Source, Media/Screenshots or .planning.

## Task Commits
1. Task 1: ac357de (refactor)
2. Task 2: CLAUDE.md edits, committed with this summary

## Deviations from Plan
None. `e3.js` in the harness folder is a one-off patch script already applied; only `tail.lua` feeds `splice.js`, so it was left.

## Self-Check: PASSED
