---
phase: 23-release-review
plan: 01
subsystem: release
tags: [cleanup, claude-md, package]
requirements: [REL-09]
key-files:
  modified: [Messages.lua, CLAUDE.md]
metrics:
  completed: 2026-11-26
---

# Phase 23 Plan 01: Code cleanup, CLAUDE.md, package check Summary

The v0.3.1 code audit found one comment to reword; CLAUDE.md now says v0.3.1; the local zip holds exactly the TOC file set.

## Commits
- 3e892af: chore(23): tidy v0.3.1 code comments (Messages.lua, comment only)
- cb31e32: docs(23): CLAUDE.md for v0.3.1

## Audit findings
- Messages.lua:345 "(never a nil hole in the list)": fixed, reworded to the rule only.
- QuestButton.lua:727 "kept from a build that failed partway, so a retry never makes a second frame": left, present-tense rule.
- UI/InPlace.lua:158 and :407 "no longer": left, before v0.3.1 (blame f4aa854c is an ancestor of main).
- UI/InPlace.lua:53 "first search after a reload": left, describes the case handled now.
- Other grep hits (ItemLevel*, Table.lua "fixed", Widgets "fixed-height") are unrelated words, not v0.3.1 history.
- No review IDs, decision IDs, requirement IDs, phase numbers, `.planning` paths, TODO / FIXME in shipped Lua or XML.
- Callers verified (none dead): `M.MarkInvited` (Messages.lua x2, UI/Table.lua), `FailedSteps` and `Q.lastError` (/tgf quest), `coverFrame` (BuildCover), `PatternOf` (StartTracking), `NarrowSet` / `narrowTo` (InPlace), `Listings.Read`'s `only`, `ClearDropped`.
- No commented-out code or stray prints found.
- Near-duplicates: `Try` / `Guarded` / `Call` and per-file `Secret` / `Print` helpers: left: convention. No in-file merge was mechanical enough to do.

## CLAUDE.md
Only the intro changed (v0.3.0 to v0.3.1). The QuestButton, Messages, Listings, UI/Table and UI/InPlace lines were checked against the code and already match; none cites bug history or IDs.

## TOC and package
TOC keeps `## Version: @project-version@`; every load-list file exists. package.ps1 packaged 28 files: the TOC, Core, Settings, Preview, ItemLevel, ItemLevelUI, QuestButton, GearSlots, Region, MeterReset, Messages, Listings, UI/{Widgets, Templates.xml, Motion, Table, MainFrame, InPlace, SettingsPanel, Listing}, Media/Textures/{tgf_icon_64x64, flag_au/cn/eu/kr/tw/us}.tga and LICENSE; nothing from Media/Source, Media/Screenshots or .planning. Version to tag: v0.3.1 (tagged at milestone completion by the author, not here).

## Deviations
None. `stylua --check .` clean. (`state.advance-plan` and `requirements.mark-complete` skipped as instructed.)
