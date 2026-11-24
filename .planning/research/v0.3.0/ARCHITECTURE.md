# Architecture Research: v0.3.0 (Elite quest eye, per-slot gear info, opt-in defaults)

**Domain:** WoW Forever addon (interface 16001, game type `camelot`), integration of three features into the existing module layout
**Researched:** 2026-11-24
**Confidence:** MEDIUM overall. Hook points and the taint boundary are HIGH (read from the `forever` branch source). What the Forever *client* does at runtime for the quest APIs, and whether inspect item links carry enchant/gem data, is LOW until probed in game (flagged per item below).

Paths: `TGF` = `C:\Users\jonat\Repositories\TerribleGroupFinder`, `BLZ` = `C:\Users\jonat\Repositories\wow-ui-source\Interface\AddOns` (branch `forever`, read-only).

## Standard Architecture

### System overview (v0.3.0 additions marked NEW / MOD)

```
 Core.lua (MOD)  ns.Migrate schema 4, DEFAULTS.schema 4, Init calls, /tgf quest|gear
      |
 Settings.lua (MOD)  registry: reorder sections, flip defaults, 4 new keys
      |                         |
      |                  UI/SettingsPanel.lua (no change expected; reads List())
      |
 +----+-----------------------------+---------------------------------+
 |                                  |                                 |
 QuestButton.lua (NEW)      GearSlots.lua (NEW)             ItemLevel.lua / ItemLevelUI.lua
 tracker hook + eye         per-slot overlays               (existing; reused, only MOD of
 click flow                 sheet + Inspect                  exports if needed)
      |                          |
      | click                    | reads unit links (player / InspectFrame.unit)
      v                          v
 UI/InPlace.lua (MOD:       Blizzard: PaperDollItemSlotButton_Update /
 IP.ShowFinder)             InspectPaperDollItemSlotButton_Update (post-hooks)
      |
      v
 Blizzard_GroupFinder_VanillaStyle (untouched; only the game's own functions/events run in it)
```

### Component responsibilities

| Component | Responsibility | Status |
|-----------|----------------|--------|
| `QuestButton.lua` (`ns.QuestButton`) | Post-hook the quest tracker module's `EndLayout`; for each used block whose quest is elite, show our own eye button (one per block, pooled by Blizzard's block pool); on click decide the route and call `ns.InPlace.ShowFinder`; `/tgf quest` probe | NEW |
| `GearSlots.lua` (`ns.GearSlots`) | Per-slot data read (`Read(unit, slot)`: item level, enchant text / missing, sockets+gems) and the overlays on character sheet and Inspect slot buttons; installs through `ns.ILvlUI.Install` so failures list in the existing probe; `/tgf gear` probe | NEW |
| `UI/InPlace.lua` | Gains `IP.ShowFinder(tab)`: the "show the finder" block now inlined in `IP.OpenMessages` (lines 448-454) extracted and shared; `OpenMessages` calls it | MOD (small) |
| `Settings.lua` | Section order Group finder, Player inspection, Damage meter; 6 defaults flip to off; new keys | MOD |
| `Core.lua` | `Migrate` schema 4; `DEFAULTS.schema = 4`; two new `Init()` calls; USAGE string, two probe commands | MOD |
| `TerribleGroupFinder.toc` | Two new Lua files in the load list (the shipped file set; install/package scripts derive from it) | MOD |
| `ItemLevel.lua` / `ItemLevelUI.lua` | Reused as-is: `ILvl.Yes`, `ILvlUI.Install`, `UI.Gold`, `UI.failed`; the quiet inspect queue is NOT used by the slot overlays | unchanged (at most export a helper) |
| `UI/SettingsPanel.lua` | Builds from `ns.Settings.List()`; section headers come from `opt.section` changes (lines 36-40); the Move button (68-79) assumes Damage meter is the last option section, still true | unchanged |

## Recommended Project Structure (delta only)

```
TerribleGroupFinder/
  Core.lua                 MOD  (Migrate 4, Init calls, /tgf quest, /tgf gear)
  Settings.lua             MOD  (sections, defaults, 4 keys)
  QuestButton.lua          NEW  (after MeterReset.lua in the TOC)
  GearSlots.lua            NEW  (after ItemLevelUI.lua in the TOC)
  UI/InPlace.lua           MOD  (IP.ShowFinder)
  TerribleGroupFinder.toc  MOD
  CLAUDE.md                MOD  (Architecture entries for the two modules; Settings line)
```

No new XML: the eye is created from Blizzard's own `QuestObjectiveFindGroupButtonTemplate` (see below), so `UI/Templates.xml` stays "two plain virtual Buttons, no `file=`".

## Feature 1: Opt-in defaults and settings sections

### Integration points

- `TGF/Core.lua:25-27` `DEFAULTS = { schema = 3 }` -> 4. `TGF/Core.lua:37-47` `ns.Migrate`: add a `< 4` block after the `< 3` block (a player on schema 2 must pass through both).
- `TGF/Core.lua:280-295` order is `Migrate` -> DEFAULTS fill -> `Settings.Init`. Migrate runs **before** `Settings.Init`, and `ns.Settings.Get` returns the *new* (off) default there, so Migrate must not ask the registry for "the current effective value". It must carry a **frozen list of the v0.2.2 defaults** (`ilvlPlayerTooltip`, `specPoints`, `ilvlItemTooltip`, `ilvlCharacterSheet`, `ilvlInspect`, `meterResetOnInstance`, all were on) and, `if existing and type(db[key]) ~= "boolean" then db[key] = true`. `existing` is already computed at the top of Migrate (`next(db) ~= nil`, line 38) before DEFAULTS are filled; every returning v0.2.x player has at least `schema`, so they count as existing; a fresh install is `{}` and gets the new defaults. `meterResetOnGroup` already handled by schema 3 (its default was already off); `dynamicRefresh`, `swipeAnimations`, `regionFlags` keep default on, nothing to save.
- `TGF/Settings.lua:122-185` `OPTIONS` order is the page order (SettingsPanel iterates `List()` and opens a header whenever `opt.section` changes, `TGF/UI/SettingsPanel.lua:36-40`). Reorder: Group finder (`eliteQuestButton` NEW default on, `dynamicRefresh`, `swipeAnimations` child, `regionFlags`), then Player inspection (rename from "Item level and talents"; the five existing keys with `default = false`, then the new per-slot keys with `default = false`), then Damage meter (`meterResetOnGroup`, `meterResetOnInstance` now `default = false`). The loop at 186-191 only defaults to `true` when `default == nil`, so each flipped option gets an explicit `default = false`. Messages stays the panel's own trailing header + button (SettingsPanel.lua:80-83). Update the header comment of Settings.lua and the CLAUDE.md "Settings.lua" line (which says "default on except `meterResetOnGroup`").
- New keys (flat booleans, no reserved-key clash with `RESERVED`, Settings.lua:20): `eliteQuestButton` (default on), and for gear info **three keys by detail, applying to both windows**: `slotItemLevel`, `slotEnchants`, `slotSockets` (default off). Reasoning: the milestone brief lists the section as "item level, talents, enchants, sockets", which maps one checkbox per detail; a sheet/inspect split would multiply keys to six and no requirement asks for it. The existing `ilvlCharacterSheet` and `ilvlInspect` stay as the overall-row toggles (different meaning, keep labels distinct: "Item level row on the character sheet" vs "Item level on each slot").
- The panel's Defaults button writes defaults (`SettingsPanel` comment "accepted"): with the flip it now turns the extras off. Intended.

### Data flow

`Core ADDON_LOADED` -> `Migrate(db)` (frozen-list save) -> `Settings.Init(db)` -> modules `Init()` -> features call `ns.Settings.Get(key)` where they act (never cached; existing rule) and `ns.Settings.OnChange(key, fn)` to redraw.

Side effect to verify, not change: with the five item-level keys off by default, `ILvl.RequestInspect` (the quiet queue) is only called from the player-tooltip path (`ItemLevelUI.lua:123-160`), so a new install never inspects anybody. That is the "doesn't clash with similar addons" goal and needs no extra code.

## Feature 2: Elite quest eye button in the objective tracker

### What Forever's tracker already does (verified in source)

- Quest tracker module is the frame `QuestObjectiveTracker` (`BLZ/Blizzard_ObjectiveTracker/Blizzard_QuestObjectiveTracker.xml:26`), blocks are `ObjectiveTrackerQuestPOIBlockTemplate`, one per watched quest, `block.id == questID` (`Blizzard_ObjectiveTrackerModule.lua:254-282`, `GetBlock` sets `block.id`).
- `QuestObjectiveTrackerMixin:UpdateSingle` (`Blizzard_QuestObjectiveTracker.lua:291`) calls `block:AddRightEdgeFrame(self.findGroupButtonSettings, questID)` only when `QuestUtil.CanCreateQuestGroup(questID)` (lines 308-310, defined `BLZ/Blizzard_FrameXMLUtil/Mainline/QuestUtils.lua:375`, cached `C_LFGList.CanCreateQuestGroup`). The template is `QuestObjectiveFindGroupButtonTemplate` (`Blizzard_ObjectiveTrackerShared.xml:65-88`: 30x30, `UI-SquareButton-*` textures, `socialqueuing-icon-eye` 13x13 icon) with mixin at `Blizzard_ObjectiveTrackerShared.lua:180-210`, whose `OnClick` calls `LFGListUtil_FindQuestGroup`.
- On Forever that function **does not exist**: `Blizzard_GroupFinder` (retail finder, where it lives at `Mainline/LFGList.lua:4594`) has `## ExcludeLoadGameType: camelot` in its TOC. So Blizzard's own button would error on click if `CanCreateQuestGroup` were ever true. Presumably the client returns false for it on Forever (that is the gap the feature fills), **LOW confidence, probe it**.
- Elite is knowable: `C_QuestLog.IsEliteQuest(questID)` is used by Forever's own title code (`BLZ/Blizzard_FrameXMLUtil/Camelot/QuestUtilsOverrides.lua:7`, and the "(Elite)" tag at lines 16-20); documented `QuestLogDocumentation.lua:749`.

### Hook: which function, and why not the others

**Recommended: `hooksecurefunc(QuestObjectiveTracker, "EndLayout", fn)`** (instance hook, post-call).

- `EndLayout` (`Blizzard_ObjectiveTrackerModule.lua:201-217`) runs at the end of every `Update` that lays out (`Update` calls it at line 164), after `FreeUnusedBlocks()` (so `usedBlocks` holds exactly the blocks on screen), after every block is anchored and headered. One hook, one pass over the visible blocks, no per-quest bookkeeping.
- Do **not** hook `UpdateSingle`: it is passed by value (`self:EnumQuestWatchData(self.UpdateSingle)`, line 412) and runs mid-layout before `SetHeader`; a hook there cannot see the final header and runs once per quest per update.
- Do **not** call `block:AddRightEdgeFrame(...)` with our own settings. It would reserve header room properly (`SetHeader` anchors `HeaderText` RIGHT at `rightEdgeOffset`, `Blizzard_ObjectiveTrackerBlock.lua:155-159`), but it runs Blizzard's code from our (tainted) call and writes `block.rightEdgeFrame`, `block.rightEdgeOffset`, `block.addedRegions`, `module.usedRightEdgeFrames` and the manager's frame pool. Layout code reads those fields securely later, and the quest item button in the same block is a secure action button: a tainted tracker is the classic way an addon breaks quest items in combat. CLAUDE.md forbids writing fields on Blizzard tables.
- Load timing: `Blizzard_ObjectiveTracker` is not load-on-demand, so `QuestObjectiveTracker` exists at our load. Still install through `ns.ILvlUI.Install("quest", fn)`-style guard and, if the global is nil, `EventUtil.ContinueOnAddOnLoaded("Blizzard_ObjectiveTracker", ...)` as `ItemLevelUI.lua:352` does for the Inspect UI. Campaign quests are a separate module (`CampaignQuestObjectiveTracker`; the quest module skips them, `Blizzard_QuestObjectiveTracker.lua` `ShouldDisplayQuest`); elite campaign quests are not expected, so hook the quest module only, structure the hook to take a module list so adding the campaign module is one line.

### Our button, pooled per block

- Keep a **weak-keyed table** `eyes[block] = button` in our module; never `block.TGFEye = ...`. Blizzard already pools blocks (`ObjectiveTrackerManager:ReleaseFrame`, `Blizzard_ObjectiveTrackerManager.lua:82`), so "one eye per block" gives us pooling for free: a freed block is hidden, taking its child eye with it; when the block is reused for another quest, the next `EndLayout` pass re-evaluates it.
- Per pass: iterate `QuestObjectiveTracker.usedBlocks` (field read; no Blizzard call) -> for each block with a numeric `block.id` (guard `issecretvalue`, `type == "number"`), compute eligibility (below); eligible -> get/create eye (`pcall(CreateFrame, "Button", nil, block, "QuestObjectiveFindGroupButtonTemplate")`, fallback to a plain button with the same atlas as `ItemLevelUI.lua:496-522` does for the stat row), `SetScript("OnClick", ours)` and `SetScript("OnEnter", ours)` **on our frame** (replaces the template's handlers that would call the missing function; the template's mouse-down/up icon nudge can stay), anchor, `Show()`; not eligible or setting off -> `Hide()`. The click handler reads the quest from `self:GetParent().id` at click time (blocks are recycled, never store the quest on the button).
- Retail look: the template gives exactly retail's art (30x30 square button, `socialqueuing-icon-eye`, `TOOLTIP_TRACKER_FIND_GROUP_BUTTON` tooltip text from the shared mixin `OnEnter`, `Blizzard_ObjectiveTrackerShared.lua:198`). Our tooltip can reuse that global plus a second line naming what the click does.
- Position: Blizzard's rightmost right-edge frame sits at `TOPRIGHT` with offset (5, 2) (`findGroupButtonSettings`, `Blizzard_QuestObjectiveTracker.lua:13-17`). If `block.rightEdgeFrame` is nil (read only) anchor ours there; if the block already has a right-edge frame (quest item button), anchor ours `RIGHT` to its `LEFT` with the module's spacing 2. If a Blizzard find-group button is present in the block (`block.rightEdgeFrame` has `Icon` + `questID` attribute) do not add ours (duplicate guard, covers the case where the client does return true).
- Header room: our button extends beyond what `SetHeader` reserved. Post-hook can only re-anchor `block.HeaderText` (`SetPoint("RIGHT", -(w+2), 0)`), the same kind of anchors-only move the sheet row already does (`ItemLevelUI.lua:459-463`), and `Reset` restores it every layout (`Blizzard_ObjectiveTrackerBlock.lua:28-30`) so it never goes stale. Only do it when the narrower width does not change `HeaderText:GetStringHeight()` (a wrap would make the text taller than `block.height`, which we must not write); otherwise let the eye overlay the end of the title. Decide the exact cosmetic in the phase's UI check; this is a layout nicety, not a taint question.
- Eligibility, cached per questID in a local table, cleared on `QUEST_LOG_UPDATE`: `C_QuestLog.IsEliteQuest(questID) == true` (pcall + `issecretvalue`), setting `eliteQuestButton` on, `C_LFGInfo.CanPlayerUsePremadeGroup()` true (otherwise the game's own `LFGVanilla_ToggleFrame` hides instead of showing, `Blizzard_LFGVanilla_ParentFrame.lua:122-150`). Whether to also accept `C_LFGList.CanCreateQuestGroup(questID)` as a second "yes" (dungeon/raid-tagged quests) is a requirements choice; the brief says elite only.
- Setting change: `ns.Settings.OnChange("eliteQuestButton", RefreshAll)` where `RefreshAll` re-runs the same pass over `usedBlocks` (no call into Blizzard code).

### Click flow into the Forever finder (the taint boundary)

What the finder does with quests: **nothing**. `grep` of `Blizzard_GroupFinder_VanillaStyle` finds no `questID` use; `LFGLISTING_QUEST_CATEGORY_ID = 116` is a file-local (`Mainline/LFGVanilla_Constants.lua`), so we carry our own `116`. Categories start unselected (`LFGBrowseCategoryDropdownMixin:Reset` -> `SetValue(0)`, `Blizzard_LFGVanilla_Browse.lua:1098`).

Allowed (precedent or plainly unrestricted):

| Action | Why it is safe |
|--------|----------------|
| `LFGVanilla_ShowFrame(tab)` (tab 1 Listing, 2 Browse; `Blizzard_LFGVanilla_ParentFrame.lua:107-120`) from a click, out of combat | Already what `IP.Open` / `IP.OpenMessages` do (`TGF/UI/InPlace.lua:390-457`); accepted precedent |
| `C_LFGList.SetSearchToQuestID(questID)` / `SetSearchToActivity(activityID)` | Documented, **no** `HasRestrictions` (`LFGListInfoDocumentation.lua:603-621`; restricted ones are `CreateListing`, `UpdateListing`, `Search`, `SetEntryTitle`, `ReportGroupAsAdvertisement`); they are API calls, not writes to a Blizzard table |
| `C_LFGList.GetActivityIDForQuestID(questID)`, `GetActivityInfoTable(id, questID)` | Reads. `GetActivityIDForQuestID` is used by retail (`LFGList.lua:4564`) but is **absent from Forever's generated API docs**: pcall it, LOW confidence |
| Our own frames anchored to / glowing over Blizzard buttons, reading `button.categoryID` | Same as the existing table/tabs; reads only |

Not allowed (each writes Blizzard state from tainted code, which later taints `CreateListing` / `Search` arguments and gets them blocked):

- `LFGBrowseFrame:ShowSearchForActivities` / `SetSelectedSearchActivities` (`Browse.lua:247-285`), `CategoryDropdown:SetValue`, `ActivityDropdown:ValueSetSelected`: they write `selectedCategoryID` / `selectedValues`, which `LFGBrowse_DoSearch` (331-355) passes into the restricted `Search`.
- `LFGListingFrame:SetCategorySelection` / `SetActivity` (`Listing.lua:342-348`, `428-451`): they write `categorySelection` and `activities`, which `CreateOrUpdateListing` (264-327) turns into the `CreateListing` argument.
- Calling `LFGBrowse_DoSearch()` ourselves, or `Click()` on Blizzard's category/activity buttons (runs their OnClick tainted).
- **The description**: the Listing comment edit box is created with `SetSecurityDisableSetText()` and `SetSecurityDisablePaste()` (`Mainline/Blizzard_LFGVanilla_Listing.xml:615-619`, registered through `StoreSecureReference`), and `LfgListingCreateData` has no comment field. An addon cannot put the quest name there, nor can the player paste it. **Drop "quest name as description"** from the requirement and instead print one chat line with the quest name (and optionally put it in our click tooltip) so the player can type it. This answers "as far as the secure box allows": it allows nothing.

The one path that selects category/activity without taint is **the game doing it itself**: Browse registers `LFG_LIST_SHOW_SEARCH(activityIDsFilter, showAllLevelRanges)` (`Browse.lua:58`, handler 155-160) and runs `ShowSearchForActivities(activityIDs)` -> shows Browse, sets the dropdowns, searches, all untainted. Nothing in the shipped Lua fires this event (grep: only the registration), so it is fired by the client. **Unknown (LOW): whether `SetSearchToQuestID` / `SetSearchToActivity` triggers it on Forever.** That decides the route:

1. **Route A (if the event fires):** click -> `C_LFGList.SetSearchToQuestID(questID)` (and/or `SetSearchToActivity(activity)` when `GetActivityIDForQuestID` answers) -> the game opens Browse on the quest's category/activity and searches. A second hint line points to the Listing tab to create.
2. **Route B (if it does not):** click -> `SetSearchToQuestID(questID)` (verify it is not sticky: see PITFALLS) -> `IP.ShowFinder(1)` (Listing, to create) or `(2)` (Browse, to find) -> chat hint "Quests & Zones, <activity>, <quest name>". Optional cosmetic guide: a pulse/glow frame of ours anchored over the Listing category button whose `categoryID == 116` (read-only; the activity rows are pooled ScrollBox frames, skip them).
3. **Route C (fallback):** just `IP.ShowFinder` + hint. Always safe.

Make the first task of the phase an in-game probe, `/tgf quest`, that prints per tracked quest: `IsEliteQuest`, `CanCreateQuestGroup`, `GetActivityIDForQuestID`, the category-116 activities, and (behind an explicit argument, out of combat, from the slash command's hardware-less context so no `Search`) registers `LFG_LIST_SHOW_SEARCH` on a throwaway frame, calls `SetSearchToQuestID`, and reports whether the event came. The author's rule is autonomous runs never pause for in-game checks, so write all three routes behind one function with the probe result deciding a single constant, and flag it as the in-game verification item of the phase.

`IP.ShowFinder(tab)` (NEW, `TGF/UI/InPlace.lua`): out-of-combat check, "isn't ready" message when `LFGVanilla_ShowFrame` is missing (the finder is load-on-demand and the game loads it through `SetLookingForGroupUIAvailable`, `BLZ/Blizzard_LFGUtil/Camelot/LFGUtil.lua:4`; our existing rule is to never call `GroupFinderVanillaStyle_LoadUI`), SettingsPanel-open handling is not needed (the eye is on screen, not the Settings), then `LFGVanilla_ShowFrame(tab)`. `IP.OpenMessages` keeps its Settings-panel wait and its final `ShowMessages()`, calling `IP.ShowFinder` for the middle block. `QuestButton` never touches `LFGParentFrame` directly.

### Data flow (quest eye)

```
QUEST_LOG_UPDATE / QUEST_WATCH_LIST_CHANGED  (Blizzard's own events)
  -> Blizzard QuestObjectiveTracker:Update -> EndLayout
       -> [our post-hook] pass over usedBlocks -> eligibility cache -> eyes[block] Show/Hide/anchor
click (hardware event, out of combat)
  -> read quest = eye:GetParent().id -> resolve activity (pcall) -> SetSearchTo* (unrestricted)
  -> IP.ShowFinder(tab)  -> game's own LFGVanilla_ShowFrame
  -> (Route A) client fires LFG_LIST_SHOW_SEARCH -> game selects + searches
  -> our table reads the answer as usual (InPlace OnSearch/Read, unchanged)
  -> chat hint with the quest name
```

The existing Dynamic refresh plumbing (`InPlace.lua:84-127`) needs no change: a game-driven search of a new filter is "a search for anything else", a new list.

## Feature 3: Per-slot gear info (character sheet and Inspect window)

### Hook points (verified)

- **Character sheet:** global `PaperDollItemSlotButton_Update(self)` (`BLZ/Blizzard_UIPanels_Game/Camelot/PaperDollFrame.lua:2177`) is called on slot show, `PLAYER_EQUIPMENT_CHANGED`, `UNIT_INVENTORY_CHANGED` for player, `BAG_UPDATE` (`PaperDollItemSlotButton_OnShow` 2015-2025 and `_OnEvent` 2050-2075). `hooksecurefunc("PaperDollItemSlotButton_Update", fn)` gives a per-slot, per-change callback with the button (`button:GetID()` = inventory slot) and no events of our own to register. Slot buttons are the globals `CharacterHeadSlot`, `CharacterNeckSlot`, ... in `BLZ/Blizzard_UIPanels_Game/Camelot/PaperDollFrame.xml:779-875`; left column = `PaperDollItemSlotButtonLeftTemplate`, right = `...RightTemplate`, weapons = `...BottomTemplate`. Skip shirt (4), tabard (19), ammo (0). The module is part of the base UI, loaded before us.
- **Inspect window:** global `InspectPaperDollItemSlotButton_Update(button)` (`BLZ/Blizzard_InspectUI/Mainline/InspectPaperDollFrame.lua:245`, the family file Forever loads per the TOC), called for every slot from `InspectPaperDollFrameMixin:UpdateButtons` (line 63, already hooked by `ItemLevelUI.lua:330`) and per slot on `UNIT_INVENTORY_CHANGED` (line 209). The unit is `InspectFrame.unit`. Buttons: `InspectHeadSlot`... (`Camelot/InspectPaperDollFrame.xml:205-312`). Load on demand: reuse the pattern at `ItemLevelUI.lua:315-352` (`EventUtil.ContinueOnAddOnLoaded("Blizzard_InspectUI", ...)`); the existing `ilvlInspect` installer and ours are separate `UI.Install` names, each failing independently.
- Native clutter: Forever's sheet slots carry a `SocketDisplay` frame, but `PaperDollItemSocketDisplayMixin:SetItem` shows it only when `PlayerIsTimerunning()` (`PaperDollFrame.lua:3574-3579`), so for a normal character it is hidden; the Camelot Inspect slot template has none. Our sockets never collide in normal play; on a timerunning character skip our sockets for a slot whose `SocketDisplay:IsShown()` (read only).

### Overlay frames (same rules as the sheet row)

- One child frame per slot button: `overlays[button] = CreateFrame("Frame", nil, button)` in a weak-keyed table (never `button.TGFOverlay`), `EnableMouse(false)` so Blizzard's tooltip and clicks keep working, frame level above the icon. Contents: item-level `FontString` (inside the icon's bottom, quality-coloured via `GetInventoryItemQuality`), enchant `FontString` on the inner side (left column: right of the icon; right column: left of it; weapons: above), socket textures row (gem icons; an empty socket as a dim socket mark). Anchors point at the Blizzard button; nothing of Blizzard's is written.
- Update function `UpdateSlot(button, unit)`: no-op and `overlay:Hide()` when all three slot settings are off; otherwise `GearSlots.Read(unit, slotID)` and set the strings.
- Item data not loaded: `C_Item.GetDetailedItemLevelInfo(link)` can be nil right after the link appears. Use the existing retry shape (1 s apart, 3 tries, token-cancelled: `ItemLevelUI.lua:257-308`), not a new queue.
- Setting change: `ns.Settings.OnChange` for the three keys -> redraw all existing overlays.
- Events needed beyond the two hooks: none for the sheet; for Inspect none either (`UpdateButtons` is the redraw trigger Blizzard already fires on `INSPECT_READY`). Add one `INSPECT_READY` listener only if item data arrives after `UpdateButtons` (that is what the existing `C_Timer.After(0, UpdateInspect)` at `ItemLevelUI.lua:312` works around: our listener may run after Blizzard's).

### Data: `GearSlots.Read(unit, slot)`

| Detail | Source | Confidence |
|--------|--------|------------|
| Link | `GetInventoryItemLink(unit, slot)` (as `ItemLevel.lua:337`); guard `issecretvalue` (`ILvl.Yes` / local `Secret`) | HIGH |
| Item level | `C_Item.GetDetailedItemLevelInfo(link)` (`ItemLevel.lua:91`, `:342`); same figure the overall figure is built from, so slot values and the existing Item Level row agree | HIGH |
| Sockets and gems | `C_Item.GetItemNumSockets(link)`, `C_Item.GetItemGemID(link, i)`, `C_Item.GetItemIconByID(gemID)` with `Item:CreateFromItemID(gemID):ContinueOnItemLoad` for the icon: exactly Blizzard's own logic in `PaperDollItemSocketDisplayMixin:SetItem` (`PaperDollFrame.lua:3576-3605`); documented `ItemDocumentation.lua:534, 876` | HIGH for the API, LOW for inspected links carrying gem IDs |
| Enchant text | `C_TooltipInfo.GetInventoryItem(unit, slot)` and the line with `Enum.TooltipDataLineType.ItemEnchantmentPermanent` (value 15, `TooltipInfoSharedDocumentation.lua:49`); same tooltip-data approach as the item tooltip spot (`ItemLevelUI.lua:595-632`). Fallback for "has an enchant at all": the 2nd field of the item string (`item:<id>:<enchantID>:...`) | MEDIUM (typed lines are documented; Forever runtime and the inspect case unverified) |
| "Missing enchant" | A **static per-slot table of enchantable slots** (there is no API that says "this item could be enchanted"); only flag when the slot is in the table, has an item, and the enchant field is empty. Which slots count on Forever's ruleset, and a level floor so low-level characters are not nagged, are requirement decisions | LOW (design decision, not data) |

Cache: none needed. Yours is live from the equipped items; the Inspect window's items live while it is shown (the game's own inspect). The session GUID cache in `ItemLevel.lua` (`known`, line 98) holds overall figures and talents and is **not** extended; per-slot reads happen on demand while the window is open.

### Reuse of `ItemLevel.lua` and the inspect guard

- The slot overlays **never call `NotifyInspect` / `ClearInspectPlayer` and do not use the quiet queue**. For the Inspect window the game itself inspected; we only read `InspectFrame.unit`. The existing guard already keeps our queue away while that window is shown or pending (`ItemLevel.lua:746-767`, `Busy`), and never clears the inspect while it is open (`Done`, 799-815), so the data we read stays valid.
- Reused: `ns.ILvl.Yes` (secret-safe truth), `ns.ILvlUI.Install` (`ItemLevelUI.lua:56-72`; failures land in `UI.failed` and are printed by `/tgf ilvl` at `ItemLevel.lua:1007-1011`), `ns.ILvlUI.Gold()`. If the quest module should also report failures, either give it the same `Install` or print its own in `/tgf quest`.
- New slot ids are the same numbers as `ItemLevel.lua:42-61` `SLOT_NAMES` (1-19); share the table by exporting it as `ILvl.SLOT_NAMES` (one-line MOD) or duplicate the needed subset.
- Own item vs. other: for `"player"` all reads are exact and live; for `InspectFrame.unit`, treat a nil link as "nothing equipped or not loaded yet" (the retry decides) and never show "missing enchant" until the item level for that slot has resolved, otherwise a half-loaded inspect flags every slot.

### Data flow (gear info)

```
player: equip change / sheet open / bag update
  -> Blizzard PaperDollItemSlotButton_Update(button)  -> [our post-hook] UpdateSlot(button, "player")
inspect: Blizzard INSPECT_READY -> InspectFrame OnShow/UpdateButtons -> InspectPaperDollItemSlotButton_Update(button)
  -> [our post-hook] UpdateSlot(button, InspectFrame.unit)  (retry x3 for late item data)
UpdateSlot -> GearSlots.Read -> ns.Settings.Get(slotItemLevel|slotEnchants|slotSockets) -> overlay strings/textures
```

## Patterns to Follow

### Pattern 1: post-hook, own frame, weak table
**What:** `hooksecurefunc` on the Blizzard function, state in a weak-keyed table keyed by the Blizzard frame, children parented to the Blizzard frame.
**When:** every Blizzard-frame decoration (tracker blocks, paper doll slots).
**Example:**
```lua
local eyes = setmetatable({}, { __mode = "k" })
local function Pass(module)
	for _, blocks in pairs(module.usedBlocks or {}) do
		for _, block in pairs(blocks) do
			Decorate(block, eyes[block])   -- reads block.id, never writes it
		end
	end
end
hooksecurefunc(QuestObjectiveTracker, "EndLayout", function(self) pcall(Pass, self) end)
```

### Pattern 2: independent pcall-guarded installers
**What:** `ns.ILvlUI.Install(name, fn)`; a missing hook point records the failure and the next spot still installs.
**When:** the tracker hook, the sheet slots, the Inspect slots (three installs).

### Pattern 3: settings read where acting, `OnChange` redraws
**What:** `ns.Settings.Get(key)` inside the hook body, `ns.Settings.OnChange(key, Redraw)` once at install; never cache.

### Pattern 4: probe commands for unverifiable runtime behaviour
**What:** `/tgf quest`, `/tgf gear` print exactly what the client returns (as `/tgf ilvl`, `/tgf region`). Add both to `USAGE` (`Core.lua:306`) and the slash switch (`Core.lua:315-347`). Required because three load-bearing facts can only be settled in the Forever client.

## Anti-Patterns to Avoid

### Anti-pattern 1: driving the finder's dropdowns or Listing state from the click
**Why bad:** writes Blizzard tables; the next `Search`/`CreateListing` reads tainted arguments and the game blocks it (`ADDON_ACTION_BLOCKED`), breaking the finder for the whole session.
**Instead:** `SetSearchTo*` + `LFGVanilla_ShowFrame` + hint; let the game's `LFG_LIST_SHOW_SEARCH` path do selection if it can.

### Anti-pattern 2: reusing Blizzard's right-edge machinery
**Why bad:** `AddRightEdgeFrame` / `GetRightEdgeFrame` write block, module and pool fields from tainted code (see Feature 2).
**Instead:** our own button, our own anchors.

### Anti-pattern 3: Migrate asking the registry
**Why bad:** at Migrate time `Settings.Get` yields the new off defaults, so existing players would "keep" off.
**Instead:** frozen list of the old defaults inside Migrate.

### Anti-pattern 4: starting inspects for the Inspect window overlays
**Why bad:** a second `NotifyInspect` or a `ClearInspectPlayer` collides with the game's own inspect and blanks the window. The guard in `ItemLevel.lua` exists for exactly that.
**Instead:** read `InspectFrame.unit` only.

## Scalability Considerations

| Concern | Typical | Heavy |
|---------|---------|-------|
| Tracker pass | 1-25 watched quests, one pass per layout, cached eligibility | Same; cache cleared on `QUEST_LOG_UPDATE` only |
| Slot overlays | 17 slots x 1 read per slot update; tooltip-data call only when `slotEnchants` is on, cached per link string | Cache invalidated by link change; gem icon loads async once per gem ID |
| Settings page | 4 extra checkboxes | n/a |

## Suggested Build Order (coarse)

1. **Phase A: Opt-in defaults and settings foundation.** Registry reorder + section rename, the six default flips, the four new keys registered (feature code may be stubs reading them), `Migrate` schema 4 with the frozen list, `DEFAULTS.schema = 4`, CLAUDE.md/Settings comments. Why first: everything else is gated by these keys, and it is the only change that can silently alter existing players' saved data, so it should be done and verified (empty table, schema-3 table, schema-2 table, partly-set table) before features arrive. No Blizzard integration risk.
2. **Phase B: Elite quest eye.** `QuestButton.lua`, `IP.ShowFinder`, TOC, `/tgf quest`. Highest uncertainty (client API behaviour, route A/B/C), so it goes before gear info to leave time for the in-game check. Begins with the probe command and the route constant; the hook and button are certain regardless of the route.
3. **Phase C: Per-slot gear info.** `GearSlots.lua`, sheet then Inspect, three settings, `/tgf gear`. Independent of B and can run in parallel with it (no shared file except Core.lua/TOC/Settings, all touched in A or by trivial one-line edits). Sheet first because it needs no inspect data and proves the overlay layout; Inspect reuses the same `UpdateSlot`.
4. **Phase D: Release Review (final).** Code cleanup (stylua), CLAUDE.md Architecture entries for `QuestButton.lua` / `GearSlots.lua`, README screenshots (new: Settings page sections, tracker eye, character sheet slots, Inspect slots; flag per the screenshot-reminder rule), version, changelog draft for the author, the author's review. Note for the changelog: the opt-in default change is the one behaviour change existing players must be told about (their settings are kept, new installs start minimal).

**Dependencies:** A -> B and C (keys). B and C independent. D last. Only shared edited files: `Core.lua` (A: Migrate; B, C: Init lines + probes), `TerribleGroupFinder.toc` (B, C), `UI/InPlace.lua` (B only), `Settings.lua` (A; B and C only read).

## Research Flags for Phases

- **Phase B needs an in-game probe before the click flow is final:** (1) does `C_LFGList.CanCreateQuestGroup` ever return true on Forever (would give a duplicate/erroring Blizzard button; guard exists), (2) does `GetActivityIDForQuestID` exist and answer, which activities category 116 holds and how a quest maps to one (zone activity by map?), (3) does `SetSearchToQuestID` / `SetSearchToActivity` fire `LFG_LIST_SHOW_SEARCH`, (4) is the search-to-quest state sticky across later normal searches.
- **Phase C needs a probe for inspect links:** do `GetInventoryItemLink(InspectFrame.unit, slot)` links include enchant and gem IDs, and does `C_TooltipInfo.GetInventoryItem` return the enchant line for an inspected unit; plus the enchantable-slot list for Forever's ruleset.
- **Phase A is standard:** no research needed beyond a Migrate test matrix.

## Sources

- `BLZ/Blizzard_ObjectiveTracker/Blizzard_QuestObjectiveTracker.lua` (13-17, 291, 308-310, 412), `Blizzard_ObjectiveTrackerModule.lua` (126-217, 254-332, 587-626), `Blizzard_ObjectiveTrackerBlock.lua` (24-33, 155-159, 347-373), `Blizzard_ObjectiveTrackerShared.lua` (180-210), `Blizzard_ObjectiveTrackerShared.xml` (65-88), `Camelot/Blizzard_QuestObjectiveTrackerOverride.lua`: HIGH (source read).
- `BLZ/Blizzard_FrameXMLUtil/Camelot/QuestUtilsOverrides.lua` (7, 16-20), `Mainline/QuestUtils.lua` (375-388): HIGH.
- `BLZ/Blizzard_GroupFinder/Blizzard_GroupFinder.toc` (`ExcludeLoadGameType: camelot`) and `Mainline/LFGList.lua` (513-536, 4594): HIGH for "retail finder absent".
- `BLZ/Blizzard_GroupFinder_VanillaStyle/` Browse.lua (58, 139-163, 247-285, 331-355, 1045-1100), Listing.lua (142-195, 246-360, 428-451), ParentFrame.lua (107-150), `Mainline/Blizzard_LFGVanilla_Listing.xml` (602-632), `Mainline/LFGVanilla_Constants.lua`: HIGH.
- `BLZ/Blizzard_APIDocumentationGenerated/LFGListInfoDocumentation.lua` (restricted functions, `SetSearchTo*`, `LFG_LIST_SHOW_SEARCH` at 815-825), `QuestLogDocumentation.lua` (749), `ItemDocumentation.lua` (534, 876), `TooltipInfoSharedDocumentation.lua` (49), `TooltipInfoDocumentation.lua` (389): HIGH for the documented surface, runtime behaviour LOW.
- `BLZ/Blizzard_UIPanels_Game/Camelot/PaperDollFrame.lua` (2015-2075, 2177, 3574-3605), `PaperDollFrame.xml` (107-160, 779-875); `BLZ/Blizzard_InspectUI/Blizzard_InspectUI.toc`, `Mainline/InspectPaperDollFrame.lua` (63, 189-275), `Camelot/InspectPaperDollFrame.xml` (3-30, 205-312): HIGH.
- `TGF/Core.lua` (25-47, 270-348), `Settings.lua` (20-48, 122-191), `UI/SettingsPanel.lua` (16-87), `UI/InPlace.lua` (23-24, 300-369, 388-457), `ItemLevel.lua` (42-61, 91-98, 333-366, 746-815, 966-1119), `ItemLevelUI.lua` (56-72, 248-361, 363-561), `CLAUDE.md`, `.planning/PROJECT.md` (v0.3.0 brief), `.planning/research/FOREVER-GROUPFINDER.md` (categories, API inventory): HIGH (project source).
