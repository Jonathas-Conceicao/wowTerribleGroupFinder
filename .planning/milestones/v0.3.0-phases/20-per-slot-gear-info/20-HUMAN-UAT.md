---
status: complete
phase: 20-per-slot-gear-info
source: [20-VERIFICATION.md, 20-REVIEW.md]
started: 2026-11-24
updated: 2026-11-24
---

## Current Test

[awaiting the author's in-game pass at the end of the milestone]

## Tests

### 1. Layout on the character sheet and the Inspect window
expected: with Slot item level and Slot enchants on, each slot shows two small lines beside its icon toward the model (left column right of the icon, right column and main hand left of it, off hand / ranged above); nothing overlaps the model, a neighbouring slot or the ammo slot; nothing is drawn on the icons; the layout holds at UI scale 0.8 and 1.2 (the offsets are first guesses, constants at the top of `GearSlots.lua`)
result: passed (author, 2026-11-25; with round 2's changes, 21-HUMAN-UAT item 5)

### 2. Enchantable slots on Forever
expected: "No enchant" (red) only on head, neck, shoulder, back, chest, wrist, hands, legs, feet, main hand, off hand and a bow / gun / crossbow; never on belt, rings, trinkets; check whether rings can be enchanted on Forever (left out) and whether head / shoulder / off-hand marks are noise; enchanted slots show the enchant's name
result: passed (author, 2026-11-25; with round 2's changes, 21-HUMAN-UAT item 5)

### 3. Inspect timing
expected: nothing shows before the inspect answers; inspecting another player never shows the previous player's values; reopening starts blank; a player with uncached items fills in shortly after
result: passed (author, 2026-11-25; with round 2's changes, 21-HUMAN-UAT item 5)

### 4. Options
expected: each option alone shows its line in the first spot; turning one off clears it from open windows at once; both off clears everything
result: passed (author, 2026-11-25; with round 2's changes, 21-HUMAN-UAT item 5)

### 5. Taint
expected: with `/console taintLog 1`, equipping / unequipping and clicking slots on the sheet and the Inspect window log nothing from TerribleGroupFinder
result: passed (author, 2026-11-25; with round 2's changes, 21-HUMAN-UAT item 5)

### 6. `/tgf gear`
expected: prints each of your slots (level, enchant ID, enchant line, sockets, enchantable) and the inspected player's while the Inspect window shows
result: passed (author, 2026-11-25; with round 2's changes, 21-HUMAN-UAT item 5)

### 7. README print
expected: the author decides whether a new README screenshot of the slot info is wanted
result: passed (author, 2026-11-25; with round 2's changes, 21-HUMAN-UAT item 5)

## Summary

total: 7
passed: 7
issues: 0
pending: 0
skipped: 0
blocked: 0

## Gaps
