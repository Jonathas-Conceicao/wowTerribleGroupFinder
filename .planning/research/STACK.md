# Stack Research: v0.2 client APIs, frames and mixins

**Domain:** WoW Forever addon (modern client, interface 16001, game type `camelot`), Lua + XML, no libraries
**Researched:** 2026-11-14
**Confidence:** HIGH for what the Blizzard source shows. Anything that depends on game data or live geometry is flagged LOW or MEDIUM and listed under "Needs an in-game check".

All paths are under `C:\Users\jonat\Repositories\wow-ui-source\Interface\AddOns\` (branch `forever`, read-only). Written `WUI\` below. Line numbers are from that branch.

There is no new library. v0.2 is entirely Blizzard frames, hooks and the Settings API. Adding libraries (Ace, LibStub) would go against the "native to Forever, no external libs" rule for nothing.

## Summary of decisions

| Feature | Use | Do not use |
|---------|-----|-----------|
| Character sheet row | `hooksecurefunc(CharacterStatsPaneScrollBox, "UpdateStats", fn)`, insert a `{ name = "ITEMLEVEL", ... }` element after the `MOVESPEED` element, re-set the data provider. Blizzard's own `PAPERDOLL_STATINFO.ITEMLEVEL` draws it | Writing to `PAPERDOLL_STATCATEGORIES` / `PAPERDOLL_STATINFO`; the legacy `CharacterStatsPane` frame (not shown on Forever) |
| Inspect text | A FontString on `InspectPaperDollFrame`, created inside `EventUtil.ContinueOnAddOnLoaded("Blizzard_InspectUI", ...)`, refreshed from `hooksecurefunc(InspectPaperDollFrame, "UpdateButtons")` | Replacing `InspectPaperDollFrameMixin` methods; touching `InspectLevelText` |
| Item tooltip | `TooltipDataProcessor.AddLinePostCall(Enum.TooltipDataLineType.ItemName, fn)` that calls `tooltip:AddLine` right after the name line | Post-call on the tooltip as a whole (the line would land at the bottom); `GameTooltip:HookScript("OnTooltipSetItem")` (does not exist on this client) |
| Settings window | `Settings.RegisterVerticalLayoutCategory` + `Settings.RegisterAddOnSetting` + `Settings.CreateCheckbox` + `CreateSettingsButtonInitializer`, then `Settings.RegisterAddOnCategory` | A hand-built options frame; canvas layout |
| Row animations | `row:CreateAnimationGroup()` with `Translation` + `Alpha`, `SetToFinalAlpha(true)` on the out group | Moving row anchors inside a ScrollBox; `UIFrameFade`-style OnUpdate loops |

## (a) Character sheet stats pane

### What Forever actually uses (verified)

Forever loads the **Camelot** variants, not Mainline:

- `WUI\Blizzard_UIPanels_Game\Blizzard_UIPanels_Game.toc:44-47` loads `[Game]\CharacterFrame.lua/.xml` for camelot (the `[Family]` copy is excluded for camelot), and `:51-60` loads `[Game]\PaperDollFrameConstants.lua`, `[Game]\PaperDollFrame.lua`, `[Game]\PaperDollFrame.xml`. `[Game]` resolves to the `Camelot\` folder (it exists next to `Mainline\`, `Vanilla\`, `Cata\`).
- The addon is not LoadOnDemand (no `LoadOnDemand` line in that TOC), so the globals exist when our `ADDON_LOADED` runs. The Inspect UI is the one that IS LoadOnDemand (see (b)).

The pane that shows is a **ScrollBox**, not the old fixed-frame `CharacterStatsPane`:

- `WUI\Blizzard_UIPanels_Game\Camelot\CharacterFrame.lua:823-825`: `CharacterFrameMixin:GetStatsPane()` returns `CharacterStatsPaneScrollBox`.
- `WUI\Blizzard_UIPanels_Game\Camelot\PaperDollFrame.lua:2403-2414`: `PaperDollFrame_UpdateStats()` calls `statsPane:UpdateStats()` when the pane is `CharacterStatsPaneScrollBox` (the `PaperDollFrame_UpdateStatsInternal` branch, `:2416`, is the legacy path and never runs here). The pet pane `CharacterStatsPanePetScrollBox` is updated separately (`:2411-2413`).
- `CharacterFrame.xml:463` defines `CharacterStatsPaneScrollBox` (`mixin="CharacterStatsPaneScrollBoxMixin"`); the pet one is `:479`. `CharacterStatsPane` (`:486`, hidden) is the legacy frame; ignore it.

### The General category and Movement Speed

`WUI\Blizzard_UIPanels_Game\Camelot\PaperDollFrameConstants.lua:35-44`:

```lua
PAPERDOLL_STATCATEGORIES = {
  { categoryName = STAT_CATEGORY_GENERAL, unit = "player",
    stats = { { stat = "HEALTH" }, { stat = "POWER" }, { stat = "MOVESPEED" } } },
  ...
```

So yes: a General category exists with `MOVESPEED` last, for the player. The pet's General category (`:92-101`) also ends with `MOVESPEED`, which matters for the pet pane (hook only the player pane).

### How a row is defined and built

- `PAPERDOLL_STATINFO` (`PaperDollFrame.lua:109`): `name -> { updateFunc = function(statFrame, unit, id) ... end }`. `["MOVESPEED"]` is `:125-127`.
- **`PAPERDOLL_STATINFO["ITEMLEVEL"]` already exists** (`PaperDollFrame.lua:122-124`) and calls `PaperDollFrame_SetItemLevel` (`:1378-1405`). That function (player only) does exactly what v0.2 wants: `GetAverageItemLevel()` returns `avg, equipped, pvp`; displayed = `floor(max(C_PaperDollInfo.GetMinItemLevel() or 0, equipped))` (`:1384-1389`), label `STAT_AVERAGE_ITEM_LEVEL`, and it fills `tooltip` / `tooltip2` including the "equipped" and PvP lines (`:1393-1402`). It is just not listed in any category on Forever, which is why the sheet shows no item level.
- `CharacterStatsPaneScrollBoxMixin:UpdateStats()` (`CharacterFrame.lua:1102-1224`) rebuilds `self.elementData` from `PAPERDOLL_STATCATEGORIES`: a header element per category (`:1159-1162`), then one element per visible stat (`:1165-1182`):

  ```lua
  { isHeader = false, unit = self:GetUnit(), name = stat.stat, id = stat.id,
    statIndex = actualIndex, ..., hideAt = stat.hideAt }
  ```

  then `self.ScrollBox:SetDataProvider(CreateDataProvider(self.elementData), ScrollBoxConstants.RetainScrollPosition)` (`:1223`). `CreateDataProvider` copies the table into a provider (`WUI\Blizzard_SharedXML\DataProvider.lua:14-20`, `InsertTable`), so editing `elementData` after the fact does not change the shown list until the provider is set again.
- Row frames: `CharacterStatFrameScrollBoxLabelElementTemplate` for plain rows (`CharacterFrame.xml:221-234`, has `Label` + `Value`), picked by the element factory (`CharacterFrame.lua:1058-1066`). `CharacterStatFrameScrollBoxBaseElementMixin:Init(elementData)` (`:1239-1275`) sets the zebra background from `statIndex % 2` (`:1247`) and, when `elementData.name` is a key of `PAPERDOLL_STATINFO`, calls its `updateFunc(self, elementData.unit, elementData.id)` (`:1264-1268`). With no `name`, it just applies `labelText` / `valueText` / `tooltip` / `tooltip2` / `tooltip3` from the element (`:1242-1258`); this is how the Resistance rows are made (`:1207-1217`).

### Recommended way to add the row

Hook the method on the player pane object and insert Blizzard's own `ITEMLEVEL` element right after Movement Speed:

```lua
-- after Blizzard_UIPanels_Game is loaded (it always is by our ADDON_LOADED)
hooksecurefunc(CharacterStatsPaneScrollBox, "UpdateStats", function(self)
  if not DB.sheetItemLevel then return end
  local data = self.elementData
  for i, e in ipairs(data) do
    if not e.isHeader and e.name == "MOVESPEED" then
      table.insert(data, i + 1, {
        isHeader = false, name = "ITEMLEVEL", unit = "player",
        statIndex = e.statIndex + 1,      -- keeps the zebra stripe right
      })
      self.ScrollBox:SetDataProvider(CreateDataProvider(data), ScrollBoxConstants.RetainScrollPosition)
      return
    end
  end
end)
```

Why this shape:

- **No Blizzard table is written** (`PAPERDOLL_STATCATEGORIES`, `PAPERDOLL_STATINFO`). Those are read inside Blizzard's `UpdateStats` loop and inside every row `Init`; a tainted entry there would taint that whole secure execution. A post-hook runs after Blizzard's code and cannot taint it.
- **Insert into `self.elementData`, not only the provider.** `CharacterStatsPaneScrollBoxMixin:HideElements()` (`:1078-1092`) rebuilds the provider from `self.elementData` whenever a `hideAt` stat disappears (`:1089-1091`); an entry added only to the provider would vanish on that rebuild.
- **Use `name = "ITEMLEVEL"`** instead of our own `labelText`/`valueText`: Blizzard's `Init` then computes the value on every row (re)bind, so the number follows equipment changes and the stock tooltip works with no code of ours. The label text comes from `STAT_AVERAGE_ITEM_LEVEL`.
- **Refresh triggers are already covered.** `PLAYER_EQUIPMENT_CHANGED`, `PLAYER_AVG_ITEM_LEVEL_UPDATE`, `BAG_UPDATE` and others queue `PaperDollFrame_QueuedUpdate` -> `PaperDollFrame_UpdateStats` (`PaperDollFrame.lua:392-395`, `:470-483`), which calls `UpdateStats` on the pane, so the hook fires each time. `PaperDollFrame_OnShow` also calls it (`:1515`).
- Toggling the setting off: if the sheet is shown, call `CharacterStatsPaneScrollBox:UpdateStats()` once so the row is rebuilt without ours (guard `IsShown()`).
- Use `hooksecurefunc(CharacterStatsPaneScrollBox, "UpdateStats", ...)` on the object, not on the mixin table: the XML `mixin=` attribute copies the functions onto the frame (`CharacterFrame.xml:463`), and the pet pane has its own copy (`CharacterStatsPanePetScrollBoxMixin = CreateFromMixins(...)`, `CharacterFrame.lua:1298`), so the pet pane stays untouched.

Value colour: `PaperDollFrame_UpdateStatsInternal` colours the legacy item level value with `GetItemLevelColor()` (`:2423`); the ScrollBox path does not. Leave the stock white value (native look).

### Safe vs unsafe

| Approach | Verdict |
|----------|---------|
| Post-hook + insert `name="ITEMLEVEL"` element | Recommended. Our code runs after Blizzard's; the row is built by Blizzard code. Only the data provider assignment runs from our (insecure) context |
| `table.insert(PAPERDOLL_STATCATEGORIES[1].stats, 4, { stat = "ITEMLEVEL" })` | One line, uses the same stock pipeline. Rejected as primary: it writes into a table that secure code reads on every update (the shifted slots are rewritten by insecure code), so the stats update path runs tainted for as long as the entry is there. It is not removable cleanly when the user turns the setting off without a reload. Keep as a fallback only if the hook shows a problem |
| Custom `PAPERDOLL_STATINFO["TGF_ILVL"].updateFunc` | Rejected: our function would run inside Blizzard's `UpdateStats` and every `Init`, tainting them |
| Anchoring our own frame under the Movement Speed row | Rejected: rows are pooled ScrollBox frames of fixed height (`CharacterFrame.xml` base template `Size 187x23`); an extra line overlaps the next row and detaches on scroll |

### Needs an in-game check
- The hook's `SetDataProvider` runs in addon context (the ScrollBox then initialises rows). Open the sheet, change gear, scroll, switch sidebar tabs (Stats / Equipment / Titles / Pet), in and out of combat, and watch for `ADDON_ACTION_BLOCKED`. MEDIUM confidence there is no taint problem (the character sheet calls no protected function).
- `STAT_AVERAGE_ITEM_LEVEL` is a GlobalString (not in the source tree); it is used by Blizzard here, so the global exists. Its text is expected to be "Item Level"; confirm in game.

## (b) Inspect frame

### Files on Forever

`WUI\Blizzard_InspectUI\Blizzard_InspectUI.toc`: `LoadOnDemand: 1`. For camelot it loads `Camelot\Blizzard_InspectUI.lua` / `.xml` (`[Game]\` lines 6, 11), `Camelot\InspectPaperDollFrame.xml`, and `[Family]\InspectPaperDollFrame.lua` (the Mainline file: `Mainline\InspectPaperDollFrame.lua`, because the Camelot folder has no such Lua file; the Camelot XML refers to `InspectPaperDollFrameMixin`, `Camelot\InspectPaperDollFrame.xml:56`). MEDIUM: the toc line has `[AllowLoadGameType mainline]` and I inferred camelot loads the Family copy; the only Lua defining `InspectPaperDollFrameMixin` in the tree is the Mainline one, so it must.

Opening: `InspectUnit(unit)` (`Mainline\Blizzard_InspectUI_Bootstrap.lua`, loads the addon, then `InspectFrame_Show`) -> `Camelot\Blizzard_InspectUI.lua:41-50` (`HideUIPanel`, `NotifyInspect(unit)`, `InspectFrame.unit = unit`, `InspectSwitchTabs(1)`). `INSPECT_READY(guid)` reaches `InspectFrameMixin:OnEvent` (`:87-97`), which updates the header and calls `ShowUIPanel(InspectFrame)`; that shows `InspectPaperDollFrame` whose `OnShow` runs `SetLevel()` and `UpdateButtons()` (`Mainline\InspectPaperDollFrame.lua`, OnShow and `OnEvent` for `INSPECT_READY`; the unit is `InspectFrame.unit`, a unit token such as "target" or "party2").

### Where the text can sit

- `InspectFrame` is a `ButtonFrameTemplate` (`Camelot\Blizzard_InspectUI.xml:13`); its parts: `InspectFrameInset` (`parentKey="Inset"`, TOPLEFT 4,-60 / BOTTOMRIGHT -6,26, `WUI\Blizzard_SharedXML\Mainline\SharedUIPanelTemplates.xml:711-721`), `CloseButton` top right, title text in the top bar (the portrait frame template). The frame has no `<Size>` in XML (size comes from the UI panel system), so do not hard-code pixel positions from the left; anchor relative to `InspectFrame` / `InspectFrameInset`.
- `InspectPaperDollFrame` fills the frame (`setAllPoints`, `Camelot\InspectPaperDollFrame.xml:56`). Its `LevelTextWrapper` / `InspectLevelText` is centred at TOP y=-40, width 220 (`:58-70`), with `InspectTitleText` and `InspectGuildText` below it (`:321-330`).
- A short right-aligned FontString anchored `BOTTOMRIGHT` to `InspectFrame.Inset`'s `TOPRIGHT` (about x=-6, y=+3) sits in the strip between the title bar and the inset, at the top right, and does not overlap the slot columns (the right equipment column starts inside the inset, `InspectPaperDollFrame.xml:254`). Parent it to `InspectPaperDollFrame` so it hides with the other Inspect tabs (PvP, Guild).

```lua
EventUtil.ContinueOnAddOnLoaded("Blizzard_InspectUI", function()   -- WUI\Blizzard_SharedXML\EventUtil.lua:67
  local fs = InspectPaperDollFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  fs:SetPoint("BOTTOMRIGHT", InspectFrame.Inset, "TOPRIGHT", -6, 3)
  local function Update()
    local unit = InspectFrame.unit
    local ilvl = unit and ns.ILvl.ForUnit(unit)   -- C_PaperDollInfo.GetInspectItemLevel, see ItemLevel.lua
    fs:SetText(DB.inspectItemLevel and ilvl and ("Item Level " .. ilvl) or "")
  end
  hooksecurefunc(InspectPaperDollFrame, "UpdateButtons", Update)   -- OnShow and INSPECT_READY
  hooksecurefunc(InspectPaperDollFrame, "SetLevel", Update)        -- level / name updates
end)
```

Why `UpdateButtons` and not our own `INSPECT_READY`: Blizzard's handler runs on the same event only after `InspectFrame.unit` matches the GUID (`Mainline\InspectPaperDollFrame.lua`, `OnEvent`), so our hook never reads the figure for a stale unit, and it also fires on `OnShow` for re-opened windows. `ns.ILvl`'s existing `INSPECT_READY` listener (`ItemLevel.lua:572-576`) already stores the number; the hook only reads it.

- API: `C_PaperDollInfo.GetInspectItemLevel(unit)` -> `equippedItemLevel` (number), `SecretArguments = "AllowedWhenUntainted"` (`WUI\Blizzard_APIDocumentationGenerated\PaperDollInfoDocumentation.lua:122-136`). Unit tokens are plain strings, no secret problem; still wrap with `issecretvalue()` on the result before arithmetic (project rule).
- `InspectFrame.unit` is cleared in `OnHide` (`Camelot\Blizzard_InspectUI.lua:144-152`), so `Update` must tolerate nil.
- Interaction with our quiet inspects: Blizzard's `ClearInspectPlayer()` runs on hide (`:150`) and `NotifyInspect` is a single global slot. The existing rule "no quiet inspect while the Inspect window is open" (CLAUDE.md, `ItemLevel.lua`) is the right guard; keep it.

### Needs an in-game check
- Real width of the Inspect window and whether "Item Level 123" collides with the centred `InspectLevelText` (220 wide) for long class/spec strings. Fallback: anchor below `InspectGuildText`/`InspectTitleText` or at the top of the inset's right column.

## (c) Item tooltips

### How tooltips are built on Forever (verified)

- Tooltip data comes from `C_TooltipInfo` and is processed by `TooltipDataHandlerMixin` (`WUI\Blizzard_SharedXMLGame\Tooltip\TooltipDataHandler.lua`). `Blizzard_GameTooltip` ships only `Mainline\GameTooltip.lua/.xml` and `Shared\`; there is no Camelot-specific tooltip, so Forever uses this pipeline.
- Registration: `TooltipDataProcessor.AddTooltipPreCall/AddTooltipPostCall/AddLinePreCall/AddLinePostCall(type, func)` (`:195-209`). Addon (insecure) callbacks are queued through a forbidden `AttributeDelegate` frame (`:111-125`) and run via `securecallfunction` after `forceinsecure()` (`:62-72`, `:181-193`), so they cannot taint Blizzard's processing. Our unit tooltip hook already uses this (`ItemLevel.lua:577-578`).
- Order inside `InternalProcessInfo` (`:245-307`): tooltip pre-calls -> `ProcessLines()` -> `tooltipPostCall` -> tooltip post-calls -> `Show()`. In `ProcessLineData` (`:319-336`) the line post-call runs **immediately after that line is added** (`AddLineDataText`, then `ProcessLinePostCalls(lineData.type, ...)` at `:334`). That is the only hook that lets us add a line directly under the name without reordering.
- Enums (verified, `WUI\Blizzard_APIDocumentationGenerated\TooltipInfoSharedDocumentation.lua`): `Enum.TooltipDataType.Item = 0` (`:89-95`), `Enum.TooltipDataLineType.ItemName = 22`, `ItemLevel = 31` (`:65`), `ItemUpgradeLevel = 32`, `ItemQuality = 35`.
- The shape of `tooltipData` (`.type`, `.lines[i].type/.leftText/...`, `.hyperlink`, `.guid`, `.id`) is used in Blizzard's own code: `TooltipUtil.GetDisplayedItem` (`WUI\Blizzard_SharedXMLGame\Tooltip\TooltipUtil.lua:9-22`) takes `tooltipData.guid` -> `C_Item.GetItemLinkByGUID`, else `tooltipData.hyperlink`; `ProcessLines` iterates `info.tooltipData.lines` (`:314`). The structure is not in the generated API docs (only `TooltipDataArg` is), so field names rest on Blizzard Lua usage, which is reliable.

### Is "Item Level" already shown on Forever?

- No Forever cvar or built-in line is visible in the UI source. Searches for `showItemLevel`, `ITEM_LEVEL_TOOLTIP`, cvar-driven item level tooltip code found only Garrison/Weekly Rewards uses. Retail's "Item Level N" line is a **server-provided line of type `ItemLevel` (31)** in `tooltipData.lines`; whether Forever's data carries it for gear cannot be read from source (it is client data). The item-level design of v0.2 therefore must detect it at runtime and never add a second one: scan `processingInfo.tooltipData.lines` for `type == Enum.TooltipDataLineType.ItemLevel` and do nothing if found. LOW confidence on the data content; HIGH that the line type exists in the client's enum.
- `ITEM_LEVEL` (GlobalString, format with `%d`) is a stock string: `WUI\Blizzard_FrameXML\EventToastManager.lua:646` uses `ITEM_LEVEL:format(ilvl)`. Use it so the text localises ("Item Level %d").

### Recommended implementation

```lua
local ITEM, NAME = Enum.TooltipDataType.Item, Enum.TooltipDataLineType.ItemName
TooltipDataProcessor.AddLinePostCall(NAME, function(tooltip, lineData)
  if not DB.itemTooltip or tooltip:IsForbidden() then return end
  local info = tooltip:GetProcessingTooltipInfo()                    -- TooltipDataHandler.lua:397
  local data = info and info.tooltipData
  if not data or data.type ~= ITEM then return end                    -- ItemName also appears on non-item data? check
  for _, l in ipairs(data.lines) do
    if l.type == Enum.TooltipDataLineType.ItemLevel then return end   -- stock line present, do not duplicate
  end
  local link = data.guid and C_Item.GetItemLinkByGUID(data.guid) or data.hyperlink
  if not link or issecretvalue(link) then return end
  local _, _, _, _, _, classID = C_Item.GetItemInfoInstant(link)
  if classID ~= Enum.ItemClass.Weapon and classID ~= Enum.ItemClass.Armor then return end
  local ilvl = C_Item.GetDetailedItemLevelInfo(link)
  if ilvl and ilvl > 0 then
    tooltip:AddLine(ITEM_LEVEL:format(ilvl), NORMAL_FONT_COLOR:GetRGB())   -- gold, directly under the name
  end
end)
```

Reasons:

- `AddLinePostCall(ItemName)` puts the line under the name **before** binding/slot/stat lines are added, and the tooltip is sized later by `self:Show()` (`:300`), so no manual resize or `:Show()` is needed (the unit tooltip prototype needs `:Show()` because it appends after the fact).
- `GetProcessingTooltipInfo()` (`:397-399`) is the info being processed, correct for `append` tooltips (comparison, embedded); `GetPrimaryTooltipData` would be wrong there.
- `C_Item.GetDetailedItemLevelInfo(itemInfo)` returns `actualItemLevel, previewLevel, sparseItemLevel` (`WUI\Blizzard_APIDocumentationGenerated\ItemDocumentation.lua:354-370`); `SecretArguments = "AllowedWhenUntainted"`, so guard the link against secrets in combat. `C_Item.GetItemInfoInstant` returns `classID` as 6th value (`:659-679`); `Enum.ItemClass.Weapon = 2`, `Armor = 4` (`ItemConstantsDocumentation.lua:269-281`). Restricting to Weapon/Armor matches retail (only equippable gear shows the line).
- The same hook covers `GameTooltip`, `ItemRefTooltip`, and the compare (shopping) tooltips, since they all use `TooltipDataHandlerMixin`. Retail shows the line on those too.
- Colour: retail's level line is gold (`NORMAL_FONT_COLOR` here); `GameTooltip_AddColoredLine` (used by Blizzard at `TooltipDataHandler.lua:348`) is equivalent if a wrap argument is needed.

What NOT to use:

- `AddTooltipPostCall(Item, ...)`: runs after all lines; the level would land at the bottom, not under the name.
- `AddLinePreCall` + returning true: would consume (hide) the original line; not needed.
- `GameTooltip:HookScript("OnTooltipSetItem")`: not part of this pipeline (tooltip data processor replaced it); relying on it is a trap.
- Reading `lineData.leftText` from line data for anything: in combat it can be secret; only `.type` and `.guid`/`.hyperlink` are needed.

### Needs an in-game check
- Whether `ItemLevel` lines already appear for Forever gear (then the feature is a no-op by design; the toggle would still exist for tidy settings) and whether `ItemName` line precedes other lines for every item data type (Item only; Toy/Spell use other line types).

## (d) Settings API

### Verified: public and designed for addons

- `WUI\Blizzard_Settings_Shared\Blizzard_Settings_Shared.toc` loads the whole system for both glue and game, with `Camelot\NewDefinitions.lua` for camelot (`:7`), and the `SettingsPanel` frame is in `Blizzard_SettingsPanel.xml` (`name="SettingsPanel"`, `:4`). The Game/AddOns tabs: the panel shows an AddOns tab only when an addon category is registered (`Blizzard_SettingsPanel.lua:164-176`).
- `WUI\Blizzard_Settings_Shared\Blizzard_ImplementationReadme.lua:1-210` is Blizzard's addon guide (vertical list or canvas, Proxy vs AddOn settings, opening to a category). It uses exactly the calls below.
- API surface (`Blizzard_Settings.lua`): `Settings.RegisterVerticalLayoutCategory(name)` `:154`, `RegisterVerticalLayoutSubcategory` `:158`, `RegisterCanvasLayoutCategory(frame, name)` `:162`, `RegisterAddOnCategory(category)` `:134`, `RegisterAddOnSetting(category, variable, variableKey, variableTbl, variableType, name, defaultValue)` `:174`, `RegisterProxySetting(...)` `:178`, `CreateCheckbox(category, setting, tooltip)` `:388`, `CreateSlider` `:404`, `CreateDropdown` `:410`, `OpenToCategory(categoryID, scrollToElementName)` `:144`, `Settings.VarType.Boolean` / `Settings.Default.True` `:11-22`.
- Category objects: `category:GetID()` is what `OpenToCategory` takes (`Blizzard_ImplementationReadme.lua:199-209`).
- Inbound calls go through a secure `AttributeDelegate` (`Blizzard_SettingsInbound.lua:80-125`), so the addon is not tainting the panel. `AddOnSettingMixin` reads and writes the saved table through `securecallfunction` and **default-fills the key if nil** (`Blizzard_Setting.lua:405-436`, `securecallfunction(SecureSetVariableTblDefaultValue, ...)`).
- Value-changed callback: `setting:SetValueChangedCallback(function(setting, value) end)` (`Blizzard_Setting.lua:265-269`).
- Button row: `CreateSettingsButtonInitializer(name, buttonText, buttonClick, tooltip, addSearchTags, ...)` (`Blizzard_SettingControls.lua:1040-1053`) -> add with `layout:AddInitializer(initializer)` (`Blizzard_SettingsLayouts.lua:33`). The `addSearchTags` argument is asserted non-nil (`:1046`), so pass `true` or `false` explicitly. Section headers: `CreateSettingsListSectionHeaderInitializer(name, tooltip)` (`:131-134`). Sub-options indented under a parent: `initializer:SetParentInitializer(parent, predicate)` (`:143`).
- `C_SettingsUtil.OpenSettingsPanel(categoryID, scrollToElementName)` carries `HasRestrictions = true` (`SettingsUtilDocumentation.lua:15-24`); what the restriction is (combat? hardware event?) is not stated in the docs. Blizzard's own UI calls `Settings.OpenToCategory` from addon-visible UI (`WUI\Blizzard_Communities\CommunitiesTabs.lua:14`, `Blizzard_Channels\Classic\ChannelFrame.lua:413`). MEDIUM: call it only from a click, and not while `InCombatLockdown()`.

### Recommended registration (one new file, `Settings.lua`, after `ItemLevel.lua` in the TOC)

```lua
EventUtil.ContinueOnAddOnLoaded("TerribleGroupFinder", function()       -- DB exists by now
  local category = Settings.RegisterVerticalLayoutCategory("TerribleGroupFinder")
  local function AddBox(key, label, tip, onChange)
    local s = Settings.RegisterAddOnSetting(category, "TGF_" .. key:upper(), key, TerribleGroupFinderDB,
      Settings.VarType.Boolean, label, Settings.Default.True)
    if onChange then s:SetValueChangedCallback(function(_, v) onChange(v) end) end
    return Settings.CreateCheckbox(category, s, tip)
  end
  -- player tooltip, item tooltip, character sheet, Inspect, Dynamic refresh, swipes, region flags
  local layout = select(2, ...) -- RegisterVerticalLayoutCategory returns category, layout
  layout:AddInitializer(CreateSettingsButtonInitializer("", "Open Messages", OpenMessages, tip, false))
  Settings.RegisterAddOnCategory(category)
  ns.settingsCategoryID = category:GetID()
end)
```

Notes:

- `RegisterVerticalLayoutCategory` returns `category, layout` (readme `:12-18`); keep both.
- Variable names (`"TGF_..."`) must be unique across all addons; prefix them. `variableKey` is the key inside `TerribleGroupFinderDB` (default to `true` for display extras so they work out of the box; Dynamic refresh stays default false per CLAUDE.md "off by default").
- The saved variable must be a table at registration. `Core.lua` creates `TerribleGroupFinderDB` on `ADDON_LOADED`; register after that (the readme example uses `EventUtil.ContinueOnAddOnLoaded`, `:62-69`). Registering from the same `ADDON_LOADED` is fine.
- Dynamic refresh dependent options: make "Swipe animations" a child of "Dynamic refresh" with `SetParentInitializer(parent, function() return DB.autoRefresh end)` so it greys out instead of silently doing nothing.
- "Open the finder on Messages" button: `buttonClick` should call a function in `UI/InPlace.lua` (new `IP.OpenMessages()`): out of combat, `ShowUIPanel(LFGParentFrame)` (or `LFGVanilla_ShowFrame(2)`, `WUI\Blizzard_GroupFinder_VanillaStyle\Blizzard_LFGVanilla_ParentFrame.lua:106-120`), then the existing local `ShowMessages()` (`UI/InPlace.lua:222-232`). Order matters: `LFGParentFrameMixin:OnShow` re-selects the stored tab (`:37-46`) and our `HookScript("OnShow", HideMessages)` on the stock tabs hides Messages, so `ShowMessages()` must run last. Preview mode (no stock finder) shows the stand-in on its Messages tab instead. Optionally `HideUIPanel(SettingsPanel)` first so the two windows do not overlap.
- Open the settings from our side: `Settings.OpenToCategory(ns.settingsCategoryID)` for `/tgf settings` (the task's "settings window"). The Settings panel is the native look; no custom skin needed.

What NOT to use:

- A custom options frame or `InterfaceOptions_AddCategory` (retired on the modern client; the Settings API replaced it).
- `RegisterCanvasLayoutCategory`: only needed for free-form layouts; the vertical layout gives checkboxes, a button, a header and tooltips for free and matches the stock panel.
- Writing `Settings.*` tables or `SettingsPanel` fields directly (`SettingsPanel:GetLayout` is used internally by `CreateCheckbox`, `Blizzard_Settings.lua:380-386`; do not touch it).
- Proxy settings for plain booleans: an AddOn setting writes the saved table directly and default-fills it, with less code.

### Needs an in-game check
- That the AddOns tab shows our category on Forever's panel, `OpenToCategory` lands on it, and `HasRestrictions` does not block opening from a click. HIGH confidence the code paths are shared with the retail panel; the Camelot-specific part (`Camelot\NewDefinitions.lua`) only lists new-setting tags.

## (e) AnimationGroup APIs for row animations

### Verified API

- `Frame:CreateAnimationGroup()` / `group:CreateAnimation("Translation" | "Alpha")` (`WUI\Blizzard_APIDocumentationGenerated\SimpleAnimGroupAPIDocumentation.lua:10-26`: `CreateAnimation(animationType, name, templateName)`, flagged `ChecksForbiddenAspects AddAnimations`, so it is not allowed on forbidden frames; ours are not).
- Base animation: `SetDuration`, `SetOrder`, `SetStartDelay`, `SetEndDelay`, `SetSmoothing` (`"IN"`, `"OUT"`, `"IN_OUT"`, `"NONE"`), `SetScript` (`SimpleAnimAPIDocumentation.lua:308-396`). Group: `Play`, `Stop`, `Finish`, `SetToFinalAlpha(bool)`, `SetLooping`, `SetScript("OnFinished" ...)` (`SimpleAnimGroupAPIDocumentation.lua:276-359`).
- `Translation:SetOffset(x, y)` / `GetOffset` (`SimpleAnimTranslationAPIDocumentation.lua:10-35`); `Alpha:SetFromAlpha/SetToAlpha(normalizedAlpha)` (`SimpleAnimAlphaAPIDocumentation.lua:38-60`). All have `SecretArguments = "AllowedWhenUntainted"`: pass plain numbers only.

### Semantics that matter for ScrollBox rows

- Animations are render-time offsets; they do **not** change the row's anchors. That is why they are safe inside a ScrollBox: the view lays rows out with anchors (`ScrollBoxListLinearView`), recycling frames from a pool, and an animation neither fights that layout nor moves the frame's logical rect. Never animate by `SetPoint` on a pooled row: the next `FullUpdate` re-anchors it and the row snaps.
- Finished Translation/Alpha effects are reset when the group ends; set `group:SetToFinalAlpha(true)` for fade-outs so a swiped-out row stays invisible until the data update removes it (the prototype already does this, `UI/Table.lua:1862`).
- A zero-duration first-order animation is the established way to apply a starting offset, then the second order animates away from it (prototype pattern, `UI/Table.lua:1844-1861`: `shift` order 1 duration 0, `move` order 2).
- ScrollBox frames are pooled: when the list scrolls or refreshes, a frame can be reused for another element. Stop the group in the row's reset/bind (already done at `UI/Table.lua:1144-1146`). Extra safeguard: on `OnFinished` do nothing that depends on the row identity.
- Updates are immediate: `ScrollBoxListMixin:OnViewDataChanged` calls `FullUpdate(ScrollBoxConstants.UpdateImmediately)` (`WUI\Blizzard_SharedXML\Shared\Scroll\ScrollBox.lua:~710-714`; `ScrollBoxBaseMixin:FullUpdate`, `:133-144`). After `SetDataProvider` (or our `T.RefreshAll`) the new row positions are valid in the same frame, so frames can be measured right after the update.
- `ScrollBox:ForEachFrame(func)` (`ScrollBox.lua:594-596`; func receives `(frame, elementData)`) is what `SwipeRows` already uses; `ScrollBox:ForEachElementData`, `FindFrame` also exist for lookups.

### Recommended for "rows slide up when one leaves"

1. Before the list updates: for each visible row frame, store `frame:GetTop()` by `ns.Listings.Key(item)`.
2. Swipe out the leaving rows (existing), wait `T.SWIPE` (lengthen it; prototype `0.25`), then update the data.
3. After the update, for each visible row whose key was stored, `delta = oldTop - frame:GetTop()` (positive when it moved up). Play a group with `shift` (order 1, duration 0, offset `(0, -delta)`) and `move` (order 2, `(0, +delta)`, `SetSmoothing("OUT")`) so the row starts where it was and glides to its new place. Skip rows that were swiped in (they already have their own animation).
4. Preview mode: the stand-in uses `W.List` (a fallback list) where `ForEachFrame` may not exist; `SwipeRows` already checks `frame.CreateAnimationGroup`. To play swipes in preview, route the same helpers through `W.List`'s visible rows (its row frames are plain frames, so the same animation code works) and add a preview button or `/tgf swipe` that changes `ns.Preview` data between two sets.
5. Keep `pcall` around animation setup (the prototype does) so a forbidden-aspect or missing-API case cannot break the table.

What NOT to use: `UIFrameFade` or custom `OnUpdate` tween loops (more code, run per frame, fight ScrollBox layout), per-row `C_Timer` chains, and `AnimationGroup` on the ScrollBox frame itself (the whole list would move, including headers).

## Supporting references

| Item | Where | Use |
|------|-------|-----|
| `EventUtil.ContinueOnAddOnLoaded(name, cb)` | `WUI\Blizzard_SharedXML\EventUtil.lua:67-75` | Hook the LoD Inspect UI, register settings after our own load |
| `hooksecurefunc(obj, "Method", fn)` | engine | Post-hook for `UpdateStats`, `UpdateButtons`, `SetLevel` |
| `securecallfunction` | `TooltipDataHandler.lua:67` | Already applied to our tooltip callbacks by Blizzard; nothing to do |
| `LFGVanilla_ShowFrame(tab)` | `Blizzard_GroupFinder_VanillaStyle\Blizzard_LFGVanilla_ParentFrame.lua:106-120` | Open the finder (tab 2 = Browse, 3 = Who) before showing Messages |

## What NOT to Use (consolidated)

| Avoid | Why | Use Instead |
|-------|-----|-------------|
| Editing `PAPERDOLL_STATCATEGORIES` / `PAPERDOLL_STATINFO` | Secure code reads them on every sheet update; tainted entries taint that path and are hard to undo without reload | Post-hook `CharacterStatsPaneScrollBox:UpdateStats` + insert a stock `ITEMLEVEL` element |
| The legacy `CharacterStatsPane` / `PaperDollFrame_UpdateStatsInternal` | Not used on Forever (`GetStatsPane` returns the ScrollBox) | The ScrollBox pane |
| Replacing `InspectPaperDollFrameMixin` functions or editing `InspectLevelText` | Taint and layout collisions | New FontString parented to `InspectPaperDollFrame`, refreshed from `hooksecurefunc` |
| Item-level line from a tooltip post-call or `OnTooltipSetItem` | Wrong position / event no longer exists in the data-processor pipeline | `AddLinePostCall(ItemName)` |
| Adding a second "Item Level" line without scanning `lines` | Possible duplicate if Forever's data carries the `ItemLevel` line (type 31) | Scan `tooltipData.lines` first |
| Own options window, `InterfaceOptions_AddCategory` | Not native; legacy API | `Settings.RegisterVerticalLayoutCategory` family |
| Anchor-moving or alpha-fading rows by hand | ScrollBox re-anchors pooled frames; snaps | Translation + Alpha animation groups |
| Reading `lineData.leftText` / unit data in combat without `issecretvalue` | Secret values error on arithmetic/concat | Guard every external value (existing project rule) |

## Version Compatibility

| Piece | Compatible with | Notes |
|-------|-----------------|-------|
| Interface 16001, game type `camelot` | `WUI` branch `forever` | All paths above are from that branch; Mainline folders are shown only where Forever loads them via `[Family]` (Inspect Lua) |
| `CharacterStatsPaneScrollBox` hook | Camelot `CharacterFrame.lua` only | If a future Forever build drops the ScrollBox pane, `CharacterStatsPaneScrollBox` is nil: guard with `if CharacterStatsPaneScrollBox then`. No flavour-forked files: one guard, one code path |
| Settings API | Shared by retail and Forever | Same calls on both; no flavour switch needed |
| `TooltipDataProcessor` | Shared | Same on both |

## Needs an in-game check (consolidated)

1. Taint behaviour of the sheet hook (open / switch tabs / equip in and out of combat).
2. Whether Forever's item tooltip data already has an `ItemLevel` line (decides if the item tooltip feature is additive or a no-op).
3. Real size of `InspectFrame` and the best anchor for the top-right text.
4. `Settings.OpenToCategory` from a click while the finder is closed, and after a `/reload`.
5. `STAT_AVERAGE_ITEM_LEVEL` / `ITEM_LEVEL` text on Forever's locale.
6. Slide-up delta correctness when the list scrolls or sections collapse (rows hidden by collapse should not animate).

## Sources

All HIGH confidence unless flagged; local Blizzard source, branch `forever`:

- `WUI\Blizzard_UIPanels_Game\Camelot\PaperDollFrameConstants.lua:35-117`, `PaperDollFrame.lua:109-127, 392-395, 470-483, 1378-1405, 2403-2414`, `CharacterFrame.lua:823-825, 1036-1311`, `CharacterFrame.xml:131-234, 463-486`, `Blizzard_UIPanels_Game.toc:40-60`
- `WUI\Blizzard_SharedXML\DataProvider.lua:14-20`, `Shared\Scroll\ScrollBox.lua:133-144, 594-596, 666-714`
- `WUI\Blizzard_InspectUI\Blizzard_InspectUI.toc`, `Camelot\Blizzard_InspectUI.lua:35-152`, `Camelot\Blizzard_InspectUI.xml:13-90`, `Camelot\InspectPaperDollFrame.xml:56-90, 312-346`, `Mainline\InspectPaperDollFrame.lua`, `Mainline\Blizzard_InspectUI_Bootstrap.lua`
- `WUI\Blizzard_SharedXML\Mainline\SharedUIPanelTemplates.xml:660-721` (`ButtonFrameTemplate`, Inset)
- `WUI\Blizzard_SharedXMLGame\Tooltip\TooltipDataHandler.lua:1-340`, `TooltipDataRules.lua:130-177`, `TooltipUtil.lua:9-22`
- `WUI\Blizzard_APIDocumentationGenerated\TooltipInfoSharedDocumentation.lua:27-135`, `ItemDocumentation.lua:354-370, 659-679`, `ItemConstantsDocumentation.lua:269-281`, `PaperDollInfoDocumentation.lua:122-136`, `SettingsUtilDocumentation.lua:10-24`, `SimpleAnim*APIDocumentation.lua`
- `WUI\Blizzard_Settings_Shared\Blizzard_Settings.lua:119-233, 331-420`, `Blizzard_ImplementationReadme.lua`, `Blizzard_SettingsInbound.lua:80-165`, `Blizzard_Setting.lua:265-269, 405-436`, `Blizzard_SettingControls.lua:131-134, 1040-1053`, `Blizzard_SettingsLayouts.lua:19-48`, `Blizzard_SettingsPanel.lua:155-180`
- `WUI\Blizzard_GroupFinder_VanillaStyle\Blizzard_LFGVanilla_ParentFrame.lua:17-150`
- Repo: `ItemLevel.lua:81-145, 336-344, 551-578`, `UI/InPlace.lua:206-290, 360-378`, `UI/Table.lua:1144-1146, 1835-1892`

---
*Stack research for: v0.2 ILvL Info and Improved Refresh (TerribleGroupFinder)*
*Researched: 2026-11-14*
