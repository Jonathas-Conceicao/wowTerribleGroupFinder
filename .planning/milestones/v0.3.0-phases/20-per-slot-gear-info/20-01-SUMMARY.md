---
phase: 20-per-slot-gear-info
plan: 01
subsystem: gear-data
tags: [lua, item-level, enchant, debug]
requires: []
provides:
  - ns.GearSlots (Read, Enchantable, Probe, SHOWN, SHOW)
  - ILvl.SLOT_NAMES, ILvl.InspectReadyFor
  - /tgf gear
affects: [20-02]
key-files:
  created: [GearSlots.lua]
  modified: [ItemLevel.lua, Core.lua, TerribleGroupFinder.toc]
decisions:
  - SLOT_NAMES exported from ItemLevel.lua rather than copied
metrics:
  tasks: 2
  files: 4
completed: 2026-11-24
---

# Phase 20 Plan 01: Per-slot gear data Summary

GearSlots.Read gives one slot's state (empty / pending / secret / known) with level, quality, enchant ID, enchant text and Forever's enchantable flag; `/tgf gear` prints it.

## Tasks

1. Data module, ILvl exports, TOC line: 09b781a
2. `/tgf gear` Probe and Core.lua wiring: 526488b

## Deviations from Plan

None in behavior. Python was unavailable, so Core.lua was edited with the Edit tool (as the plan intended anyway). stylua converted new files to CRLF.

## In-game checks (deferred to the milestone's end)

- `/tgf gear` on an enchanted character: levels match the character sheet, enchant IDs and lines show, enchantable flags are right (head, neck, shoulder, back, chest, wrist, hands, legs, feet, main hand, off hand; ranged only for bow/gun/crossbow). Rings are not counted enchantable (one low source): confirm.
- `/tgf gear` with the Inspect window open on another player: "inspect answered" is yes and their slots print; pending slots read "pending", never "no enchant".
- The prefix pattern from `ENCHANTED_TOOLTIP_LINE` strips "Enchanted: " from the line.

## Known Stubs

None.

## Self-Check: PASSED

GearSlots.lua exists; commits 09b781a and 526488b exist; `stylua --check .` passes; no NotifyInspect / ClearInspectPlayer outside comments in GearSlots.lua.
