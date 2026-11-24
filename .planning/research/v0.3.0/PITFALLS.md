# Pitfalls Research: v0.3.0 (opt-in defaults, Elite quest button, per-slot gear info)

**Domain:** WoW Forever addon (interface 16001, `camelot`, modern client with secret values and taint rules)
**Researched:** 2026-11-24
**Confidence:** MEDIUM-HIGH. Claims from the Blizzard source (`wow-ui-source`, branch `forever`) are HIGH. Runtime behaviour that only the live client can show (what `C_LFGList.CanCreateQuestGroup` returns on Forever, taint spread, anchors to protected buttons) is LOW and listed under "Needs a live check".

Paths: `B:` = `C:\Users\jonat\Repositories\wow-ui-source\Interface\AddOns`, `A:` = this repo. Phase names assume this split: **P-A** Opt-in defaults and migration, **P-B** Elite quest button, **P-C** Per-slot gear info, **P-D** Settings page restructure and Release Review.

---

## Critical Pitfalls

### Pitfall 1: The "quest name as description" cannot be written by an addon, and neither can the listing

**What goes wrong:** Planning assumes the button can open the Listing tab with category 116, the activity picked and the quest name typed in. Three separate walls stop it.
1. The description box rejects addon text. `LFGListingComment`'s EditBox calls `StoreSecureReference("LFGListingComment", ...)`, `SetSecurityDisableSetText()` and `SetSecurityDisablePaste()` (`B:Blizzard_GroupFinder_VanillaStyle/Mainline/Blizzard_LFGVanilla_Listing.xml:615-617`; same in `Classic/...xml:579-581`). `SetText` from any code does nothing, and paste is off. `OnTextChanged` only marks the listing dirty when `userInput` is true (`Blizzard_LFGVanilla_Listing.lua:1176-1179`), so even a working write would not enable posting.
2. `CreateOrUpdateListing` builds the create data from Blizzard's own `self.activities` table and passes no `questID` and no comment (`Blizzard_LFGVanilla_Listing.lua:264-322`, `CreateListing` at 315). The retail quest path (`LFGListFrame_BeginFindQuestGroup`, `B:Blizzard_GroupFinder/Mainline/LFGList.lua:513-536`) is not loaded on Forever (see Pitfall 3).
3. `CreateListing`, `UpdateListing` and `Search` are `HasRestrictions = true` (`B:Blizzard_APIDocumentationGenerated/LFGListInfoDocumentation.lua:70-73, 572-575, 633-636`).

**Why it happens:** The retail flow that makes "find group for this quest" work is secure Blizzard code (`issecure()` gate with a confirmation popup, `LFGList.lua:470-480`). Its Forever counterpart does not exist, and our code is always the insecure caller.

**Consequences:** Any route that makes the addon do the work either silently does nothing (SetText) or throws `ADDON_ACTION_BLOCKED` and taints later clicks (Pitfall 2).

**Prevention:** Decide in the phase plan that the button's whole job is *navigation plus a hint*, and drop the prefill from the requirement text:
- Open the finder with `LFGVanilla_ShowFrame(tab)` (`B:Blizzard_GroupFinder_VanillaStyle/Blizzard_LFGVanilla_ParentFrame.lua:107-120`). The existing `IP.OpenMessages` (`A:UI/InPlace.lua:434-457`) already does this safely: out of combat only, Settings panel guard, `LFGVanilla_ShowFrame` then our own tab.
- Show the quest name and the "Quests & Zones" step in our own frame/line (a small hint beside or under the Listing tab, with the name in a read-only `EditBox` of ours that the player selects and copies, or just plain text to type). Never in Blizzard's box.
- If the player is already listed (`C_LFGList.HasActiveEntryInfo()`), the Listing tab is the locked/update view, so open the Listing tab and say that updating or delisting comes first (retail shows `PREMADE_GROUP_SEARCH_DELIST_WARNING` for the same case, `LFGList.lua:4594-4604`). Do not call `RemoveListing`.

**Warning signs:** A plan task that says "set the description", "select the activity" or "press Find Group" programmatically; any call to `LFGListingFrame:*`, `LFGBrowseFrame:*`, `*.EditBox:SetText`.

**Phase to address:** P-B, in the plan's first task (settle the route before building the button). Update PROJECT.md's wording ("as far as the secure description box and restricted calls allow").

---

### Pitfall 2: Driving Blizzard's finder from addon code taints the player's own later Search/CreateListing

**What goes wrong:** To "open Browse with Quests & Zones and the quest's activity selected", the obvious code calls `LFGBrowseFrame:ShowSearchForActivities(ids)` / `SetSelectedSearchActivities(ids)`, `LFGBrowseFrame.CategoryDropdown:SetValue(116)`, `ActivityDropdown:ValueSetSelected(id, true)`, or `LFGListingFrame:SetCategorySelection(116)` / `SetActivity(...)`.

**Why it happens / evidence:**
- Those are secure mixin methods. Called from our insecure code, they run tainted: `SetValue` writes `self.selectedCategoryID` (`B:Blizzard_GroupFinder_VanillaStyle/Blizzard_LFGVanilla_Browse.lua:1089-1096`), `ValueSetSelected` writes the `selectedValues` list (`:1229-1246`), `SetCategorySelection` writes `categorySelection` and rebuilds `self.activities` (`Blizzard_LFGVanilla_Listing.lua:342-352, 260-290`). The addon is `Secure: 1` (`Blizzard_GroupFinder_VanillaStyle.toc`).
- `SetSelectedSearchActivities` and `ShowSearchForActivities` end in `LFGBrowse_DoSearch()` (`Browse.lua:247-285`), i.e. `C_LFGList.Search` from tainted execution: blocked, `ADDON_ACTION_BLOCKED`.
- The player's later clicks read the tainted slots: `LFGBrowse_DoSearch` passes `CategoryDropdown:GetValue()` and `ActivityDropdown.selectedValues` straight into `Search` (`Browse.lua:331-346`), and `CreateOrUpdateListing` iterates `self.activities` into `CreateListing` (`Listing.lua:264-322`). A tainted argument into a `HasRestrictions` call is a blocked call. The taint on a field clears only when secure code overwrites it (the player picking a value in the dropdown does), so the failure is intermittent and hard to attribute.
- `Button:Click()` on Blizzard's category buttons or `dropdown:Pick`-style helpers run the secure handler in our tainted context: same result.

**Prevention:**
- Hard rule for P-B: the button never calls a function on `LFGBrowseFrame`, `LFGListingFrame`, their dropdowns or buttons, and never writes a field of theirs. This is CLAUDE.md's taint rule applied to a new entry point; restate it in the plan.
- Allowed: `LFGVanilla_ShowFrame(n)` (precedent above), `HookScript`, our own frames. Guide the player instead: our hint says "Pick Quests & Zones, then the zone", with an optional highlight glow on Blizzard's dropdown drawn as *our own* texture parented to our own frame (never `dropdown:SetX`).
- Never "dynamic refresh" the finder in any way from the button (a timer `Search` is already known to be blocked, CLAUDE.md).

**Warning signs:** `ADDON_ACTION_BLOCKED` naming TerribleGroupFinder and `C_LFGList.Search` / `CreateListing`; the Post or Search button doing nothing right after the eye button was used; `/console taintLog 2` showing `selectedCategoryID` or `activities` tainted by the addon.

**Phase to address:** P-B (design) and the Release Review live check (open finder via eye, then post a listing and search by hand, with taintLog on).

---

### Pitfall 3: The stock tracker already has a find-group eye, and its click handler does not exist on Forever

**What goes wrong:** On Forever's own tracker the quest module already adds a retail "green eye" for any quest where `QuestUtil.CanCreateQuestGroup(questID)` is true: `findGroupButtonSettings` with `QuestObjectiveFindGroupButtonTemplate` (`B:Blizzard_ObjectiveTracker/Blizzard_QuestObjectiveTracker.lua:12-16`), added in `UpdateSingle` (`:308-310`; the bonus tracker does the same at `Blizzard_BonusObjectiveTracker.lua:343-345`). That button's `OnClick` calls `LFGListUtil_FindQuestGroup` (`Blizzard_ObjectiveTrackerShared.lua:205-209`), defined only in `Blizzard_GroupFinder` (`B:Blizzard_GroupFinder/Mainline/LFGList.lua:4594`), and that addon is `## ExcludeLoadGameType: camelot` (`Blizzard_GroupFinder.toc`). So if `C_LFGList.CanCreateQuestGroup` ever returns true on Forever, the stock eye shows and a click raises a Lua error (nil global), and ours would be a second eye beside it.

**Why it happens:** The tracker is the shared retail module; Forever's override file only adds tag text and disables timer bars (`B:Blizzard_ObjectiveTracker/Camelot/Blizzard_QuestObjectiveTrackerOverride.lua:1-7`).

**Prevention:**
- Live-check first: does a stock eye ever appear for a group quest on Forever? (`/dump QuestUtil.CanCreateQuestGroup(<id>)`, `/dump C_LFGList.CanCreateQuestGroup(<id>)`.) Record the answer in the plan.
- If it appears: ours must not duplicate. Hide nothing of Blizzard's (never write `block.rightEdgeFrame` or `Hide()` Blizzard's button; hooks only per CLAUDE.md). Options: place ours elsewhere on the row, or only show ours when `block.rightEdgeFrame` is not a find-group button (read-only check), or hook the stock button's `OnClick` via `HookScript` to also show a hint. Do not define a global `LFGListUtil_FindQuestGroup` shim (a write into the global namespace that Blizzard's secure code would then call from tainted code).
- If it never appears: nothing to dedupe, but guard anyway with the read-only check.
- Do not use `CanCreateQuestGroup` as the elite test (Pitfall 5).

**Warning signs:** Two eyes on one row; a Lua error `attempt to call global 'LFGListUtil_FindQuestGroup'` after clicking the stock one.

**Phase to address:** P-B, first task (live check), before the button's placement is finalised.

---

### Pitfall 4: Adding to a tracker block the way Blizzard does (`AddRightEdgeFrame`) or overlaying it carelessly

**What goes wrong:**
1. Calling `block:AddRightEdgeFrame(...)` from a post-hook asserts: `AdjustRightEdgeOffset` is `assert(not self.lastRegion)` ("must be done before setting any lines", `B:Blizzard_ObjectiveTracker/Blizzard_ObjectiveTrackerBlock.lua:337-341`), and in a post-hook the lines are already laid out. It would also write `usedRightEdgeFrames`/`block.rightEdgeFrame` state (Block.lua:347-370, `Blizzard_ObjectiveTrackerModule.lua:591-625`) from tainted code. Do not use it.
2. A plain overlay frame does not reserve room: the header and lines get their right edge from `block.rightEdgeOffset` (`Block.lua:156, 198`), which only `AddRightEdgeFrame` changes, so our eye sits on top of the quest title. A long title runs under it.
3. Blocks and right-edge frames are pooled and re-laid out on every update: `Block:Reset()` zeroes `rightEdgeOffset`/`rightEdgeFrame` (`Block.lua:24-37`), `GetBlock` reuses a block for a new `id`, `FreeBlock` releases it to a pool (`Module.lua:254-330`). A frame we attached once to "the block" will show on whichever quest the block holds next.
4. The module mixin is copied onto each instance (`CreateFromMixins`, and `CampaignQuestObjectiveTrackerMixin` copies `QuestObjectiveTrackerMixin`, `Blizzard_CampaignQuestObjectiveTracker.lua:7`). `hooksecurefunc(QuestObjectiveTrackerMixin, "UpdateSingle", f)` after the frames exist hooks nothing; hooking only `QuestObjectiveTracker` misses `CampaignQuestObjectiveTracker`. The update passes `self.UpdateSingle` as a bare callback (`QuestObjectiveTracker.lua:412`), so the hook must be installed on the instance before the next layout and cannot assume `self` equals a given module.
5. The quest item button sits in the same right-edge slot (`questItemButtonSettings`, `QuestObjectiveTracker.lua:309-311`) and is a context-bound button (`buttonContext = ButtonContext_TrackerQuestItem`, `Blizzard_ObjectiveTrackerShared.xml:4-8`). Treat it as protected in combat: anchoring our frame to it, or relying on its position, is a LOW-confidence taint/lockdown risk.

**Prevention:**
- One pooled button per block frame, keyed by the block (`weak`-keyed table), re-evaluated on **every** `UpdateSingle`/layout: show only when the block's current `block.id` (questID) is elite, else hide. Never trust last state.
- Hook instances: `hooksecurefunc(QuestObjectiveTracker, "UpdateSingle", ...)` and the campaign tracker's, installed at `PLAYER_LOGIN` once `Blizzard_ObjectiveTracker` is certain to be loaded (it is not load-on-demand, but verify) and with a pcall guard like the existing installers (`A:ItemLevelUI.lua:316-337`). Take the questID from the `quest` argument (`quest:GetID()`), the block from `self:GetExistingBlock(questID)` (read only).
- Anchor to the *block* (`TOPRIGHT`, small inset), never to `block.ItemButton`; accept that the title may run under the eye, or anchor it at the block's left of the item button using only fixed offsets. Decide visually in game; keep it out of the title via a short right gap only if the live check shows overlap.
- Parent to the block (non-protected) so it hides with it; make it a plain `Button` of ours with `RegisterForClicks("LeftButtonUp")`, no secure template.
- Do not create, show or re-anchor our frames during `InCombatLockdown()` if any anchor involves a protected frame; it is safe to just `SetShown` on our own frame in combat. The click handler returns early in combat (opening a UIPanel in combat is guarded already, `A:UI/InPlace.lua:439-441`).

**Warning signs:** Eyes on non-elite quests after a quest is turned in or the list reorders; eyes missing for campaign-module quests; eye drawn over the title; "script ran too long"/layout flicker if our hook triggers `ObjectiveTrackerManager:UpdateAll`-type work (never call it).

**Phase to address:** P-B.

---

### Pitfall 5: "Elite" is detected from the wrong field

**What goes wrong:** Using `suggestedGroup` (`QuestInfo.suggestedGroup`, `B:Blizzard_APIDocumentationGenerated/QuestLogDocumentation.lua:1557`), `Enum.QuestTag.Group` (value 1, `:1507`) or `CanCreateQuestGroup` to mean "elite quest". On Forever the game defines elite explicitly: `C_QuestLog.IsEliteQuest(questID)` (documented, `QuestLogDocumentation.lua:749`) is what Forever's quest title prefix uses (`B:Blizzard_FrameXMLUtil/Camelot/QuestUtilsOverrides.lua:6-9`, "[22+] "), and the tracker's "(Elite)" text comes from `QuestTagInfo.tagID == Constants.QuestConsts.QUEST_INFO_ELITE_ID` (`QuestUtilsOverrides.lua:19-26`; constant value 1 in `QuestConstantsDocumentation.lua:149`). `QuestTagInfo` also carries `isElite` (`QuestLogDocumentation.lua:1603`, nilable). Dungeon, PvP and raid tags are separate (`QUEST_INFO_DUNGEON_ID` etc.): those quests must not get an eye.

**Prevention:**
- Primary test: `C_QuestLog.IsEliteQuest(questID)` inside a `pcall`; fallback `C_QuestLog.GetQuestTagInfo(questID)` with `tagID == Constants.QuestConsts.QUEST_INFO_ELITE_ID`; require `type(x) == "boolean"` / number and `not issecretvalue(x)` before use (both functions are `SecretArguments = "AllowedWhenUntainted"`, so only pass a plain number questID, never a possibly secret one from a hook argument).
- Do not use the localized tag text ("(Elite)") to detect: it is localized (`PARENS_TEMPLATE:format(ELITE)`).
- Cache result per questID for the session (the stock code caches `CanCreateQuestGroup` the same way, `B:Blizzard_FrameXMLUtil/Mainline/QuestUtils.lua:375-389`, "result will not change until completed"); do not call from `OnUpdate`.
- Quest not in the log (a stale block during turn-in, `QUEST_TURNED_IN`): `IsEliteQuest` on an unknown id may return false or error; the pcall plus "false = no eye" handles it. Do not request quest data (`RequestLoadQuestByID`) from the layout path.

**Warning signs:** Eyes on every group-tagged dungeon quest; eye missing on a real elite quest right after login (quest data not loaded yet: re-run on `QUEST_LOG_UPDATE`, not once).

**Phase to address:** P-B.

---

### Pitfall 6: Quest to activity mapping does not exist in the Forever API docs, and the quest name may be unavailable

**What goes wrong:** Retail finds the activity through `C_LFGList.GetActivityIDForQuestID(questID)` (`B:Blizzard_GroupFinder/Mainline/LFGList.lua:4564`) and uses `QuestUtils_GetQuestName` (`B:Blizzard_FrameXMLUtil/Mainline/QuestUtils.lua:686-689`). On the `forever` branch `GetActivityIDForQuestID` appears nowhere in `Blizzard_APIDocumentationGenerated` (only the retail Lua uses it), while `CanCreateQuestGroup`, `SetSearchToQuestID` and `GetActivityInfoTable(activityID, questID?, ...)` are documented (`LFGListInfoDocumentation.lua:20, 184-200, 613`). Category 116 "Quests & Zones" is zone-based (`A:.planning/research/FOREVER-GROUPFINDER.md:185`); elite quests may have no activity of their own.

**Prevention:**
- Treat quest to activity as *unknown* until a live probe (extend `/tgf ilvl`-style probe: `/tgf quest <id>` printing `C_LFGList.GetActivityIDForQuestID` presence, `GetAvailableActivities(116)`, each activity's `mapID`, `fullName`, and `searchResult.questID` of live listings). Call every optional API through `type(fn) == "function"` and `pcall`.
- Do not guess from the localized zone name text (the quest's zone vs the activity's `fullName`); match on `mapID` if the probe shows it works, else do not pre-select anything (we cannot anyway, Pitfall 2) and only show the quest name in the hint.
- Quest name: `C_QuestLog.GetTitleForQuestID(questID)` (`QuestLogDocumentation.lua:668-682`, nilable) or the `quest.title` the tracker already passed; use the already-displayed title, strip our own tag suffix. It is the client's localization, which is exactly what other players of that realm see; do not translate or hardcode. If nil, show the hint without a name rather than an empty string.
- Quests without any activity in 116: still show the eye (the category exists), because the player can pick the zone manually; do not hide the eye based on a failed mapping.

**Warning signs:** Nil-call errors on login of a player where the API is absent; wrong zone suggested.

**Phase to address:** P-B (probe task before the hint text is finalised); list as a research flag.

---

### Pitfall 7: Schema 4 misclassifies new installs as existing players (or the reverse)

**What goes wrong:** The schema 3 precedent classifies "existing" as `next(db) ~= nil` taken at the top of `ns.Migrate` before any write (`A:Core.lua:37-46`), and Migrate runs before DEFAULTS are filled in (`A:Core.lua:285-294`). Ways to break it when adding a schema 4 step:
1. **Recomputing `existing` inside the new step.** The schema 3 branch ends with `db.schema = 3`, so the table is already non-empty when a second branch runs. A fresh install (empty table) would then look "existing" in step 4 and get every old default saved as `true`: the opt-in change would apply to nobody. Compute `existing` once, at the top, and share it.
2. **Using `Settings.Get`/`List()` defaults to build the preserved set.** After this milestone `Get` returns the *new* defaults (off), so "save what Get returns" saves false. Hard-code the v0.2.2 key list and its old default (true) in the migration: `ilvlPlayerTooltip, specPoints, ilvlItemTooltip, ilvlCharacterSheet, ilvlInspect, meterResetOnInstance` (`A:Settings.lua:122-185`). `meterResetOnGroup` is already handled by schema 3 and stays.
3. **Looping over every registered option** ("for each opt in List: if existing then save true"). That would switch *new-in-0.3.0* keys (the per-slot gear option, the Elite quest option) on for existing players. New keys have no old behaviour to preserve: they follow their new default for everyone.
4. **Overwriting an explicit choice.** Only save `true` where `type(db[key]) ~= "boolean"` (as schema 3 does for `meterResetOnGroup`, Core.lua:42). An explicit `false` stays.
5. **Treating "schema key present" as proof of use.** Every v0.2.x load writes `schema = 3` (`DEFAULTS`, Core.lua:25-27, 290-294), so a v0.2.2 player who installed and never opened Settings has a table with only `schema`. That is an existing player and must keep the on-by-default extras (their unsaved keys read as on today). Correct under the brief; make sure a test fixture covers it.
6. **A saved empty table.** A v0.1 player whose table has never held a key looks new. Accept (they have nothing to preserve) but note it.
7. **Order inside `ns.Migrate`.** The v0.1 cleanup keys (`gs`, `autoRefresh`) are cleared on every load; computing `existing` after clearing them would misclassify a v0.1-only table (Core.lua:38-40). Keep `existing` first.

**Prevention:** Single `existing` computed first; steps `if schema < 3` and `if schema < 4` both read it; step 4 writes only the hard-coded key list, only for non-boolean values, then `db.schema = 4`. Bump `DEFAULTS.schema` to 4. Add a headless fixture test (the repo's harness) with these tables: `{}`, `{gs = 1}`, `{schema = 3}`, `{schema = 3, specPoints = false}`, `{schema = 3, meterResetOnGroup = true}`, `{schema = 4}`, and a v0.2.1-shaped table that must pass through both steps. Assert results via `Settings.Get`.

**Warning signs:** A fresh install showing item level on tooltips (step misfired on `{}`); an existing player's tooltips going blank after the update; "Defaults" button writing different values than a fresh install.

**Phase to address:** P-A.

---

### Pitfall 8: Opt-in defaults make the addon look broken, and unsaved-vs-saved state leaks into other code

**What goes wrong:**
- A new install shows nothing outside the finder; the player may think item level or the meter prompt "stopped working" or never discover the settings page. The Settings page and `/tgf settings` exist but there is no pointer.
- The Settings panel's Defaults button saves defaults (accepted per CLAUDE.md): for existing players it flips the preserved `true` values to the new off defaults. Document it; do not "fix" it.
- Features that start work regardless of the setting. Inspect text, the sheet row and the tooltips read `Get` where they act (`A:ItemLevelUI.lua:129-130, 281, 487, 638`; `MeterReset.lua:404`). The quiet inspect queue is only requested when a tooltip option is on (`ItemLevelUI.lua:150-155`). New per-slot code must follow the same rule (Pitfall 11) so a fresh install does zero inspect traffic and zero hooks that do work. Install hooks lazily or no-op when the option is off; installing is fine, acting is not.
- Parent/child options: `swipeAnimations` is a child of `dynamicRefresh` (`Settings.lua:159-165`); with the section reorder (Group finder, Player inspection, Damage meter, Messages) keep `parent` keys valid and `Register` order stable (the page is built from `List()` order).

**Prevention:** Print one line on a fresh install (`schema` was 0, `existing` false) pointing to `/tgf settings` once, gated so it never repeats (a saved flag set only then). Keep all reads through `Get`, never `db.key`. Add the new keys to `OPTIONS` with their defaults; do not add them to `RESERVED`.

**Phase to address:** P-A (migration, hint), P-D (section order, parent keys).

---

## Moderate Pitfalls

### Pitfall 9: Per-slot data is read from the wrong place or at the wrong time (inspect data cleared or belonging to someone else)

**What goes wrong:** Inspect data is a single global slot. `ClearInspectPlayer()` is called by the Inspect window when it hides (`B:Blizzard_InspectUI/Camelot/Blizzard_InspectUI.lua:144-151`) and by our quiet queue (`A:ItemLevel.lua:799-808`). Overlays that read `GetInventoryItemLink(unit, slot)` on a timer after that read nothing, or, worse, read the *previous* player's gear when a quiet inspect for another GUID was the latest one.

**Prevention:**
- Only draw Inspect overlays from the game's own refresh: `hooksecurefunc("InspectPaperDollItemSlotButton_Update", ...)` (global, called per slot from `InspectPaperDollFrameMixin:UpdateButtons` on show and on `INSPECT_READY`, `B:Blizzard_InspectUI/Mainline/InspectPaperDollFrame.lua:12-27, 63-70, 245-272`) plus `UNIT_INVENTORY_CHANGED` which also calls it (`:209-216`). Use `button:GetID()` as the slot and `InspectFrame.unit` as the unit.
- Require the data to belong to the inspected player: compare `UnitGUID(InspectFrame.unit)` with the GUID of the latest answered inspect (the guard already tracks `lastTarget`/`readyGUID`/`readySerial`, `ItemLevel.lua:695-702, 1051-1062`). Expose a read-only `ILvl.InspectReadyFor(unit)` rather than duplicating; never read per-slot data when it is false.
- Do not extend the quiet inspect queue to collect per-slot data for tooltips or cache it. Per-slot data lives only while the Inspect window is shown: no `known[guid]` entries, no session cache, no extra `NotifyInspect`. The existing guard says the queue stays away while the Inspect window is shown or pending (`ItemLevel.lua:15-22`), so the two never compete if the overlay never asks for inspects.
- Never call `ClearInspectPlayer()`/`NotifyInspect()` from the overlay code.
- Redraw on `OnHide` (clear our fontstrings) so a reopened window never flashes the previous player's marks.

**Warning signs:** Marks from player A on player B's window; marks that disappear when a tooltip inspect finishes; double inspect traffic in `/tgf ilvl`.

**Phase to address:** P-C.

---

### Pitfall 10: Item data not cached; `nil` shown as "no enchant"

**What goes wrong:** `GetInventoryItemLink` may return a link while `GetDetailedItemLevelInfo`/`GetItemInfo` return nothing, and for an inspected unit item data arrives progressively after `INSPECT_READY`. The existing reader already models this: `ILvl.Read` counts a slot as pending when the level is nil (`A:ItemLevel.lua:333-368`) and retries `ITEM_RETRIES = 3` times a second apart (`ItemLevel.lua:1085-1099`). A per-slot overlay that treats nil level or nil gem info as "empty" paints a false red "missing enchant" or "no socket" mark.

**Prevention:**
- Three states per slot: *no item*, *pending*, *known*. Draw nothing for pending; schedule a re-read.
- Gem icons: the stock socket display shows the pattern: `C_Item.GetItemGemID(item, i)` works without the gem cached (no `GetItemGem`), and the icon needs `Item:CreateFromItemID(gemID):ContinueOnItemLoad(...)` (`B:Blizzard_UIPanels_Game/Camelot/PaperDollFrame.lua:3576-3612`). Re-check that the slot still shows the same link in the callback (slots are reused when the unit changes).
- Item level: `C_Item.GetDetailedItemLevelInfo(link)` can return nothing (`MayReturnNothing`, `ItemDocumentation.lua:354-366`); retry on `GET_ITEM_INFO_RECEIVED` (debounced, one pass per frame) rather than polling. Unregister when no overlay is visible.
- Treat the unit's heirlooms and quality 1 items like the existing code does (`ItemLevel.lua:353-359`); the overlay's item level for heirlooms is the level of *that* link and may differ from the unit's real value; show the level the game's tooltip shows, nothing invented.

**Phase to address:** P-C.

---

### Pitfall 11: Enchant and socket detection from links and tooltips

**What goes wrong:**
- **Enchant:** the enchant ID is field 2 of the item string (`item:itemID:enchantID:gem1:gem2:gem3:gem4:...`; Blizzard documents the layout, `B:Blizzard_PTRFeedback/Blizzard_Reports.lua:391`). A "missing enchant" mark is only correct for slots that can be enchanted. Marking every slot, a shirt, tabard, trinkets, necks, rings (for non-enchanters), or off-hand items that are not weapons/shields (held-in-off-hand), floods the window with false warnings. Which slots are enchantable and which items accept an enchant (a two-hand weapon, a dagger, a wand: no; a shield: some eras no) depends on the era's ruleset and cannot be derived from the API; there is no "can be enchanted" function in `ItemDocumentation.lua` (only `GetWeaponEnchantInfo`, `:1141`, for *your* temporary weapon enchants, not permanent ones).
- **Sockets:** `C_Item.GetItemNumSockets(link)` returns the sockets on the item (`ItemDocumentation.lua:876-888`); `GetItemGemID(link, i)` returns the socketed gem or nothing. The stock display uses these two (`PaperDollFrame.lua:3576-3600`). A tooltip scan would be slower, localized and secret-prone; `GetItemStats` is not a socket count (it returns `EMPTY_SOCKET_*` keys only for empty sockets of base items, and not for extra sockets added by effects) and is the wrong tool.
- **Secret values:** links and IDs for other players can be secret (`ItemLevel.lua:337-340` already skips them). `link:match("item:%d+:(%d*)")` on a secret string errors; check `issecretvalue(link)` first and skip the slot, as `ILvl.Read` does.

**Prevention:**
- Make the "missing enchant" mark conservative: a data table of enchantable slots for the target ruleset with a one-line source comment, verified in game with a fully enchanted character (and a max-level one with a bare slot). When in doubt for a slot or weapon type, draw no mark rather than a wrong one. Treat this table as research-flag data, not code: list the slots in the plan with how each was verified.
- Parse the enchant field with a tolerant pattern: `link:match("|Hitem:(%d+):(%d*)")`, enchant is `tonumber(second)`; an empty or 0 field means none. Wrap in `pcall`, skip when secret. Do not use `GetItemInfo`'s link normalisation (it strips nothing but is async).
- Sockets: `GetItemNumSockets` and `GetItemGemID` only; empty socket = `numSockets > count(GetItemGemID(link, i))`; show a plain grey socket marker for empty ones, the gem icon for filled ones; show nothing for items with no sockets. Cap the loop at the template's 3 (the stock `Slot1-Slot3`, `PaperDollFrame.xml:107-124`); the real maximum on Forever is unverified.
- Enchant/gem *names* in tooltips (if shown) must come from our own `GameTooltip` lines on hover, never by editing the slot button's tooltip scripts.

**Phase to address:** P-C; flag "enchantable slot list" as needing a phase-level data check.

---

### Pitfall 12: Overlays collide with Forever's own slot art and other addons

**What goes wrong:**
- Forever's character sheet and Inspect slots already carry a stock `SocketDisplay` frame anchored beside each slot (`B:Blizzard_UIPanels_Game/Camelot/PaperDollFrame.xml:128-160`: `RIGHT x=7` on the left column, `LEFT x=-7` on the right column, `TOP y=7` on the weapons). It is shown only for timerunning characters (`PaperDollItemSocketDisplayMixin:SetItem`, `PaperDollFrame.lua:3576-3581`), so it is normally hidden, but on a timerunning character our sockets would duplicate it (check `PlayerIsTimerunning()` and skip our gem row when `slot.SocketDisplay:IsShown()`; read-only).
- The Inspect window's Camelot XML has no `SocketDisplay` (Mainline's does, `B:Blizzard_InspectUI/Mainline/InspectPaperDollFrame.xml:29-65`), and the shared Lua guards with `if button.SocketDisplay` (`InspectPaperDollFrame.lua:270`). Do not "fix" that by writing a `SocketDisplay` key onto Blizzard's button: it would make Blizzard's secure update call into our frame and write a field on a Blizzard frame (CLAUDE.md taint rule).
- Inspect slot buttons are `frameLevel="100"` (`B:Blizzard_InspectUI/Camelot/InspectPaperDollFrame.xml:3`): an overlay frame parented to the button at a low level draws under the icon border. Parent our own frame to the slot button (hooks and children are allowed) with a higher `SetFrameLevel`, or draw regions on our own child frame.
- Small vanilla-era slots (about 37 px) leave little room: three text elements (ilvl, enchant mark, gems) overlap the icon, the count, the item-quality border and the gear-slot border art. The slot columns are tightly spaced (4 px gap, `InspectPaperDollFrame.xml:205-215`), so text beside the slot may overlap the model or the next column's slot. The weapon row is horizontal.
- Other addons (Inspect/gear overlay addons, `ElvUI`, etc.) may already draw on the same slots. We cannot know; do not hide or restyle theirs.

**Prevention:** Own child frame per slot, created once and reused (never created per update), named with our prefix; item level as a small outlined `GameFontNormalSmall` string inside the icon's bottom, enchant as a single mark at a corner, gems as small icons along the inner edge of the slot (toward the model for each column, the way the stock display points). Test at the default UI scale, at 0.8 and at 1.2, with the large and small fonts; read the font from a template (`NumberFontNormalSmall`) rather than hard-coded files. Put a "hide overlays" option behind the per-slot setting, default off. Keep to the existing independent-installer-plus-pcall pattern (`A:ItemLevelUI.lua:316-337`, `UI.Install("inspect", ...)` at `:683`) so one failing slot cannot break the others, and list the new installers in `/tgf ilvl`'s failed-installer report.

**Phase to address:** P-C.

---

### Pitfall 13: Inspect UI is load-on-demand; one-shot installs miss it

**What goes wrong:** `Blizzard_InspectUI` is `LoadOnDemand` (`B:Blizzard_InspectUI/Blizzard_InspectUI.toc`), so `InspectPaperDollItemSlotButton_Update` does not exist at our load, and `hooksecurefunc` on a nil global errors. The research file already records this for the text (`A:.planning/research/PITFALLS.md` Pitfall 4); the code installs through `EventUtil.ContinueOnAddOnLoaded("Blizzard_InspectUI", ...)` (`A:ItemLevelUI.lua:348-358`). Core unregisters `ADDON_LOADED` after our own load (`A:Core.lua:284`), so a naive `ADDON_LOADED` listener added later never fires.

**Prevention:** Reuse the same `ContinueOnAddOnLoaded` path (it also fires if the addon is already loaded). Hook the global by name only after it exists; hook once (guard flag), because `/reload` re-runs our file but not Blizzard's. If Inspect is already open at install (a retry at login), draw immediately. The character sheet's `PaperDollItemSlotButton_Update` (`B:Blizzard_UIPanels_Game/Camelot/PaperDollFrame.lua:2183-2220`) is in a normal-load addon; hook it at `PLAYER_LOGIN` and again guard against it being undefined (the existing sheet code needed "one more try at `PLAYER_LOGIN`", CLAUDE.md).

**Phase to address:** P-C.

---

### Pitfall 14: Writing to the character sheet in ways that taint the sheet again

**What goes wrong:** The v0.2 character sheet row tainted the sheet when it wrote into the stats data (`A:.planning/research/PITFALLS.md` Pitfall 2; PROJECT.md Key Decisions line 322). The slot buttons are a different structure (not data-driven), but the same family of mistakes exists: setting `button.someField = ...` on a Blizzard slot button, replacing `PaperDollItemSlotButton_Update`, overriding `button.UpdateItemContextMatching`, calling `button.SocketDisplay:SetItem(...)` ourselves, or creating frames from the secure `*_Update` path with `CreateFrame` templates that run Blizzard code.

**Prevention:** Hooks only (`hooksecurefunc`), per-slot state kept in our own table keyed by the button (weak keys), own frames as children. No field writes on Blizzard frames, no method calls into `PaperDollItemSlotButtonMixin`. The hook body runs `pcall(Draw, button)`. Reading `GetInventoryItemLink("player", slot)` for your own gear is safe (not secret).

**Phase to address:** P-C.

---

## Minor Pitfalls

### Pitfall 15: Click handler and combat

Opening the finder (`ShowUIPanel`) in combat is guarded in the existing opener (`A:UI/InPlace.lua:439-441`); reuse `IP.OpenMessages`'s structure, not a copy. Our eye can stay visible in combat but its click prints "can't open the group finder in combat" (as now). A tooltip on the eye uses `GameTooltip` owner rules (`W.ShowTip`), and the stock eye atlas is `socialqueuing-icon-eye` on `UI-SquareButton-*` art (`B:Blizzard_ObjectiveTracker/Blizzard_ObjectiveTrackerShared.xml:65-84`); reuse those assets and the same mouse-down icon nudge (`Blizzard_ObjectiveTrackerShared.lua:186-196`) so it looks native. If either atlas or file is missing, fall back to a plain texture (`W.AtlasMarkup` empty-when-missing pattern).

### Pitfall 16: Tracker header tooltips and block clicks

The block's header handles clicks to open the quest/POI; our button must not pass clicks through or steal them. Use a real Button with `OnClick` and let the block's own scripts handle everything else; do not `SetPropagateMouseClicks` on the block.

### Pitfall 17: Quest turn-in and abandon

On `QUEST_TURNED_IN`/abandon the block is freed on the next layout; the click handler must re-validate `C_QuestLog.IsEliteQuest(id)` and `C_QuestLog.GetLogIndexForQuestID(id)` (nil = not in the log) and do nothing if the quest left the log.

### Pitfall 18: README and screenshots

The new eye button, the per-slot marks and the reordered Settings sections change screenshots (project memory: flag when a UI change may need a new README print). Also CLAUDE.md's architecture list and the Key Constraints "outside the finder the addon only hooks" sentence need the tracker and slot overlays added; both are accepted exceptions that must be written down (an own frame on the tracker block, own frames on slot buttons).

---

## Phase-Specific Warnings

| Phase | Likely pitfall | Mitigation |
|-------|----------------|------------|
| P-A Opt-in defaults | `existing` recomputed inside step 4 (Pitfall 7); preserved set built from `Get` or from all options (7); no pointer for new players (8) | Compute `existing` once at the top; hard-code the six v0.2.2 keys; fixtures for 7 table shapes; one-time hint line |
| P-B Elite button | Prefill/selection through Blizzard frames taints later Search/Create (2); description box is `SetSecurityDisableSetText` (1); stock eye duplicates and errors (3); layout/pool/hook-target traps (4); wrong elite test (5); quest-to-activity API absent in docs (6) | Navigation plus our own hint only; live-probe `CanCreateQuestGroup`, `GetActivityIDForQuestID`; `IsEliteQuest` with pcall; per-block re-evaluation; hook both tracker instances |
| P-C Per-slot info | Reading cleared or foreign inspect data (9); nil info shown as "missing" (10); enchantable-slot table wrong, secret links (11); overlap with stock `SocketDisplay` and small slots (12); load-on-demand Inspect (13); field writes on slot buttons (14) | Hook `*_Update`, read live only, GUID check, three-state slots, conservative enchant table, own child frames with higher frame level |
| P-D Settings and Release | Section reorder breaks `parent` or registration order (8); docs and screenshots stale (18) | Keep `Register` order = display order; update CLAUDE.md and README; live taint pass with `/console taintLog 2` |

## Needs a live check (not provable from source)

- Does `C_LFGList.CanCreateQuestGroup(questID)` return true for any quest on Forever (stock eye appears, Pitfall 3)? What does `C_LFGList.GetActivityIDForQuestID` exist as, and do category 116 activities carry a `mapID` that matches a quest's zone (Pitfall 6)?
- Taint after the eye opens the finder: post a listing and search by hand with `/console taintLog 2`; no `ADDON_ACTION_BLOCKED` (Pitfall 2).
- Anchoring our frame near `block.ItemButton` in combat (Pitfall 4, LOW).
- Which slots and weapon types accept an enchant on Forever, and the real socket maximum per item (Pitfall 11).
- Whether `GET_ITEM_INFO_RECEIVED` fires for an inspected player's items, or only `INSPECT_READY` re-reads help (Pitfall 10).

## Sources

- Blizzard UI source, branch `forever` (read-only), files cited inline: `Blizzard_ObjectiveTracker/*`, `Blizzard_GroupFinder_VanillaStyle/*`, `Blizzard_GroupFinder/Mainline/LFGList.lua`, `Blizzard_FrameXMLUtil/{Mainline,Camelot}/QuestUtils*.lua`, `Blizzard_UIPanels_Game/Camelot/PaperDollFrame.{lua,xml}`, `Blizzard_InspectUI/{Camelot,Mainline}/*`, `Blizzard_APIDocumentationGenerated/{LFGListInfo,QuestLog,Item,PaperDollInfo,SimpleEditBoxAPI}Documentation.lua` (HIGH)
- This repo: `Core.lua`, `Settings.lua`, `ItemLevel.lua`, `ItemLevelUI.lua`, `UI/InPlace.lua`, `CLAUDE.md`, `.planning/PROJECT.md`, `.planning/research/PITFALLS.md` (v0.2 pitfalls 2, 3, 4), `.planning/research/FOREVER-GROUPFINDER.md` (HIGH for code, MEDIUM for prior live observations)
- Taint propagation rules (a field written by tainted code stays tainted until secure code overwrites it; secure functions called from insecure code run tainted): general WoW secure-execution behaviour, consistent with CLAUDE.md's rules and the v0.2 sheet experience (MEDIUM; the exact blocked-call consequences are in "Needs a live check")
