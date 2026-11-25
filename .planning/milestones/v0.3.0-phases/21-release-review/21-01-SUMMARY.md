---
phase: 21-release-review
plan: 01
subsystem: release
tags: [cleanup, docs, release-review]
requires: []
provides: [clean v0.3.0 code comments, CLAUDE.md matching v0.3.0, verified zip file set]
affects: [CLAUDE.md, GearSlots.lua]
key-files:
  modified: [GearSlots.lua, CLAUDE.md]
metrics:
  completed: 2026-11-24
---

# Phase 21 Plan 01: Code cleanup and CLAUDE.md accuracy Summary

Three milestone-internal comments in GearSlots.lua reworded to present-tense rules, CLAUDE.md brought in line with the v0.3.0 code, and the local zip checked against the TOC.

## Commits
- f23d031 refactor(21-01): tidy v0.3.0 code comments (GearSlots.lua, comments only)
- dc85b5f docs(21-01): CLAUDE.md for v0.3.0

## Audit findings
Fixed (GearSlots.lua, comment lines only; tables and constants unchanged):
- ENCHANTABLE comment: dropped the "low-confidence source / author's in-game check" sentence.
- /tgf gear banner: now "prints what the slot overlays read".
- Layout constants comment: now "offsets and widths of the slot text, in px".

Grep gates over shipped Lua/XML (review IDs, phase numbers, .planning, TODO, HasGameEye, "first guess", and so on): no v0.3.0 hits left.
Left, before v0.3.0: UI/InPlace.lua:96 and :340 "no longer"; UI/Table.lua "fixed" widths; UI/Widgets.lua:660 "fixed-height"; Region.lua:19, :31 "the author's flagpedia.net PNGs" (a source credit).

Callers checked, all used (nothing removed): IP.LISTING_TAB (QuestButton.lua), ILvl.SLOT_NAMES and ILvl.InspectReadyFor (GearSlots.lua), Q.ZoneSources and Q.HintLine (Probe/Click), Q.lastError (probe line), ITEM_RETRIES, retry.inspectReady, kindOf, LEVEL_ABOVE, EnumValue, EYE_FALLBACK, OUTLINE_ATLAS, listingWidthPending / listingWidthEvents / listingExtra (all used in InPlace.lua). No HasGameEye remnants; no stray prints or commented-out code found.

Near-duplicates, left: QuestButton PlainNumber / PlainString / Secret (different type checks, no mechanical merge); Say/Call vs Present/Print, and per-file Secret / Clear / Print / Call locals: left, convention; the two pcall(RedrawKind) branches in readyFrame and the InspectFrame OnHide vs ClearKind: left (not a mechanical, behaviour-neutral merge); Restore vs HeaderBase (different jobs).

## CLAUDE.md changes
Intro v0.3.0; taint bullet notes the finder is never resized in combat; Settings line says eliteQuestButton is read by QuestButton.lua; GearSlots line states the enchantable rule, RequestLoadItemDataByID / GET_ITEM_INFO_RECEIVED redraw with 1 s retries as backstop and the separate inspect budget; InPlace line states the combat rule (PLAYER_REGEN_ENABLED) and that Browse's hide restores the base width. Core (schema 4, gear/quest commands), Settings (13 keys, order, four defaults on), SettingsPanel, ItemLevel, ItemLevelUI, QuestButton and MeterReset lines checked against the code with no difference found.

## TOC and package
TOC keeps `## Version: @project-version@` and loads QuestButton.lua and GearSlots.lua; every load-list file exists. scripts/package.ps1 ran (28 files, no warnings). Zip entries: TOC, Core, Settings, Preview, ItemLevel, ItemLevelUI, QuestButton, GearSlots, Region, MeterReset, Messages, Listings, UI/{Widgets.lua, Templates.xml, Motion, Table, MainFrame, InPlace, SettingsPanel, Listing}, Media/Textures/{tgf_icon_64x64, flag_au, cn, eu, kr, tw, us}.tga, LICENSE. Nothing from Media/Source, Media/Screenshots or .planning. Version to tag: v0.3.0 (tagged at milestone completion by the author, not here).

## Verification
`stylua --check .` clean. No in-game test possible.

## Deviations
None. CLAUDE.md is LF in the working copy (git warns of CRLF conversion on touch); only intended lines changed.

## Self-Check: PASSED
