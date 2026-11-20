---
phase: 17-release-review
plan: 01
subsystem: release
tags: [cleanup, docs, packaging, v0.2.2]
requires: []
provides: [v0.2.2 code tidy, CLAUDE.md for v0.2.2, verified package]
affects: [MeterReset.lua, Messages.lua, Core.lua, UI/SettingsPanel.lua, UI/InPlace.lua, CLAUDE.md]
tech-stack:
  added: []
  patterns: []
key-files:
  created: []
  modified: [MeterReset.lua, Messages.lua, Core.lua, UI/SettingsPanel.lua, UI/InPlace.lua, CLAUDE.md]
decisions:
  - "SP.AfterClose stays: live caller M.Move (in combat SP.CloseThen leaves the panel shown, the dialog waits for it to hide)"
  - "InPlace's OpenAfterSettings is left beside SP.AfterClose: merging would put both on one latest-wins slot, not behaviour-neutral"
  - "Version to tag: v0.2.2 (tagged at milestone completion, not here); TOC keeps @project-version@"
metrics:
  duration: ~3 min
  completed: 2026-11-19
requirements: [REL-07]
---

# Phase 17 Plan 01: Code cleanup, CLAUDE.md and package check Summary

The v0.2.2 code (meter prompt Move, Settings close-then-act, activity menu, schema 3) tidied with no behaviour change: two mechanical merges, one dead field removed, comments stating current rules; CLAUDE.md matches the code at (v0.2.2); the local zip holds exactly the shipped set.

## Tasks

| Task | Name | Commit | Files |
| ---- | ---- | ------ | ----- |
| 1 | Audit and clean the v0.2.2 code | db5aa15 | Core.lua, Messages.lua, MeterReset.lua, UI/SettingsPanel.lua, UI/InPlace.lua |
| 2 | CLAUDE.md for v0.2.2; TOC, version, package | c099e95 | CLAUDE.md |

## Audit findings (Task 1)

| Where | Finding | Outcome |
| ----- | ------- | ------- |
| shipped Lua / XML | `CR-`/`WR-`/`IN-`/`D-NN`, `.planning`, `Phase N` | none found |
| shipped Lua | `TODO`/`FIXME`/`XXX`/`prototype`/`used to`/`was lost`/`was wrong`/`fix for` | none found |
| ItemLevel.lua:33, Messages.lua:177, Settings.lua:32 | "twice" | left: pre-v0.2.2 rule descriptions, not bug stories |
| UI/InPlace.lua:93, :337 | "no longer" | left: pre-v0.2.2, describe current behaviour |
| UI/InPlace.lua:409-411, :432 | "we never close it ourselves" / "never closed by us": no longer true since the Settings buttons close the panel via `SP.CloseThen` | fixed: states nothing here closes it, the Settings button does through its own Close |
| UI/SettingsPanel.lua CloseThen | comment folded "Close failed" into the dropped-action case, while the code runs `fn` then | fixed: states both rules (dropped while unapplied settings ask; runs now where Close failed, as in combat) |
| MeterReset.lua `M.Move` doc | didn't say why the panel can still be shown | fixed: in combat nothing closes it, the dialog shows once it hides |
| MeterReset.lua `f.icon` | field set, never read (code or harness) | removed |
| MeterReset.lua Ask / EndMove | same three lines (target, question text, Yes/No buttons) | merged into local `SetQuestion` |
| Messages.lua ChooseActivity | two menu entries with the same StillThere / Send / Redraw body | merged into local `Pick(choice)` (choice tables only read by `M.Send`) |
| Core.lua Migrate comment | "default became off in v0.2.2" (history wording) | fixed: states the schema 3 rule |
| Settings.lua `meterResetOnGroup` comment | present-tense already | left |
| `SP.AfterClose` | still referenced: MeterReset.lua `M.Move` (combat path) and `SP.CloseThen` | kept (live callers) |
| `M.Moving` | caller Core.lua `/tgf meter` | kept |
| IN-02 `kind` parameter | gone (`Format(kind, l, text, activity)`'s `kind` is the preset kind, used) | nothing to do |
| UI/InPlace.lua `OpenAfterSettings` vs `SP.AfterClose` | near-duplicate one-time OnHide hooks | left: AfterClose is one latest-wins slot; sharing it would let a Move and an OpenMessages request replace each other |
| MeterReset.lua Yes/No vs Default/Lock | both already through `MenuButton` (template + fallback) | nothing to do |
| MeterReset.lua saved-spot check | Init and Place both use `SavedPos`/`Finite` | nothing to do |
| Messages.lua menu checks vs Table's Whisper | Table's checks guard the click, `StillThere` guards a later menu pick (also checks the listing is still shown) | left: different moments, not mergeable mechanically |
| debug leftovers | only `print` is Core.lua `Print`; no commented-out code or unused locals found in the diff | none |

## Verification

- Harness pass counts, HEAD before edits vs after: default 1057 / 1057, `--fallback` 895 / 895, `--attach` 1142 / 1142; all `SUMMARY: 0 failed`
- `stylua --check .` clean; Lua files kept CRLF
- Task 1 grep gates print nothing; `AfterClose` hits are its definition and the live caller in MeterReset.lua
- CLAUDE.md: `(v0.2.2)` 1, `(v0.2.1)` 0; contains schema 3, `meterResetOnGroup`, `DB.meterPos`, `M.Move`, `SP.CloseThen`, the activity menu's Edit; no review / decision IDs
- TOC: `## Version: @project-version@`, every load-list file exists
- `scripts/package.ps1`: exit 0, no WARNING, 26 files. Zip entries: TerribleGroupFinder.toc, Core.lua, Settings.lua, Preview.lua, ItemLevel.lua, ItemLevelUI.lua, Region.lua, MeterReset.lua, Messages.lua, Listings.lua, UI/Widgets.lua, UI/Templates.xml, UI/Motion.lua, UI/Table.lua, UI/MainFrame.lua, UI/InPlace.lua, UI/SettingsPanel.lua, UI/Listing.lua, Media/Textures/tgf_icon_64x64.tga, flag_au/cn/eu/kr/tw/us.tga, LICENSE. Nothing from Media/Source, Media/Screenshots or .planning
- Version to tag: v0.2.2 (tagged at milestone completion, not here)

## CLAUDE.md changes (Task 2)

Most lines (Core schema 3, Settings defaults, MeterReset, Messages activity menu, SettingsPanel CloseThen) already matched the code. Changed: release line to (v0.2.2); the Key Constraints Taint line now names the Settings panel's own `Close` from the Move / Edit whisper messages buttons, consistent with the SettingsPanel line; Core line lists the `/tgf` commands (incl. `meter`); Messages line says Whisper / Send Message both open the activity menu.

## Deviations from Plan

**1. [Rule 1 - Stale comment] UI/InPlace.lua comments edited in Task 1**
- Not in Task 1's `<files>`, but its comments said the Settings panel is never closed by the addon (matched the plan's `never close` acceptance grep and is no longer true). Comment-only edit, included in commit db5aa15.

**2. Baseline counts measured from a HEAD export**
- The pass counts before the first edit were taken by running the harness on a `git archive HEAD` copy in the scratchpad (same commit as before the edits).

## Self-Check: PASSED
- Commits db5aa15 and c099e95 exist; modified files present; SUMMARY written.
