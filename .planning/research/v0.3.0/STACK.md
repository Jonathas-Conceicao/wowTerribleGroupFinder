# Technology Stack: v0.3.0 (game APIs and Blizzard frames)

**Project:** TerribleGroupFinder v0.3.0 (Elite quest eye button, per-slot gear info, opt-in defaults)
**Researched:** 2026-11-24
**Source of truth:** `C:\Users\jonat\Repositories\wow-ui-source`, branch `forever` (read-only). Paths below are relative to `Interface/AddOns/`.
**Overall confidence:** HIGH for what the source shows; MEDIUM/LOW where it depends on server data or live behaviour (marked "VERIFY LIVE").

No new libraries. Everything is Blizzard frames, templates, `C_*` APIs and hooks. All code stays inside the existing taint rules (CLAUDE.md).

---

## 1. Headline findings (read this first)

1. **Retail's finder is not loaded on Forever.** `Blizzard_GroupFinder/Blizzard_GroupFinder.toc:10` says `## ExcludeLoadGameType: camelot`. So `LFGListUtil_FindQuestGroup` (`Blizzard_GroupFinder/Mainline/LFGList.lua:4594`), `LFGListFrame_BeginFindQuestGroup` (`:513`), `LFGListEntryCreation_SetAutoCreateMode` (`:1262`) and `LFGListUtil_GetQuestCategoryData` (which calls `C_LFGList.GetActivityIDForQuestID`, `:4564`) **do not exist** on Forever. Retail's "quest mode" prefill has no counterpart.
2. **Forever's finder has no quest path at all.** No `questID`, `SetSearchToQuestID`, or auto-create mode anywhere in `Blizzard_GroupFinder_VanillaStyle` (grep clean). `LFGListingMixin:CreateOrUpdateListing` (`Blizzard_LFGVanilla_Listing.lua:264-328`) passes only `activityIDs`, `newPlayerFriendly`, `generalPlaystyle`, `voiceMode`. No `questID` is sent.
3. **The description box cannot be written.** `Mainline/Blizzard_LFGVanilla_Listing.xml:615-617` (`LFGListingComment` ScrollFrame, `.Comment.EditBox`): `StoreSecureReference("LFGListingComment", self.EditBox)`, `SetSecurityDisableSetText()`, `SetSecurityDisablePaste()`. The engine reads it directly. **"Quest name as description" is not achievable by an addon: drop it or show it as a hint only.**
4. **Selecting category/activity on the Listing tab means writing to Blizzard's frame.** `LFGListingFrame:SetCategorySelection` / `:SetActivity` (`Blizzard_LFGVanilla_Listing.lua:342`, `:428`) write `self.categorySelection` / `self.activities`, which `CreateOrUpdateListing` reads before the restricted `C_LFGList.CreateListing` (`LFGListInfoDocumentation.lua:70`, `HasRestrictions = true`). Called from addon code those writes are tainted, so the Post click would likely be blocked (`ADDON_ACTION_BLOCKED`). This breaks CLAUDE.md's "never write fields on Blizzard's finder". **Do not call them.**
5. **Achievable route for the eye button:** open the finder on the **Listing** tab (precedent: `IP.OpenMessages` in `UI/InPlace.lua:434-457` calls `LFGVanilla_ShowFrame`), then show **our own** guidance overlay (hint with the quest name, suggested activity, glow on Blizzard's "Quests & Zones" category button). The player does category, activity and Post themselves.
6. **Forever already has socket art and an enchant-free paper doll.** Both `PaperDollItemSlotButton*Template` already contain a stock `SocketDisplay` (`Blizzard_UIPanels_Game/Camelot/PaperDollFrame.xml:91-152`) but `PaperDollItemSocketDisplayMixin:SetItem` only shows it for `PlayerIsTimerunning()` (`Camelot/PaperDollFrame.lua:3576-3579`). It is Blizzard's: do not unhide it. Build our own frames.

---

## 2. Feature 1: Elite quest "eye" button

### 2.1 Retail reference (what to look like)

| Item | Value | Source |
|------|-------|--------|
| Template | `QuestObjectiveFindGroupButtonTemplate`, `mixin="QuestObjectiveFindGroupButtonMixin"`, `motionScriptsWhileDisabled="true"`, size 30x30 | `Blizzard_ObjectiveTracker/Blizzard_ObjectiveTrackerShared.xml:65-66` |
| Eye icon atlas | `socialqueuing-icon-eye` on `parentKey="Icon"`, 13x13, anchor CENTER x=-1 | `Blizzard_ObjectiveTrackerShared.xml:69-74`; also `Blizzard_QuickJoin/QuickJoin.xml:29` |
| Button art | `NormalTexture file="Interface\Buttons\UI-SquareButton-Up"`, Pushed `UI-SquareButton-Down`, Disabled `UI-SquareButton-Disabled`, Highlight `Interface\Buttons\UI-Common-MouseHilight` ADD alpha .5 | `Blizzard_ObjectiveTrackerShared.xml:78-81` |
| Press feel | OnMouseDown: `Icon` re-pointed CENTER (-2,-1); OnMouseUp: CENTER (-1,0) | `Blizzard_ObjectiveTrackerShared.lua:186-196` |
| Tooltip | `GameTooltip:SetOwner(self)`; `AddLine(TOOLTIP_TRACKER_FIND_GROUP_BUTTON, HIGHLIGHT_FONT_COLOR:GetRGB())` | `Blizzard_ObjectiveTrackerShared.lua:198-203` |
| Placement | `block:AddRightEdgeFrame(self.findGroupButtonSettings, questID)`, settings `{ template, offsetX = 5, offsetY = 2 }` -> `frame:SetPoint("TOPRIGHT", block, 5, 2)` | `Blizzard_QuestObjectiveTracker.lua:13-17`, `:308-310`; `Blizzard_ObjectiveTrackerBlock.lua:347-373` |
| Click | `LFGListUtil_FindQuestGroup(questID, true)` (`isFromGreenEyeButton`) | `Blizzard_ObjectiveTrackerShared.lua:205-210` |

Confidence HIGH (source). `TOOLTIP_TRACKER_FIND_GROUP_BUTTON` is a GlobalString not present in this tree (only referenced at `Blizzard_ObjectiveTrackerShared.lua:200`): use it with a plain-text fallback. Atlas existence in the Forever client cannot be proven from source (no atlas DB in the tree): feature-test with `C_Texture.GetAtlasInfo("socialqueuing-icon-eye")` and fall back to a plain texture, as `W.AtlasMarkup` / `W.IconButton` already do.

### 2.2 Does Blizzard already show the eye on Forever? (VERIFY LIVE)

Forever's tracker is the same module with a Camelot override file: `Blizzard_ObjectiveTracker.toc:36` loads `[Game]/Blizzard_QuestObjectiveTrackerOverride.lua [AllowLoadGameType camelot]` (`Camelot/Blizzard_QuestObjectiveTrackerOverride.lua`: `CanShowTimerBar` -> false, `GetQuestTagText` -> `QuestUtilsOverrides.GetQuestTagText`). `QuestObjectiveTrackerMixin:UpdateSingle` (`Blizzard_QuestObjectiveTracker.lua:291`) still runs the stock `if QuestUtil.CanCreateQuestGroup(questID) then block:AddRightEdgeFrame(...)` (`:308`). `QuestUtil.CanCreateQuestGroup` caches `C_LFGList.CanCreateQuestGroup(questID)` (`Blizzard_FrameXMLUtil/Mainline/QuestUtils.lua:375-387`). Whether the server returns true for Forever quests is unknowable from source.

- If it returns **false** for elite quests: no stock eye, ours is the only one. (Expected: the user wants the addon to add it.)
- If it returns **true**: the stock eye appears, and clicking it calls the **nonexistent** global `LFGListUtil_FindQuestGroup` (Lua error). Mitigation: define `LFGListUtil_FindQuestGroup` ourselves (new global; replaces nothing, so no taint of Blizzard values) pointing at our open-finder function, and do **not** add a second button on blocks that already carry the stock one (`block.rightEdgeFrame` is a `QuestObjectiveFindGroupButtonMixin` frame). Probe with `/run print(C_LFGList.CanCreateQuestGroup(<id>))` for an elite quest.

### 2.3 Which quests get the button

All in `Blizzard_APIDocumentationGenerated/QuestLogDocumentation.lua` (verbatim names; all `SecretArguments = "AllowedWhenUntainted"`):

| API | Signature | Doc line |
|-----|-----------|----------|
| `C_QuestLog.IsEliteQuest` | `(questID number) -> isEliteQuest bool` | `:749` |
| `C_QuestLog.GetQuestTagInfo` | `(questID) -> info QuestTagInfo?` with fields `tagName`, `tagID`, `isElite?` ... | `:525`, struct `:1594-1606` |
| `Constants.QuestConsts.QUEST_INFO_ELITE_ID` | `= 1` | `QuestConstantsDocumentation.lua:149` |
| `C_QuestLog.GetSuggestedGroupSize` | `(questID) -> suggestedGroupSize number` | `:620` |
| `C_QuestLog.GetInfo` | `(questLogIndex) -> QuestInfo?` incl. `suggestedGroup`, `questID`, `isHeader`, `title` | `:191`, struct `:1547-1578` |
| `C_QuestLog.GetLogIndexForQuestID`, `GetTitleForQuestID`, `GetNumQuestLogEntries` | (see doc) | `:206`, `:668`, `:303` |

Forever's own tracker already identifies elites this way: `Blizzard_FrameXMLUtil/Camelot/QuestUtilsOverrides.lua:6-9` (`C_QuestLog.IsEliteQuest`) and `:20-26` (`tagInfo.tagID == Constants.QuestConsts.QUEST_INFO_ELITE_ID`; also DUNGEON, PVP, RAID tags). **Recommended predicate:** `IsEliteQuest(id) or tagID in {ELITE, DUNGEON, RAID} or GetSuggestedGroupSize(id) > 1` (OR-ed; the author said "elite/group"). Wrap in pcall + `issecretvalue` guards.

### 2.4 Hooking the tracker (taint-safe)

- Global module frame: `QuestObjectiveTracker` (`Blizzard_QuestObjectiveTracker.xml`, `<Frame name="QuestObjectiveTracker" mixin="QuestObjectiveTrackerMixin" ...>`). The instance owns copied mixin functions, so hook the **instance**: `hooksecurefunc(QuestObjectiveTracker, "UpdateSingle", fn)` (fn receives `(self, quest)`; `quest:GetID()`), not the mixin table. `LayoutContents` reads `self.UpdateSingle` at call time (`:412`) so the hook runs.
- Block lookup: `QuestObjectiveTracker:GetExistingBlock(questID)` (`Blizzard_ObjectiveTrackerModule.lua:292`); block fields read-only: `block.id` (`:272`), `block.HeaderText`, `block.rightEdgeFrame`, `block.rightEdgeOffset` (`Blizzard_ObjectiveTrackerBlock.lua:24-33`, `:156`, `:198`).
- Blocks are pooled (`ObjectiveTrackerManager:AcquireFrame`, `Module.lua:248-252`) and reused for other quests: our button must be our own frame, `SetUp(questID)` on every `UpdateSingle`, hidden when the block is freed/reused for a non-qualifying quest. Parent it to the block (our own child frame; do not use `AddRightEdgeFrame`/`GetRightEdgeFrame`: they write `block.rightEdgeFrame`, `rightEdgeOffset` and the module's `usedRightEdgeFrames`, and `AdjustRightEdgeOffset` even `assert(not self.lastRegion)`, `Block.lua:337-341`, so it cannot run after the layout from a post-hook anyway).
- **Space reservation problem:** the header and every objective line are anchored `RIGHT` at `block.rightEdgeOffset` (`Block.lua:156`, `:198`); a post-hook cannot widen that reservation through Blizzard's API, so a button anchored at `TOPRIGHT` will overlap the title end. Options (decide in phase research / live test): (a) anchor ours to the left of `block.rightEdgeFrame` when present, else `TOPRIGHT` (5,2), accept overlap on long titles; (b) re-point `block.HeaderText`'s `RIGHT` anchor by ~-30 px after the hook (anchors only, same accepted class as the Item Level row's stat-row anchor moves; the next layout pass resets it through `SetHeader`). Prefer (b) only if it survives layout passes without flicker. LOW confidence: needs live check.
- Events that re-run the layout: `QUEST_LOG_UPDATE`, `QUEST_WATCH_LIST_CHANGED`, `SUPER_TRACKING_CHANGED` etc. (`Blizzard_QuestObjectiveTracker.lua:3`). The hook on `UpdateSingle` covers all; no separate event needed. Out of combat only for the click (opening finder), not for drawing.
- Do not hook other trackers (Bonus/Scenario also use the template, `Blizzard_BonusObjectiveTracker.lua:16`, `:343`); the milestone says tracker quests only. `CampaignQuestObjectiveTracker` exists but is irrelevant on Forever (`ShouldDisplayQuest` filters Campaign out, `:415-421`).

### 2.5 Opening the finder "ready to create a group for the quest"

Available (all Blizzard globals, called already by the addon or the game):

| Call | What | Source | Taint note |
|------|------|--------|-----------|
| `LFGVanilla_ShowFrame(tab)` | `ShowUIPanel(LFGParentFrame)` then tab 1/2/3 via `LFGParentFrameTab{1,2,3}_OnClick` | `Blizzard_GroupFinder_VanillaStyle/Blizzard_LFGVanilla_ParentFrame.lua:107-120` | Used by addon already (`UI/InPlace.lua:449`). Out of combat. |
| `LFGVanilla_ToggleFrame(tab)` | toggles; also gates on `C_LFGList.GetPremadeGroupFinderStyle() == Enum.PremadeGroupFinderStyle.Vanilla` and `C_LFGInfo.CanPlayerUsePremadeGroup()` | `ParentFrame.lua:122-149` | Prefer `ToggleFrame`-style gating checks before `ShowFrame`. |
| `GroupFinderVanillaStyle_LoadUI()` | `LoadAddOnWithErrorHandling("Blizzard_GroupFinder_VanillaStyle")`; the finder is **LoadOnDemand** | `Blizzard_GroupFinder_VanillaStyle_Bootstrap.lua:3-5`, TOC `LoadOnDemand: 1` | Call it if `LFGParentFrame` is nil. |
| `LFGParentFrame_SearchActiveEntry()` | switches to Browse for the active entry | `ParentFrame.lua:167-170` | Not needed. |
| `C_LFGList.HasActiveEntryInfo()` | already listed? Retail asks to delist first (`LFGListUtil_FindQuestGroup`); on Forever, tab 1 shows the edit state | used `ParentFrame.lua:77` | Read-only. |
| `C_LFGList.GetAvailableCategories()`, `C_LFGList.GetAvailableActivities(categoryID, activityGroupID)`, `C_LFGList.GetActivityInfoTable(activityID[, questID])`, `C_LFGList.GetLfgCategoryInfo(categoryID)` | enumerate Quests & Zones (116) | called by stock: `Blizzard_LFGVanilla_Listing.lua:763-790`, `ParentFrame.lua:235-262`; doc `LFGListInfoDocumentation.lua:184`, `:334`. `GetAvailableCategories/GetAvailableActivities` are undocumented but used by stock code. | Read-only. |

Constants: Quests & Zones category = **116** (`LFGLISTING_QUEST_CATEGORY_ID`, local in `Mainline/LFGVanilla_Constants.lua:12`; not global, so hard-code 116 and verify via `GetLfgCategoryInfo(116)` returning a table). Category art atlas `groupfinder-button-questing` (`:19`).

**What we CAN NOT do (and why):**

| Wanted | Verdict | Evidence |
|--------|---------|----------|
| Pre-select category 116 | NO (taint, see 1.4) | `LFGListingFrame:SetCategorySelection` writes `self.categorySelection` (`Listing.lua:342-348`); Blizzard's own button does it from a secure click (`LFGListingCategorySelectionButton_OnClick`, `:805-808`). |
| Pre-select the quest's activity | NO (taint) | `SetActivity` writes `self.activities[...]` and `selectedActivities` (`:428-451`); read by `CreateOrUpdateListing` (`:264-300`) before restricted `CreateListing`. |
| Fill the description with quest name | NO (secure box) | `Listing.xml:615-617`. `C_LFGList.SetEntryTitle` is `HasRestrictions = true` (`LFGListInfoDocumentation.lua:589-591`). |
| Pass `questID` to `CreateListing` | NO | Restricted; stock Forever UI never sends it (`LfgListingCreateData.questID` exists, `:957` doc; unused by stock Forever code). |
| Use `C_LFGList.GetActivityIDForQuestID` | UNKNOWN | Not in generated docs, only called from the unloaded retail file (`LFGList.lua:4564`). Feature-test `type(C_LFGList.GetActivityIDForQuestID) == "function"` at runtime; never rely on it. |
| `C_LFGList.SetSearchToQuestID(questID)` | Documented (`LFGListInfoDocumentation.lua:613`, not restricted) but Forever's Browse never uses it and `LFGBrowse_DoSearch` calls `C_LFGList.Search` with explicit args (`Browse.lua:331-352`). Do not use; do not call `LFGBrowse_DoSearch`/`ShowSearchForActivities` from addon code (tainted `Search` is `HasRestrictions`, `:572-574`). |
| Fire `LFG_LIST_SHOW_SEARCH` | NO | Engine event, handled at `Browse.lua:156-161`. |

**Recommended design (guidance, not automation):**
1. Click -> out of combat check -> load finder if needed -> `LFGVanilla_ShowFrame(1)` (Listing tab) -> let the stock category view show.
2. Our own overlay frame parented to `LFGListingFrame` (parent only; allowed by CLAUDE.md "parent our own frames to it"): quest name and the suggested zone/activity ("Select: Elwynn Forest"), cleared on `OnHide`/tab change/combat.
3. Visual cue: a glow on the stock category button where `button.categoryID == 116` (`LFGListingCategorySelection_AddButton` sets `button.categoryID`, `Listing.lua:779-797`; buttons in `LFGListingFrame.CategoryView.CategoryButtons`, `Listing.xml:520`). Add our own texture child; never touch their fields beyond reading.
4. Optionally mark the matching activity row after the player picks category 116: the activity list is a pooled ScrollBox (`LFGListingActivityView_InitActivityButton`, `Listing.lua:1108-1160`; row has `.NameButton.Name`, `.CheckButton`); `hooksecurefunc("LFGListingActivityView_InitActivityButton", fn(button, elementData))` gives `elementData.activityID`, `.name`; add our own highlight texture and clear it on each re-init (pooled rows).
5. Mapping quest -> activity (VERIFY LIVE): there is no API. Use `C_LFGList.GetActivityInfoTable(activityID)` fields `fullName`, `shortName`, `mapID`, `categoryID` (`LFGListInfoDocumentation.lua:873-903`) for activities from `C_LFGList.GetAvailableActivities(116)`, matched by zone name: the quest's zone is the nearest preceding `isHeader` entry of `C_QuestLog.GetInfo(i)` (walk back from `GetLogIndexForQuestID`), compared with `GetActivityInfoTable(id).fullName/shortName` (the finder shows `shortName` if non-empty, `LFGUtil_GetActivityInfoName`, `Blizzard_LFGUtil` / `Listing.lua:1114`). Alternative `C_QuestLog.GetMapForQuestPOIs()` (no args, `QuestLogDocumentation.lua:222`) returns only the POI map. If `activityInfo.mapID` equals the map (`C_Map` ids), prefer that. LOW confidence until the activity list for 116 is dumped in game (one `/tgf` probe).
6. `autoChooseActivity` (`LfgCategoryData`, `:927`): if true for 116 the Listing's ActivityView hides the scroll list and **requires** a comment (`Listing.lua:893-904`, `commentRequired = true`). Then the player types the quest name themselves. Show our hint next to that box: "Suggested description: <quest name>". We cannot set it. Check `C_LFGList.GetLfgCategoryInfo(116).autoChooseActivity` live: it decides how simple the flow is.

**Scope note for the roadmap:** requirement text "quest's map/activity selected and quest name as description, as far as secure box and restricted calls allow" resolves to: open Listing tab + our hint/glow overlay. No automated selection or description. Surface this to the author in the phase plan.

---

## 3. Feature 2: per-slot gear info

### 3.1 Frames and slot buttons

**Character sheet** (`Blizzard_UIPanels_Game`, Camelot files; TOC lines 42-60 load `[Game]\PaperDollFrame.lua/.xml` for camelot):

| Thing | Name | Source |
|-------|------|--------|
| Slot buttons (globals) | `CharacterHeadSlot`, `NeckSlot`, `ShoulderSlot`, `BackSlot`, `ChestSlot`, `ShirtSlot`, `TabardSlot`, `WristSlot`, `HandsSlot`, `WaistSlot`, `LegsSlot`, `FeetSlot`, `Finger0Slot`, `Finger1Slot`, `Trinket0Slot`, `Trinket1Slot`, `MainHandSlot`, `SecondaryHandSlot`, `RangedSlot`, `AmmoSlot` (`Character*Slot`) | `Camelot/PaperDollFrame.xml:779-873` |
| Templates | `PaperDollItemSlotButtonLeftTemplate` (parentArray `EquipmentSlots`, left column, stock SocketDisplay anchored `RIGHT x=7`), `...RightTemplate` (right column, `LEFT x=-7`), `...BottomTemplate` (parentArray `WeaponSlots`, `TOP y=7`) | `PaperDollFrame.xml:128-165` |
| Slot ID | `button:GetID()` set from `C_PaperDollInfo.GetInventorySlotInfo(slotName)` in `PaperDollItemSlotButton_OnLoad` | `Camelot/PaperDollFrame.lua:1919-1960`; `C_PaperDollInfo.GetInventorySlotInfo` doc `PaperDollInfoDocumentation.lua:164-180` |
| Column arrays | `PaperDollFrame.ItemsFrame.EquipmentSlots` (used `PaperDollFrame.lua:1752`), `WeaponSlots` | xml parentArray |
| Update entry | global `PaperDollItemSlotButton_Update(self)` (`:2177`); events `PLAYER_EQUIPMENT_CHANGED`, `UNIT_INVENTORY_CHANGED`, `BAG_UPDATE`, `ITEM_LOCK_CHANGED` handled by the slot's `OnEvent` (`:2050-2075`) | |
| Sheet show | `PaperDollFrame_OnShow(self)` (`:1511`) | |
| Stock gem display | `button.SocketDisplay` (`PaperDollItemSocketDisplayMixin:SetItem`, timerunning only) | `:3574-3606`, atlas `character-emptysocket` (`PaperDollFrame.xml:95`), 11x11 |
| Gear slot border atlas | `UI-Character-Info-GearSlot` (`PaperDollFrame.xml:67`); small `UI-Character-Info-GearSlotSmall` (ammo) | |

Hook with `hooksecurefunc("PaperDollItemSlotButton_Update", fn(button))` (global function; hooking is allowed) and draw our own overlay frames as **children of each slot button** (`CreateFrame("Frame", nil, button)`); never touch `ignoreTexture`, `SocketDisplay`, `IconBorder`, `popoutButton`. Already-present addon conventions apply (`pcall`-guarded installer, Settings key read where it acts, redraw on setting change).

**Inspect window** (`Blizzard_InspectUI`, TOC loads `[Game]\...` Camelot for camelot; `LoadOnDemand`):

| Thing | Name | Source |
|-------|------|--------|
| Slot buttons | `InspectHeadSlot`, `InspectNeckSlot`, `InspectShoulderSlot`, `InspectBackSlot`, `InspectChestSlot`, `InspectShirtSlot`, `InspectTabardSlot`, `InspectWristSlot`, `InspectHandsSlot`, `InspectWaistSlot`, `InspectLegsSlot`, `InspectFeetSlot`, `InspectFinger0/1Slot`, `InspectTrinket0/1Slot`, `InspectMainHandSlot`, `InspectSecondaryHandSlot`, `InspectRangedSlot` | list: `Blizzard_InspectUI/Camelot/Blizzard_InspectUI.lua:13-33` (`INSPECTPAPERDOLLFRAME_SLOTS` global); xml `Camelot/InspectPaperDollFrame.xml:54-165` |
| Template | `InspectPaperDollItemSlotButtonTemplate` (no `SocketDisplay` in Camelot's template) + Left/Right/Bottom variants | `InspectPaperDollFrame.xml:1-50` |
| Update entry | `InspectPaperDollItemSlotButton_Update(button)` reads `GetInventoryItemTexture(unit, button:GetID())` etc. (unit = `InspectFrame.unit`) | `Mainline/InspectPaperDollFrame.lua:245-273` (loaded on camelot per TOC: `[Family]\InspectPaperDollFrame.lua [AllowLoadGameType mainline]`) |
| Frame level update | `InspectPaperDollFrameMixin:UpdateButtons()` (`:63`), `:SetLevel()` (`:29`), `:OnShow()` (`:81`); the existing addon already hooks `UpdateButtons` and `SetLevel` (`ItemLevelUI.lua:~340`) | reuse that hook point |
| Unit/ready flow | `InspectFrame.unit` set in `InspectFrame_Show(unit)` (`Camelot/Blizzard_InspectUI.lua:41-50`); `INSPECT_READY` handler `:87-100` (`UnitGUID(inspectUnit) == guid` then `ShowUIPanel(InspectFrame)`); `UnitChanged` `:124` | |
| Window sizes / unit change | `InspectFrameMixin:OnEvent` hides the frame on `PLAYER_TARGET_CHANGED` / `GROUP_ROSTER_UPDATE` (`:104-110`) | clear overlays in `InspectFrame:HookScript("OnHide")` (already done for the text) |

The existing Inspect installer pattern (`EventUtil.ContinueOnAddOnLoaded("Blizzard_InspectUI", ...)`, `ItemLevelUI.lua:352`) is the one to extend: after load, create one overlay set per `INSPECTPAPERDOLLFRAME_SLOTS` name via `_G[name]`.

### 3.2 Data APIs (per slot)

Verbatim from `Blizzard_APIDocumentationGenerated` (all `SecretArguments = "AllowedWhenUntainted"` unless stated):

| API | Signature | Returns | Doc |
|-----|-----------|---------|-----|
| `GetInventoryItemLink(unit, slot)` | classic global (used by `ItemLevel.lua:337`) | item hyperlink or nil; values can be secret on this client -> `issecretvalue` guard as `ItemLevel.Read` does | stock use `InspectPaperDollFrame.lua:224` |
| `C_Item.GetDetailedItemLevelInfo(itemInfo)` | `itemInfo` = link/ID | `actualItemLevel, previewLevel bool, sparseItemLevel` (MayReturnNothing) | `ItemDocumentation.lua:354-367` |
| `C_Item.GetCurrentItemLevel(itemLocation)` | `ItemLocation` mixin | `currentItemLevel?` | `:292` (player only: `ItemLocation:CreateFromEquipmentSlot(slot)`; not for inspected units) |
| `C_Item.GetItemNumSockets(itemInfo)` | link/ID | `socketCount number` | `:876-889` |
| `C_Item.GetItemGemID(itemInfo, index)` | `index` luaIndex | `gemID number` (MayReturnNothing; "can get gemID without gem loaded in sparse", stock comment `PaperDollFrame.lua:3590`) | `:534-548` |
| `C_Item.GetItemGem(hyperlink, index)` | cstring link | `gemName, gemLink` | `:516-531` |
| `C_Item.GetItemIconByID(itemID)` | | icon | stock use `PaperDollFrame.lua:3604` (the stock gem icon path) |
| `C_Item.GetItemStats(itemLink)` | | stat table (may include `EMPTY_SOCKET_*` keys for open sockets) | `:1004-1017` |
| `C_Item.GetItemInfoInstant(link)` | | `..., classID, subclassID` | `:659`; already used by `ItemLevel.lua:342` |
| `C_Item.GetItemInfo(link)` | | quality is 3rd return (used `ItemLevel.lua:346`) | `:626` |
| `Item:CreateFromItemID(id)` + `:ContinueOnItemLoad(cb)` / `:IsItemDataCached()` | async load for gem icons | stock pattern `PaperDollFrame.lua:3593-3605` |
| `C_TooltipInfo.GetInventoryItem(unit, slot, hideUselessStats)` | `-> data TooltipData` (MayReturnNothing) | lines with `type`; enchant line type `Enum.TooltipDataLineType.ItemEnchantmentPermanent = 15`; gem sockets `GemSocketEnchantment = 30` | `TooltipInfoDocumentation.lua:389-405`; `TooltipInfoSharedDocumentation.lua:49`, `:64` |
| `C_Item.GetWeaponEnchantInfo()` | temporary weapon enchants (poisons/oils) -> `WeaponEnchantInfo { hasEnchant, enchantType, enchantID, enchantIconID, ... }` | not permanent enchants; skip | `ItemDocumentation.lua:1141`, `:1968-1977` |

Already-built reusable piece: `ILvl.Read(unit)` (`ItemLevel.lua:~332-372`) loops slots 1..19, returns `slots[slot] = { level, kind, heirloom }` with all `Secret()` guards and item-load tracking (`pending`, `complete`). **Extend it (or add a sibling reader sharing the same guards) to also return per-slot `link`, `enchantID`, `numSockets`, `gems[i]`.** Note the session cache by GUID currently stores only aggregates (`known[guid] = { ilvl, source, talents, ... }`, `ItemLevel.lua:~97-100`); per-slot data is read live from the unit at draw time (inspect data stays valid while the Inspect window shows that unit); do not cache per-slot data across inspects (stale after `ClearInspectPlayer()`). Draw on the same signals as the Inspect text: `UpdateButtons`/`SetLevel` hooks + `ILvl.OnLearned` + `INSPECT_READY` + item-load callbacks.

**Enchant parsing:** item link layout `item:itemID:enchantID:gemID1:gemID2:gemID3:gemID4:suffixID:uniqueID:level:...`. `enchantID` = 2nd field after `item:` (empty string or `0` = none). Parse with `link:match("item:%d+:(%d*):(%d*):(%d*):(%d*):(%d*)")` after the secret check. HIGH confidence for the layout (long-standing client format; no source line in this tree, Blizzard's own socket UI relies on `GetItemGemID`). The enchant **name** has no Lua API from an enchantID; for the display text either show only a mark/count, or read the tooltip line (`C_TooltipInfo.GetInventoryItem`, type 15; `leftText` may need `TooltipUtil.SurfaceArgs`; wrap in pcall; for inspected units the tooltip data is valid only while inspect data is loaded). Recommend: mark only (a small coloured "E" / check texture + tooltip on hover using the tooltip line), name optional.

**"Missing enchant" rule (needs design decision, LOW confidence):** there is no API for "this slot can be enchanted". Forever is Vanilla-ruleset ("camelot"): player-enchantable slots there are head, shoulder, back, chest, wrist, hands, legs, feet, main/off hand (weapons), ranged (scopes)... and rings only for enchanters. Define a static, easily editable slot table in the addon (and make the player's own Enchanting skill, or `C_TradeSkillUI`, irrelevant), start conservative (back, chest, wrist, hands, legs, feet, main hand, off hand when a weapon, two-hander main hand) and verify with the author. Do not flag shirt/tabard/neck/trinkets/waist/rings.

**Missing-socket mark:** `GetItemNumSockets(link)` returns sockets on the link; a gem is present when `GetItemGemID(link, i)` returns a number. Whether Forever has gems at all is a ruleset question (the stock sheet only shows sockets for timerunning, `PaperDollFrame.lua:3576-3579`, suggesting gems are not a normal Forever feature): if `GetItemNumSockets` returns 0 for every equipped item in a live check, the sockets feature is a no-op on Forever. VERIFY LIVE before committing phase scope.

### 3.3 Atlases / textures for the per-slot overlays

Only atlases proven in source:

| Use | Atlas / texture | Source |
|-----|-----------------|--------|
| Empty socket | `character-emptysocket` (11x11) | `Camelot/PaperDollFrame.xml:95` |
| Gem icon | the gem's item icon via `C_Item.GetItemIconByID(gemID)` | `PaperDollFrame.lua:3604` |
| Slot border (context) | `UI-Character-Info-GearSlot` | `PaperDollFrame.xml:67` |
| Missing marker / enchant tick | none proven. Use plain text (`FontString`) or the existing `W.IconTag`/`W.AtlasMarkup` fallback path; candidates to feature-test only: `common-icon-redx`, `common-icon-checkmark` (not in source: **unverified**, always guard with `C_Texture.GetAtlasInfo`). `Interface\RaidFrame\ReadyCheck-NotReady` / `ReadyCheck-Ready` are old stable file textures (unverified in this tree). |
| Item level text | `GameFontNormalSmall` / `GameFontHighlightSmall` FontString with quality colour via `C_Item.GetItemQualityColor` (`ItemDocumentation.lua:921`) or `ITEM_QUALITY_COLORS` | |

### 3.4 Layout and taint rules for the overlays

- Overlay = our own `Frame` per slot button, `SetFrameLevel(button:GetFrameLevel() + n)`, `EnableMouse(false)` (tooltips: hover on the stock slot already works; add info to the stock tooltip via `TooltipDataProcessor` only if needed, already used by the addon).
- Anchor to the slot button's outer side (left column text to the right? No: left column slots have the model on their right, text must fit between slot and model; the stock SocketDisplay sits at `RIGHT x=7` on left slots and `LEFT x=-7` on right slots, so the room beside slots is already reserved for it): put item level as a small overlay on the icon's bottom corner (no layout cost), sockets/enchant along the existing stock SocketDisplay positions. Keep text 10-11 px; check against `CHARACTER_FRAME_WIDTH = 631` / collapsed `398` (`CharacterFrameConstants.lua:4-6`).
- Never write `button.*` fields, never `SetItem` on `SocketDisplay`, never replace `PaperDollItemSlotButton_Update`. Hooks only.
- Combat: slot data reads are fine in combat for yourself; for inspected units no inspect in combat (existing guard).
- Never call `NotifyInspect`/`ClearInspectPlayer` from the new code; piggy-back on the existing quiet queue (`ItemLevel.lua` 'quiet inspect queue') and on the Inspect window's own inspect (`ItemLevelUI.lua` `WindowGuid()`), which already avoids clearing while the window shows.
- Character sheet "Item Level" row overlap: none (separate frame, `ilvlCharacterSheet`).

---

## 4. Feature 3: opt-in defaults and Settings sections (no game API work)

Internal only (`Settings.lua`, `UI/SettingsPanel.lua`, `Core.lua` Migrate schema 4). API notes that matter:

- New keys must follow the existing registry (`ns.Settings.Register`, flat boolean keys, saved only once set). New keys proposed: `questFindGroupButton` (default on), `gearItemLevel`/`gearEnchants`/`gearSockets` (default off; names to be decided by requirements).
- `ns.Migrate` schema 4 (once, for a player whose table already held any key at load): save current effective values for every key whose new default is off, as v0.2.2's schema 3 did for `meterResetOnGroup` (`CLAUDE.md` Core description). New installs get the new defaults.
- Settings page order requested: Group finder, Player inspection (item level, talents, enchants, sockets), Damage meter, Messages. `SettingsPanel` already builds sections from `ns.Settings.List()` via `section`; reorder section declarations and rename "Item level and talents" -> "Player inspection". The Elite quest button belongs under "Group finder".
- The eye button's installer must read `ns.Settings.Get("questFindGroupButton")` where it acts (hook runs always, draws/hides based on the setting; `ns.Settings.OnChange` redraws the tracker via `QuestObjectiveTracker:MarkDirty()`? **No**: do not call Blizzard methods that mutate layout; hide our own frames instead and let the next natural layout pass re-run the hook).

---

## 5. Taint and secret-value checklist for the phases

| Rule | Applies to |
|------|-----------|
| Only `hooksecurefunc`, `HookScript`, our own child frames; no field writes on Blizzard frames/mixins | tracker block, slot buttons, finder |
| No `AddRightEdgeFrame` / `GetRightEdgeFrame` / `AcquireFrame` from addon code | tracker (writes module/block state, asserts) |
| No `LFGListingFrame:SetCategorySelection/SetActivity/ActivityFiltersChanged`, no `LFGBrowse_DoSearch`, no `C_LFGList.CreateListing/UpdateListing/Search/SetEntryTitle` | eye button |
| `C_LFGList.RemoveListing()` is already the single accepted call; do not add to it | |
| `LFGVanilla_ShowFrame` only out of combat; load via `GroupFinderVanillaStyle_LoadUI()` when `LFGParentFrame == nil`; honour `C_LFGList.GetPremadeGroupFinderStyle()` and `C_LFGInfo.CanPlayerUsePremadeGroup()` as `LFGVanilla_ToggleFrame` does (`ParentFrame.lua:136-139`) | eye click |
| `issecretvalue()` on every `GetInventoryItemLink/ID`, `C_QuestLog.*` result, and `C_TooltipInfo` field before use; pcall around `C_TooltipInfo` | gear + tracker |
| `GameTooltip` use: our own button tooltips may `SetOwner`/`AddLine` (as the stock button does); no `RefreshData` additions | |
| Never send addon messages in `C_ChatInfo.InChatMessagingLockdown()` | n/a (no messages here) |
| Hide, do not remove, the stock eye if it appears; do not hide Blizzard's `QuestObjectiveFindGroupButtonTemplate` frames (hide-and-hook is reserved for finder parts) | tracker |

---

## 6. What is MISSING on Forever vs retail (verified)

| Retail feature | Forever | Evidence |
|----------------|---------|----------|
| `LFGListUtil_FindQuestGroup`, `LFGListFrame_BeginFindQuestGroup`, `LFGListEntryCreation_SetAutoCreateMode("quest")` | absent (Blizzard_GroupFinder excluded) | `Blizzard_GroupFinder.toc:10` |
| `C_LFGList.GetActivityIDForQuestID` | not documented; only used by the unloaded file | `LFGList.lua:4564`; grep over docs: no match |
| Quest/title auto-fill in listing | absent | Listing XML secure box; no `questID` in VanillaStyle |
| `LFGListUtil_OpenBestWindow` | absent (noted in `Blizzard_QueueStatusFrame/Camelot/QueueStatusFrameOverrides.lua:3-4`) | |
| Gem/socket display on the character sheet | stock frames exist but timerunning only | `Camelot/PaperDollFrame.lua:3576-3579` |
| Enchant display on slots | none in Blizzard code | grep `PaperDollFrame.lua` (only enchanting-profession code) |
| Inspect SocketDisplay | absent in Camelot template (the `if button.SocketDisplay` guard exists in `InspectPaperDollItemSlotButton_Update:271` but the Camelot XML has none) | `Camelot/InspectPaperDollFrame.xml:1-50` |
| Global `QuestObjectiveFindGroupButtonTemplate` | PRESENT (shared file), but its click handler targets the missing global | `Blizzard_ObjectiveTrackerShared.xml:65`, `.lua:205-210` |

---

## 7. Verify-live checklist (one `/tgf` probe each; roadmap should schedule these early)

1. `C_LFGList.CanCreateQuestGroup(questID)` for an elite quest in the log (decides whether the stock eye appears and whether to define the `LFGListUtil_FindQuestGroup` shim).
2. `C_LFGList.GetAvailableActivities(116)` dump: `activityID`, `fullName`, `shortName`, `mapID`, `maxNumPlayers`, plus `C_LFGList.GetLfgCategoryInfo(116)` (`autoChooseActivity`).
3. `type(C_LFGList.GetActivityIDForQuestID)` and, if a function, its answer for an elite quest.
4. `C_Texture.GetAtlasInfo("socialqueuing-icon-eye")`, `"character-emptysocket"` presence.
5. `C_Item.GetItemNumSockets(link)` over all equipped items (is the sockets feature meaningful on Forever at all?).
6. Item link enchant field for an enchanted vs unenchanted item (confirm the parse and the tooltip line type 15 text).
7. Header overlap behaviour of the eye button on a long quest title (anchors-only RIGHT re-point survives layout passes?).

## Sources

- Forever UI source (branch `forever`): files and lines cited inline above (HIGH).
- Project docs: `CLAUDE.md`, `.planning/PROJECT.md` (Current Milestone v0.3.0), `UI/InPlace.lua:434-457`, `ItemLevel.lua`, `ItemLevelUI.lua` (existing integration points).
- Not verified outside the source tree: atlas names other than those cited in Blizzard XML, item-link field order (standard client format), Forever server-side quest/activity data (all marked VERIFY LIVE).
