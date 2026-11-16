---
phase: 15-release-review
plan: 01
subsystem: release
tags: [cleanup, claude-md, packaging]
requirements-completed: [REL-06]
key-files:
  modified: [UI/Table.lua, CLAUDE.md]
metrics:
  completed: 2026-11-16
---

# Phase 15 Plan 01: Code cleanup, CLAUDE.md, package check Summary

The v0.2.1 code was already near clean; one comment was reworded and CLAUDE.md's release line corrected, with all three smoke modes unchanged.

## Commits
- e31631c refactor(15-01): state the flag tag measurement as a rule (UI/Table.lua)
- db28327 docs(15-01): CLAUDE.md release line reads v0.2.1 (CLAUDE.md)

## Audit findings
- Grep for CR-/WR-/IN-/D-NN, Phase N, .planning, TODO/FIXME/XXX/prototype, "used to", "was wrong", "fix for" across shipped Lua / XML / JS: nothing. Other history words hit only unrelated present-tense uses (ItemLevel.lua:33, Messages.lua:173, Settings.lua:31, InPlace.lua:93/337, Table.lua:23/876/914, Widgets.lua:660): left.
- UI/Table.lua:1300 "a pooled row's old width would cut a wider tag": reworded as the present rule. Fixed.
- Added comments in MeterReset, Region, ItemLevel, ItemLevelUI, Preview, Settings, Core reviewed line by line: all state rules, no bug stories. Left.
- Unused locals / functions in all v0.2.1 Lua files (script over local declarations): none.
- Debug leftovers: none in Lua; png2tga.js has one `console.log` per converted flag (intended tool output), header already says what it converts and how to run it. Left.
- Near-duplicate helpers (secret/type guards in talent readers, AddLine vs UpdateLine, SaneGroup vs saved-shard sanitizer, flag/tag sizing, popup scans): none mergeable mechanically without behaviour risk; left. Candidates for the author only if wanted later.
- Region.lua / CLAUDE.md name flagpedia.net: allowed (the rule covers the README only).

## CLAUDE.md
Settings (ten keys in order), MeterReset, ItemLevelUI, Region, SettingsPanel (sections), Media lines already matched the code; only the header "v0.2" became "v0.2.1". No review/decision IDs outside the GSD Workflow section.

## TOC and package
`## Version: @project-version@` kept; MeterReset.lua listed and present. package.ps1 packaged 26 files, no warnings: TOC, 17 Lua/XML files, tgf_icon_64x64.tga, flag_us/au/eu/cn/kr/tw.tga, LICENSE; nothing from Media/Source or Media/Screenshots. Version to tag: v0.2.1 (tagged at milestone completion, not here).

## Harness (before = after)
- default 1033 PASS, --fallback 871, --attach 1118; each ends `SUMMARY: 0 failed`. `stylua --check .` clean.

## Note for 15-02 / the author
The inspect guard timing (14 WR-02) may not be in-milestone only: v0.2.0 already ran a quiet inspect guarded only by a 2 s gap (OTHERS_BUSY), so it could already disturb the game's Inspect Talents. A possible v0.2.0 fix to mention in the changelog is the author's call.

## Deviations
None.

## Self-Check: PASSED
