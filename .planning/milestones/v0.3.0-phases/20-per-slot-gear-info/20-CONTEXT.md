# Phase 20: Per-slot Gear Info - Context

**Gathered:** 2026-11-24
**Status:** Ready for planning
**Mode:** Autonomous smart discuss: the recommended answers were taken, building on the author's
kickoff answers in `.planning/research/v0.3.0/KICKOFF-DECISIONS.md` (locked)

<domain>
## Phase Boundary

Each equipped slot on the character sheet and the Inspect window shows, beside its icon, the
item's level and its enchant ("No enchant" in red on a slot Forever lets you enchant). Two keys from
Phase 18: `slotItemLevel`, `slotEnchants` (both off by default), each covering both windows.
Sockets are out of scope. Requirements: GEAR-01..04.

</domain>

<decisions>
## Implementation Decisions

### Layout (author's choice: both beside the icon)
- One overlay frame of ours per slot button (weak-keyed table `overlays[button]`, never a field on
  the button), `EnableMouse(false)` so Blizzard's tooltip / clicks keep working; nothing drawn on
  the icon itself
- Two small lines beside the icon, toward the model: line 1 the item level, line 2 the enchant.
  Left column (`PaperDollItemSlotButtonLeftTemplate`): text left-aligned right of the icon; right
  column: right-aligned left of the icon; weapon row (`...BottomTemplate`): main hand's text left of
  its icon, off hand / ranged above (or the side with room: the planner checks the Camelot
  geometry in `PaperDollFrame.xml:779-875` and `InspectPaperDollFrame.xml:205-312`)
- When only one option is on, its line takes the first line's spot (no blank line)
- Fonts: a small game font (`GameFontHighlightSmall` / `NumberFontNormalSmall`-sized); the item level
  coloured by item quality (`C_Item.GetItemQualityColor` / `ITEM_QUALITY_COLORS`); the enchant in
  green (`GREEN_FONT_COLOR`), "No enchant" in red (`RED_FONT_COLOR`); the enchant text width-bound
  and cut to fit (`SetWidth` + `SetWordWrap(false)`), the full text in no new tooltip (the item's own
  tooltip already shows it)
- Slots: 1-19 except shirt (4), tabard (19); ammo / relic slots as Forever's sheet has them

### Data
- New file `GearSlots.lua` (`ns.GearSlots`), loaded after `ItemLevelUI.lua`; its installers go
  through `ns.ILvlUI.Install` (failures listed by `/tgf ilvl`) or an equivalent of its own
- `Read(unit, slot)`: link from `GetInventoryItemLink(unit, slot)` (secret guarded with the existing
  helpers), level from `C_Item.GetDetailedItemLevelInfo(link)` (same source as `ILvl.Read`, so slot
  values and the overall figure agree); enchant text from `C_TooltipInfo.GetInventoryItem(unit,
  slot)` line with `type == Enum.TooltipDataLineType.ItemEnchantmentPermanent` (15), its
  `leftText` with a leading "Enchanted: " (`ENCHANTED_TOOLTIP_LINE` pattern) stripped; whether an
  enchant exists at all from the item string's 2nd field (`item:<id>:<enchantID>`), so a missing
  tooltip line with an enchant ID shows a generic "Enchanted" rather than "No enchant"
- Enchantable slots (no API: a static table): head, shoulder, back, chest, wrist, hands, legs, feet,
  main hand, off hand (weapons, shields and held-in-off-hand items: Forever's new off-hand
  enchants), **neck (Forever)**, ranged only for bows / guns / crossbows (scopes; from
  `C_Item.GetItemInfoInstant` class / subclass). Not: belt, rings, trinkets, shirt, tabard, wands,
  thrown, relics. Sources: research FEATURES.md (Blizzard Watch / Warcraft Tavern: Forever adds neck
  and off-hand). Rings stay out (one LOW source); flagged for the author's in-game check
- "No enchant" at every level (author), only when the slot is enchantable, has an item, the item
  data has resolved and the enchant field is 0 / empty

### Updates
- Character sheet: `hooksecurefunc("PaperDollItemSlotButton_Update", fn)` (unit "player")
- Inspect: `hooksecurefunc("InspectPaperDollItemSlotButton_Update", fn)` after
  `EventUtil.ContinueOnAddOnLoaded("Blizzard_InspectUI", ...)` (as ItemLevelUI.lua does), unit
  `InspectFrame.unit`, values only while that unit's GUID is the one the window shows
- Item data not loaded yet: the slot shows nothing (and never "No enchant") until it resolves; the
  existing retry shape (1 s apart, 3 tries, token-cancelled, ItemLevelUI.lua:257-308) or
  `Item:ContinueOnItemLoad`, not a new queue
- No `NotifyInspect` / `ClearInspectPlayer`, no use of the quiet inspect queue, no per-slot cache
- `OnChange` for both keys redraws every existing overlay (off clears it at once)
- Overlays hide with Inspect's `OnHide`; switching inspected players never shows the previous
  player's values (cleared before the new read)

### Debug
- `/tgf gear`: prints each equipped slot of yours (and the inspected unit when the Inspect window is
  open): item level, the enchant ID from the link, the enchant tooltip line, `GetItemNumSockets`,
  and whether we count the slot as enchantable — a tool shipped alongside, not a gate

### Claude's Discretion
- Exact offsets and widths per column, font choice, whether "No enchant" uses `RED_FONT_COLOR` or a
  dimmer red
- Sharing `SLOT_NAMES` from ItemLevel.lua (export) or a local subset

</decisions>

<code_context>
## Existing Code Insights

### Reusable Assets
- `ns.ILvl.Read` / helpers (ItemLevel.lua:333-366): link + `GetDetailedItemLevelInfo`, secret guards
- `ns.ILvlUI.Install` (ItemLevelUI.lua:56-72), the retry shape (257-308), the Inspect UI load
  pattern (315-352), the item tooltip's tooltip-data line reading (595-632)
- `ns.Settings.Get` / `OnChange`

### Established Patterns
- Character sheet: our own frames only, anchors only, never Blizzard's stats data (CLAUDE.md
  taint history)
- Independent pcall-guarded installers; settings read where acting

### Integration Points
- `PaperDollItemSlotButton_Update` (Blizzard_UIPanels_Game/Camelot/PaperDollFrame.lua:2177),
  slot buttons `Character*Slot` (PaperDollFrame.xml:779-875)
- `InspectPaperDollItemSlotButton_Update` (Blizzard_InspectUI/Mainline/InspectPaperDollFrame.lua:245),
  `Inspect*Slot` (Camelot/InspectPaperDollFrame.xml:205-312), `InspectFrame.unit`
- Research: `.planning/research/v0.3.0/ARCHITECTURE.md` Feature 3, `PITFALLS.md` 9-14

</code_context>

<specifics>
## Specific Ideas

- The author's chosen layout:

```
[Head]  62
        +8 Stamina
[Neck]  60
        No enchant
```

</specifics>

<deferred>
## Deferred Ideas

- Sockets / gems (dropped: none on Forever)
- A level floor for "No enchant" (the author chose every level)

</deferred>
