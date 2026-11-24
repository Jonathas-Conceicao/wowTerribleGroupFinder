---
phase: 20-per-slot-gear-info
plan: 02
subsystem: gear-display
tags: [lua, overlays, character-sheet, inspect]
requires: [20-01]
provides:
  - per-slot item level / enchant overlays on the character sheet and Inspect window
  - ns.GearSlots.Init
affects: []
key-files:
  modified: [GearSlots.lua, Core.lua, CLAUDE.md]
decisions:
  - display half appended after the /tgf gear probe in GearSlots.lua (the probe uses nothing of it)
metrics:
  tasks: 3
  files: 3
completed: 2026-11-24
---

# Phase 20 Plan 02: Per-slot gear display Summary

One overlay frame of ours per slot button, drawn from post-hooks on `PaperDollItemSlotButton_Update` and `InspectPaperDollItemSlotButton_Update`: item level in quality colour and enchant (green text, "Enchanted", or red "No enchant"), gated by `slotItemLevel` / `slotEnchants`, with a 1 s x3 retry for late item data and an Inspect gate on `ILvl.InspectReadyFor`.

## Tasks

1. Overlays, Draw, retry, installers, `GS.Init`, and the Core.lua call (plan tasks 1 and 2, one commit because the display half and its installers are one block): 119254a
2. CLAUDE.md (GearSlots line, taint exception, ItemLevel exports, `gear` subcommand, Settings wording): 62efe30

## Deviations from Plan

- Tasks 1 and 2 committed together (119254a); no behavior difference.
- The `Settings.lua` line in CLAUDE.md keeps the `eliteQuestButton` wording for Phase 19.
- The INSPECT_READY frame, `Rgb` and `SetLine` helpers were added as small supporting locals.

Acceptance greps: weak-keyed tables 2, no `button.<field> =` writes, no inspect calls outside comments, `stylua --check .` passes, CHANGELOG.md / README.md untouched. Every local function is defined above its first caller (`RedrawKind` is forward-declared; `WindowGuid` precedes `Schedule`).

## In-game checks (not done; no game access)

- With Slot item level / Slot enchants on, the sheet and an Inspect window show levels and enchants in the chosen layout; tune GAP / widths (UI scale 0.8 / 1.2).
- Unenchanted neck or off hand shows red "No enchant"; a ring never does.
- Switching inspected targets never flashes the previous player's values; closing Inspect clears.
- Turning each option off clears both windows at once.
- Equipping, right-click and shift-click on slots work with no taint error (`/console taintLog 1`).
- Ranged slot text above the icon does not collide with the ammo slot; off hand / ranged text does not overlap neighbours.
- README may want a new screenshot of the sheet with slot info (the author retakes it).

## Known Stubs

None.

## Self-Check: PASSED

GearSlots.lua, Core.lua, CLAUDE.md changes exist; commits 119254a and 62efe30 exist.
