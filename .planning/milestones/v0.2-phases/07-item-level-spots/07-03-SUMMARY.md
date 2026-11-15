---
phase: 07-item-level-spots
plan: 03
subsystem: item-level
tags: [lua, tooltip, TooltipDataProcessor]
requires:
  - phase: 07-item-level-spots
    provides: ns.ILvlUI installers (Text, Gold, Install, Init)
provides:
  - Item tooltip line (installer "item")
  - CLAUDE.md architecture lines for ItemLevel.lua and ItemLevelUI.lua
affects: []
tech-stack:
  added: []
  patterns: [TooltipDataProcessor.AddLinePostCall on the ItemName line, once-per-build record keyed by tooltip in a weak table]
key-files:
  created: []
  modified: [ItemLevelUI.lua, CLAUDE.md]
key-decisions:
  - "Once per build: a weak table keyed by tooltip records the info table and line index of our add; a second ItemName line with another index in the same info adds nothing, a rebuild (same index) adds again"
requirements-completed: [ILV-02]
duration: 25min
completed: 2026-11-14
---

# Phase 7 Plan 03: Item tooltip line Summary

Gold "Item Level N" right under the name of weapons, armor and relics on every tooltip that uses Blizzard's tooltip data, once per build, behind `ilvlItemTooltip`; CLAUDE.md now describes `ItemLevel.lua` and `ItemLevelUI.lua` as built.

## Accomplishments
- `AddLinePostCall(Enum.TooltipDataLineType.ItemName, ...)`: the body runs in `pcall`; setting read live; forbidden tooltips and missing `GetProcessingTooltipInfo` skip.
- Level from the GUID's link, else hyperlink, else id; gear classes only (weapon / armor), no bag / quiver / ammo / shirt / tabard slots, level above 1, `overrideItemLevel` wins; skipped when a stock type-31 line exists; every value passes the secret guard. Nothing written on the tooltip, info or data; no `Show()`.
- CLAUDE.md: `ItemLevel.lua` line rewritten (data, cache, inspect guard, observers, probe), new `ItemLevelUI.lua` line, Taint bullet extended.
- Harness: 25 `ilvl item:` checks; default, `--fallback`, `--attach` all `SUMMARY: 0 failed`. stylua clean, deployed with install.ps1.

## Task Commits
1. Tasks 1-2 (one commit, the code and its doc line belong together): 7a6cf26 `feat(07-03): item level on item tooltips`

## Deviations from Plan
None of substance. Harness line records use `text` / `r` / `g` / `b` fields (the stub's shape), so the checks read those.

## Known Stubs
None.

## In-game checks (deferred to milestone end)
1. `/dump C_TooltipInfo.GetInventoryItem("player", 16).lines`: does Forever already send a type-31 line (then ours stays off by design)? Is `ItemName` the first line?
2. Hover gear in bags, character sheet, Inspect window, a chat link, loot, a merchant, the auction house, with comparison tooltips: gold "Item Level N" right under the name, before "Soulbound", exactly once, also after holding still a few seconds.
3. Bags, arrows, shirts, tabards, potions: no line.
4. Hover gear in combat: no Lua error.
5. `/run TerribleGroupFinderDB.ilvlItemTooltip=false`, hover gear: no line.

## Self-Check: PASSED
ItemLevelUI.lua and CLAUDE.md modified, commit 7a6cf26 exists, harness 0 failed in all three modes.
