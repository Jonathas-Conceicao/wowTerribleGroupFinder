---
phase: 20-per-slot-gear-info
verified: 2026-11-24T00:00:00Z
status: passed # in-game checks passed by the author, 2026-11-25, with round 2's changes (21-HUMAN-UAT.md item 5)
score: 10/10 must-haves verified in code
overrides_applied: 0
gaps: []
human_verification:
  - test: "Enable Slot item level and Slot enchants (Settings > Player inspection) and open the character sheet"
    expected: "Each slot (not the shirt or tabard) shows its item level, quality-coloured, and its enchant in green, in two lines beside the icon toward the model. Left column text is right of the icon, right column and main hand text is left of it, and off hand and ranged text is above."
    why_human: "Layout geometry (offsets, widths 80/60/42) are first guesses never rendered; text may overlap the model, the neighbouring slots or the ammo slot."
  - test: "On an unenchanted neck, off hand, head, chest and so on, read the second line. Then check a ring, belt, trinket and wand or relic."
    expected: "Enchantable slots show red 'No enchant' (including at low level). Rings, belt, trinkets, wand, thrown and relic never show it. An enchanted slot shows the enchant name cut to fit, with no overlap."
    why_human: "The enchantable table is static. Forever's real enchantable slots, and whether rings are enchantable, can only be confirmed in game. The enchant tooltip line type 15 must be present on Forever."
  - test: "Inspect a player, then switch to another player. Do this quickly and with a slow answer."
    expected: "Nothing shows until that player's inspect answered. 'No enchant' never flashes while data is loading. The previous player's values never show on the new one. Closing and reopening the window starts blank."
    why_human: "Depends on the live inspect / INSPECT_READY timing and the item data loading."
  - test: "Toggle each of the two options off and on with the sheet and the Inspect window open, and with only one option on."
    expected: "Off clears both windows at once. With one option on, its line sits on the first line's spot, with no blank line above it."
    why_human: "Runtime UI behaviour."
  - test: "Equip, right-click and shift-click slots on the sheet and Inspect window with /console taintLog 1. Try UI scale 0.8 and 1.2."
    expected: "No taint or ADDON_ACTION_BLOCKED error, tooltips and clicks still work (overlays are mouse-disabled), the layout holds at both scales."
    why_human: "Taint and scale behaviour cannot be checked without the client."
  - test: "Run /tgf gear on yourself and with the Inspect window open on a player"
    expected: "Prints each slot's level, enchant ID, enchant line, sockets and enchantable. Prints the 'inspect answered' flag for the other player. Lists no failed slots* installers."
    why_human: "Needs live APIs (C_TooltipInfo, GetItemNumSockets)."
---

# Phase 20: Per-slot Gear Info Verification Report

**Phase Goal:** The character sheet and the Inspect window show each slot's item level and enchant at a glance
**Verified:** 2026-11-24
**Status:** human_needed (all code-level checks pass; only in-game checks remain)
**Re-verification:** No, initial verification

## Goal Achievement

### Observable Truths

| # | Truth | Status | Evidence |
|---|-------|--------|----------|
| 1 | GEAR-01: slot item level from `C_Item.GetDetailedItemLevelInfo(link)` (same source as ILvl.Read), shown per slot on both windows, gated by `slotItemLevel` | VERIFIED | GearSlots.lua:168 (Read); Lines() at 399-402 uses quality colour, `math.floor`; hooks at 579 (sheet) and 596 (Inspect) |
| 2 | GEAR-02: enchant name in green from the `ItemEnchantmentPermanent` line with the prefix stripped; "Enchanted" when only an ID exists; red "No enchant" when enchantable and empty, at every level | VERIFIED | EnchantText 125-149; Lines 403-411; no level floor anywhere |
| 3 | GEAR-02: enchantable slots are head, neck, shoulder, back, chest, wrist, hands, legs, feet, main hand, any off-hand item, and ranged only for bows, guns and crossbows (rings, belt, trinkets, wands, relics excluded) | VERIFIED in code (table matches the locked decision) | ENCHANTABLE 55-67 holds slots 1,2,3,5,7,8,9,10,15,16,17 only; the ranged slot is by subclass (2, 3, 18) at 70-90. The real Forever set is an in-game check. |
| 4 | GEAR-03: a pending or secret slot shows nothing and never "No enchant"; an empty slot shows nothing | VERIFIED | Read states 158-173; Draw blanks "pending", "secret" and "empty" (519-526); "No enchant" is only built in Lines, which is only called for "known" |
| 5 | GEAR-03: on Inspect, nothing shows until `ILvl.InspectReadyFor(unit)`; a GUID change clears before the new read; OnHide clears; retries re-check the GUID | VERIFIED | Draw 500-517; InspectReadyFor in ItemLevel.lua:997-1012 (you, or readyGUID and serial match); OnHide at 599-603; Schedule 453-475 |
| 6 | Layout locked: two lines beside the icon toward the model, nothing on the icon; a single line takes the first spot | VERIFIED in code | Overlay 320-358 (left: text right of icon; right and main: text left of it; above for off hand and ranged); Show 424-437 puts a single entry in `a` |
| 7 | GEAR-04: own frames only (child of the button, weak-keyed tables, `EnableMouse(false)`), hooks via `hooksecurefunc` and `HookScript`, no fields written on Blizzard buttons, no inspect calls | VERIFIED | `overlays`/`kindOf` weak-keyed (303-304); `o.a`/`o.b` are on our frame; no `NotifyInspect`, `ClearInspectPlayer` or `RequestInspect` in the file's code; no Blizzard function reassigned. The `o.a, o.b` fields are on our frame, not the button. |
| 8 | GEAR-04: turning either option off redraws existing overlays at once | VERIFIED | GS.Init 626-627 `OnChange` to RedrawAll; Draw blanks when both are off (490-493) |
| 9 | Wiring: GearSlots.lua is in the TOC after ItemLevelUI.lua; Init is called from Core; `/tgf gear` is wired; installers go through `ILvlUI.Install` with a PLAYER_LOGIN retry | VERIFIED | TOC grep; Core.lua:325, 333, 360-361; Init 625-637; Install returns false on a missing function, so the retry fires |
| 10 | Docs and hygiene: CLAUDE.md updated, `stylua --check .` clean, CHANGELOG.md and README.md untouched, no TBD/FIXME/XXX | VERIFIED | CLAUDE.md line 29 and the other edits present; `stylua --check .` OK; `git diff --stat` for CHANGELOG/README is empty; marker grep is empty |

**Score:** 10/10 verified in code. The visual layout and the Forever-specific facts are routed to human verification.

### Requirements Coverage

| Requirement | Source Plan | Status | Evidence |
|-------------|-------------|--------|----------|
| GEAR-01 | 20-01, 20-02 | SATISFIED in code (in-game visual check pending) | truth 1 |
| GEAR-02 | 20-01, 20-02 | SATISFIED in code (the enchantable set is checked in game) | truths 2, 3 |
| GEAR-03 | 20-01, 20-02 | SATISFIED in code | truths 4, 5 |
| GEAR-04 | 20-02 | SATISFIED in code (taint is checked in game) | truths 7, 8 |

All four IDs in REQUIREMENTS.md (lines 52-66, traceability 102-105) are claimed by the plans. There are no orphaned requirements. The traceability table still reads "Pending", which is a doc status for the orchestrator to update.

### Locked decisions (20-CONTEXT.md and KICKOFF-DECISIONS.md)

- Both lines beside the icon toward the model, nothing on the icon: honoured.
- "No enchant" in red at every level: honoured, with no level gate.
- Neck and off hand are enchantable: honoured (slots 2 and 17).
- Sockets absent: honoured. Sockets appear only in the `/tgf gear` probe, as the debug decision specifies.
- Both keys default off in Settings.lua (lines 186-199).

### Anti-Patterns Found

None blocking. The layout constants are labelled "first guesses, tuned in game". `GS.Read` does not cache and does not inspect.

### Gaps Summary

No code gaps. The phase is code-complete. The remaining items are the in-game checks listed in the frontmatter: real geometry and overlap, the Forever enchantable set (rings), inspect timing, taint, and UI scale.

---

_Verified: 2026-11-24_
_Verifier: Claude (gsd-verifier)_
