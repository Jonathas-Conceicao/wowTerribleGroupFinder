# Phase 7: Item Level Spots - Context

**Gathered:** 2026-11-14
**Status:** Ready for planning
**Mode:** Smart discuss, recommended answers auto-accepted (author: never pause autonomous runs; decisions listed for review at the end)

<domain>
## Phase Boundary

Item level, from the game's own figures, in four spots: friendly player unit tooltips (prototype exists in `ItemLevel.lua`), item tooltips (gold "Item Level N" right under the item name, retail look), the character sheet's General stats (a row under Movement Speed), and the Inspect window (text at its top right). Plus the guard that keeps the addon's quiet inspects from disturbing the player's own Inspect window or showing another player's value. Each spot reads its `ns.Settings` key (`ilvlPlayerTooltip`, `ilvlItemTooltip`, `ilvlCharacterSheet`, `ilvlInspect`) where it acts; the settings page itself is Phase 10.

</domain>

<decisions>
## Implementation Decisions

### How item level looks in each spot
- Inspect window: "Item Level 48" in gold (`STAT_AVERAGE_ITEM_LEVEL` / `ITEM_LEVEL`-style label read from the game's globals at runtime, plain fallback), small font (`GameFontNormalSmall`), at the top right of the gear panel; the game's own whole number (`C_PaperDollInfo.GetInspectItemLevel`); empty until known, never "?"
- Character sheet: Blizzard's own `ITEMLEVEL` stat (`PAPERDOLL_STATINFO.ITEMLEVEL`, `PaperDollFrame_SetItemLevel`): its label, value format and tooltip, placed directly under Movement Speed in the player's General category (native look; not our own row)
- Player tooltip: keep the prototype: gold "Item Level N" on friendly players, yourself included; enemies / attackable never looked up or shown
- Your own figure everywhere (tooltip, Inspect on yourself): equipped value rounded down, as the character sheet

### Item tooltips and the probe
- Item tooltips: every equippable item with an item level above 1 (weapons, armor, shields, relics / librams / totems / idols, held-in-off-hand, rings, trinkets, necks, cloaks); not bags, not ammo, not shirts / tabards (level 1); the line is gold "Item Level N" (`ITEM_LEVEL` format) directly under the name, exactly once, on every tooltip type (bags, character sheet, Inspect, chat links / `ItemRefTooltip`, loot, merchant, auction house, comparison)
- `/tgf ilvl` probe stays as a diagnostic command (it helps support item level questions); no other debug output

### From research (research/SUMMARY.md: locked technical choices)
- Character sheet row: Option A (hook `CharacterStatsPaneScrollBox.UpdateStats`, insert the `ITEMLEVEL` element after `MOVESPEED` in `elementData`, re-set the data provider); Option B (write `PAPERDOLL_STATCATEGORIES` once) only if Option A taints; record it in PROJECT.md Key Decisions as a narrow exception
- Item tooltip: `TooltipDataProcessor.AddLinePostCall(Enum.TooltipDataLineType.ItemName, ...)` + `tooltip:AddLine`; skip when a stock `ItemLevel` (type 31) line exists; `C_Item.GetDetailedItemLevelInfo`; guard secret values; never a whole-tooltip post-call
- Inspect: `EventUtil.ContinueOnAddOnLoaded("Blizzard_InspectUI", ...)`; FontString on `InspectPaperDollFrame`; refresh from `hooksecurefunc` on `UpdateButtons` / `SetLevel`
- Quiet inspect guard: busy while `InspectFrame.unit ~= nil` or within ~2 s of any `NotifyInspect` / `InspectUnit` not ours; GUID match at `INSPECT_READY` and at read time; never `ClearInspectPlayer()` when a later inspect started
- Split: `ItemLevel.lua` keeps data + inspect queue (+ `OnLearned` observer); new `ItemLevelUI.lua` holds the four spots as independent, pcall-guarded installers; hooks installed unconditionally, gated inside by `ns.Settings.Get`

### Claude's Discretion
- Exact anchor offsets of the Inspect text (to be tuned in game; avoid `InspectLevelText`)
- How the sheet row and the Inspect text redraw when their setting changes (`ns.Settings.OnChange`)
- Harness stubs needed for the new hooks

</decisions>

<code_context>
## Existing Code Insights

### Reusable Assets
- `ItemLevel.lua`: `Read`, `Average`, `Of(unit)`, `Remember`, inspect queue (`INSPECT_GAP` 1.5 s, `INSPECT_WAIT` 4 s, retries), `FindUnit`, `RequestInspect`, `RefreshTooltip`, `OnTooltipUnit`, `Probe`
- `Settings.lua`: `ns.Settings.Get/OnChange` with the four `ilvl*` keys already registered (default on)

### Established Patterns
- Tooltip post-calls via `TooltipDataProcessor`; insecure callbacks; never write Blizzard frame fields (sheet row is the documented exception)
- Smoke harness outside the repo (scratchpad `smoke/`): stubs in `harness.lua` head, tests in `tail.lua`, `node splice.js`, `node run.js <repo> [""|--fallback|--attach]`

### Integration Points
- `Core.lua` `ns:ADDON_LOADED` → `ns.ILvl.Init()`; TOC load list (add `ItemLevelUI.lua` after `ItemLevel.lua`)

</code_context>

<specifics>
## Specific Ideas

- Retail look for item tooltips: gold "Item Level N" right under the item name, before "Soulbound"
- Author's words: "on inspect I want to add a raw text on top right with the player ilvl"; "one line to the Character stats first panel, general section below movement speed, equipped ilvl"

</specifics>

<deferred>
## Deferred Ideas

- Per-slot item levels, colour-coded item level, sorting by item level (out of scope for v0.2)

</deferred>
