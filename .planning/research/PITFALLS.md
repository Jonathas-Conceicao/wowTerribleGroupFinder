# Pitfalls Research

**Domain:** Adding item level spots, a settings window, Dynamic refresh polish, region flags and gear score removal to an existing in-place WoW Forever group finder addon (milestone v0.2)
**Researched:** 2026-11-14
**Confidence:** MEDIUM-HIGH. Blizzard-source claims (wow-ui-source, branch `forever`) are HIGH. Runtime behaviour that only the live client can show (combat, taint spread, shard mapping) is marked LOW or MEDIUM and listed under "Needs a live check".

Paths below are relative to `C:\Users\jonat\Repositories\wow-ui-source\Interface\AddOns\` unless they start with the addon repo.

---

## Critical Pitfalls

### Pitfall 1: The Forever character sheet's stats pane is a ScrollBox rebuilt from a global table, not a set of static frames

**What goes wrong:** The plan says "an extra row under Movement Speed". In Forever (Camelot) `CharacterFrameMixin:GetStatsPane()` returns `CharacterStatsPaneScrollBox` (`Blizzard_UIPanels_Game/Camelot/CharacterFrame.lua:823`). `UpdateStats()` (line 1102) rebuilds `self.elementData` from `PAPERDOLL_STATCATEGORIES` and calls `SetDataProvider` on every `PaperDollFrame_UpdateStats` (equipment, talent, speed and target events, `PaperDollFrame.lua:~470`). Anything parented or anchored under the Movement Speed frame by hand is thrown away or recycled on the next update: frames are pooled and one frame shows different data later. A second source of loss: `HideElements()` (line 1078) re-creates the data provider from `self.elementData` whenever any stat reports `shouldRemove`, so a row injected only into the live data provider vanishes.

**Why it happens:** Retail-era guides anchor a FontString under `CharacterStatsPane.AttributesCategory` or the old `statsFramePool`. The old `CharacterStatsPane` (non-scroll) still exists in the XML but is hidden and unused in Camelot.

**Consequences:** Row appears once, then moves, duplicates, or disappears on scroll, equipment change or pet toggle.

**How to avoid:**
- Add a stat entry to the data source, not a frame: `PAPERDOLL_STATCATEGORIES` has TWO categories named `STAT_CATEGORY_GENERAL` (`Camelot/PaperDollFrameConstants.lua:35` player, `:~99` pet, told apart by `unit`). Find the one with `unit == "player"`, find the `MOVESPEED` entry by value (never a hard-coded index), insert after it, and do it once (guard against a second run, e.g. addon reload logic).
- Reuse the game's own `PAPERDOLL_STATINFO["ITEMLEVEL"]` (`PaperDollFrame.lua:122`, `PaperDollFrame_SetItemLevel` line 1378): it already formats label/value/tooltip and returns a number. Registering our own `PAPERDOLL_STATINFO` key means writing another Blizzard global; avoid unless the label must differ.
- If a custom `updateFunc` is ever needed: it is called TWICE per update (once in `UpdateStats` line ~1190 to test `hideAt`, once in the element `Init`, `CharacterFrame.lua:1273`) with a pooled frame; it must be cheap, idempotent, never start inspects, and must RETURN a number. `numericValue ~= statData.hideAt` with `hideAt == nil` means returning `nil` hides the row silently.

**Warning signs:** Row missing after `/reload` with the sheet open; present for player pane but also shows in the pet pane; two rows after toggling the pet tab; value stuck.

**Phase to address:** Item level on the character sheet (Item Level phase).

---

### Pitfall 2: Writing Blizzard globals (`PAPERDOLL_STATCATEGORIES`) taints the sheet's update path

**What goes wrong:** Inserting into `PAPERDOLL_STATCATEGORIES[n].stats` (a Blizzard-owned table) marks the written slots as tainted. `UpdateStats` then reads tainted entries and runs tainted from that point, including `ScrollBox:SetDataProvider` and the element initializers. In this modern client tainted code reading secret values errors out instead of degrading quietly (docs mark many unit stat APIs `SecretWhenUnitStatsRestricted`, e.g. `GetUnitSpeed` in `Blizzard_APIDocumentationGenerated/UnitDocumentation.lua:335`).

**Why it happens:** It is the one practical way to put a row in a data-driven pane; there is no `hooksecurefunc` route that can change data after the fact (post-hooks can't alter the provider without writing into it, which taints the same way).

**Consequences:** Most likely harmless on a non-protected frame (CharacterFrame has no protected children), but a tainted update in combat can break the pane or blame the addon in `ADDON_ACTION_FORBIDDEN`/Lua errors. MEDIUM confidence: taint spread through `securecallfunction`/`secureexecuterange` initializers could not be proven from source.

**How to avoid:**
- Keep the project taint rule's spirit: do the table write once, outside combat (at ADDON_LOADED, which is before any combat), never per update.
- Do NOT touch `CharacterStatsPaneScrollBox.elementData` or the provider directly from our callbacks.
- Do not hook `PaperDollFrame_UpdateStats` to rewrite data; a pure read-only post-hook is fine for refreshing our own state.
- Record this as the one deliberate exception to "never write fields on Blizzard frames" in PROJECT.md/CLAUDE.md decisions, with the reasoning, so the Release Review does not flag it.
- Make the sheet row independently switchable (setting) so a player can turn it off if it ever misbehaves.

**Warning signs:** `ADDON_ACTION_BLOCKED/FORBIDDEN` naming TerribleGroupFinder when opening the character frame or entering combat with it open; Lua errors "attempt to compare a secret value" in `PaperDollFrame*`.

**Phase to address:** Item level on the character sheet. Verify with the live check list below.

---

### Pitfall 3: Quiet inspects collide with the player's own Inspect window (wrong unit data, cleared data)

**What goes wrong:** `ItemLevel.lua` calls `NotifyInspect` and `ClearInspectPlayer` (`Done`, line 349-352). Facts from `Blizzard_InspectUI/Camelot/Blizzard_InspectUI.lua`:
- `InspectFrame_Show` (line 40) calls `NotifyInspect(unit)` and sets `InspectFrame.unit` immediately, but the frame is only shown on `INSPECT_READY` (line 88). Between the click and the answer `InspectFrame:IsShown()` is false, so our `Busy()` guard (`InspectFrame:IsShown()`, ItemLevel.lua:327) does not see it. Our `Done` then calls `ClearInspectPlayer()` and wipes the data the player just asked for; or our own `NotifyInspect` replaces their pending target.
- `InspectFrameMixin:OnHide` (line 144) calls `ClearInspectPlayer()` itself, so a quiet inspect of ours in flight when the window closes loses its data (our read returns old, zero or "lingering" values; the API is known to return the previous player's value).
- `C_PaperDollInfo.GetInspectItemLevel(unit)` takes a unit, but the client holds ONE inspect result. If the unit token now points at another player (target changed, `UnitChanged` re-inspects at line 125) the number belongs to the previous inspect.

**Why it happens:** Inspect state is global and shared by the stock window, our probe and our tooltip inspects, and the visible-state guard is one flag too late.

**Consequences:** Inspect window opens empty or with a quiet inspect's gear; the Inspect text shows another player's item level; our cache gets a wrong value that is then "never looked up again" (a known value is never refreshed).

**How to avoid:**
- Guard on `InspectFrame and (InspectFrame:IsShown() or InspectFrame.unit ~= nil)` and on any pending `NotifyInspect` of the game's (hook `NotifyInspect`/`InspectUnit` with `hooksecurefunc` to note "someone else inspected at T"; treat the next 2 s as busy).
- Call `ClearInspectPlayer()` only if no other inspect started after ours. Never call it when the window might be about to show.
- Accept values only when the `INSPECT_READY` GUID argument equals the GUID we asked for AND `UnitGUID(unit)` still equals it at read time (the existing `FindUnit(c.guid, c.unit)` is the right pattern; keep it for every read, including the Inspect window text).
- If our inspect was displaced (their `INSPECT_READY` arrives with a different GUID), drop ours without caching and requeue later.

**Warning signs:** Inspect window opens blank on first click right after hovering players; item level differs by a few points between tooltip and Inspect text; a number stays after the player changed gear (stale "known" value).

**Phase to address:** Item level tooltips for players + Inspect text. Add the guard before wiring Inspect.

---

### Pitfall 4: Blizzard_InspectUI is load-on-demand and Core.lua unregisters ADDON_LOADED after our own load

**What goes wrong:** `Core.lua` does `frame:UnregisterEvent("ADDON_LOADED")` once our addon loads, so we never see `Blizzard_InspectUI` load. `InspectFrame`, `InspectLevelText`, `InspectPaperDollFrame` do not exist until the first `InspectUnit` (`Blizzard_InspectUI/Mainline/Blizzard_InspectUI_Bootstrap.lua`, `LoadAddOnWithErrorHandling`). Any access at our ADDON_LOADED is a nil error, and an `InspectFrame and ...` guard that is nil forever silently disables the feature (ItemLevel.lua:327 already uses that global lazily).

**How to avoid:**
- Use `EventUtil.ContinueOnAddOnLoaded("Blizzard_InspectUI", fn)` (`Blizzard_SharedXML/EventUtil.lua:67`): runs now if already loaded, else on that ADDON_LOADED. Blizzard uses the same call (`Camelot/Blizzard_InspectUI.lua:383`). It fires after all of the addon's files ran, before the first `InspectFrame_Show`, so hooks are in place for the very first inspect.
- Hook with `hooksecurefunc` only: `InspectFrame_Show`, and the paper doll's `SetLevel`/`UpdateButtons` (`Blizzard_InspectUI/Mainline/InspectPaperDollFrame.lua:29,63`; Camelot's TOC loads the Mainline lua for the paper doll). Our own `INSPECT_READY` frame is registered at login (already so in `ILvl.Init`), so event order versus the Inspect frame's handlers is not guaranteed: do the read in a `hooksecurefunc` on the paper doll update, or defer one frame (`C_Timer.After(0)`), never assume ours runs second.
- Parent our FontString to `InspectFrame` (a region on their frame is fine; writing fields on it is not). Anchor to a stock region (title/close area), check it does not overlap the close button, and re-anchor on `InspectFrame:UpdateTabs`/size changes is not needed if anchored to the frame itself.
- Also set our text on `OnShow` of the paper doll and clear it when `InspectFrame.unit` is nil (cleared in `OnHide`, line 145) so the previous player's number never flashes.
- Item data for the inspected gear loads asynchronously: show nothing (or no text) while unknown/incomplete (already the rule), and retry on `GET_ITEM_INFO_RECEIVED`/short timer instead of a permanent "N/A".

**Warning signs:** Error `attempt to index global 'InspectFrame'` at login; text never appears the first time but does after a second inspect.

**Phase to address:** Inspect window text.

---

### Pitfall 5: Item tooltip line inserted at the end, or twice, or into every tooltip

**What goes wrong:** Three separate failure modes in `TooltipDataProcessor` usage (`Blizzard_SharedXMLGame/Tooltip/TooltipDataHandler.lua`):
1. A tooltip POST call (what `OnTooltipUnit` uses) runs after all lines, so `AddLine` lands at the bottom. To put "Item Level N" under the name, register an `AddLinePostCall(Enum.TooltipDataLineType.ItemName, fn)`: line post-calls run right after each line is added (`ProcessLineData`, lines ~325-335), so an `AddLine` there is inserted as line 2. The line post-call receives `(tooltip, lineData)` only, not the tooltip data; read the item from `tooltip:GetPrimaryTooltipData()`/`tooltip:GetItem()`.
2. Duplicates: `RebuildFromTooltipInfo` (line 360) does `ClearLines` then reprocesses everything, so post-calls re-run by design and add exactly once. Duplicates appear only when we ALSO add lines from `RefreshTooltip` (our async unit-tooltip refresh calls `AddLine` on a shown tooltip, ItemLevel.lua:334-346; a later rebuild is fine, but an item path that adds from a `hooksecurefunc(GameTooltip, "SetX")` or `OnShow` hook in addition to the processor adds twice) or when a tooltip is processed in append mode (`AppendInfo`, line 379: each append re-runs post-calls, so embedded/appended item blocks each get a line, which is usually correct but then a hand-written "already added" flag wrongly suppresses the second).
3. Forever may already emit an item level line: `Enum.TooltipDataLineType.ItemLevel = 31` exists (`Blizzard_APIDocumentationGenerated/TooltipInfoSharedDocumentation.lua:65`), as does `ItemUpgradeLevel`. If the server tooltip data has a line of type 31 for some items, adding ours doubles it.

**How to avoid:**
- Use only the processor (ItemName line post-call), nothing else; keep the unit path's `RefreshTooltip` unit-only.
- On the post-call, scan `tooltip:GetPrimaryTooltipData().lines` for `type == ItemLevel` and skip when present (verify live: `/dump C_TooltipInfo.GetInventoryItem("player", 16).lines` types).
- Decide the tooltip whitelist: GameTooltip, ItemRefTooltip and the shopping/comparison tooltips (`ShoppingTooltip1/2`, which inherit the same handler) should all get the line (retail does); skip embedded and non-item data. `OnTooltipUnit` filters `tooltip ~= GameTooltip`; do not copy that filter blindly to items or comparison tooltips lose the line.
- The compare tooltips are started in `FinalizeItemTooltip` (`TooltipDataRules.lua:163`), a SECURE post-call that runs before ours; they are anchored to the main tooltip and re-laid out on `Show`, so our extra line (added before `self:Show()` at `TooltipDataHandler.lua:~270`) is safe.
- Do not cache a negative result: when item data is not loaded `C_Item.GetDetailedItemLevelInfo` returns nothing; `TOOLTIP_DATA_UPDATE` (`GameTooltip.lua:970`) rebuilds the tooltip when data arrives and our call runs again, adding the line then.

**Warning signs:** Line at the bottom; duplicate "Item Level" on some items; comparison tooltip missing the line; line appears only after a second hover.

**Phase to address:** Item level on item tooltips.

---

### Pitfall 6: Wrong number for items (base vs effective level, non-gear, heirlooms) and secret values in tooltip data

**What goes wrong:** `GetItemInfo` returns the base item level; `C_Item.GetDetailedItemLevelInfo(itemInfo)` returns the actual (upgrade/scaling-aware) level (`Blizzard_APIDocumentationGenerated/ItemDocumentation.lua:354`, `MayReturnNothing`). Retail shows the line only on equippable items with a meaningful level. Items with level 0/1, consumables, quest items, bags, containers and keys must not get "Item Level 1". Heirlooms scale with the PLAYER's level: the level for a link from chat is not the level of your own copy, and `tooltipData.overrideItemLevel` is set for comparison data (`TooltipComparisonManager.lua:15`). Tooltip data (`hyperlink`, `lines[].leftText`) can be a secret value in restricted contexts; `GetDetailedItemLevelInfo` is `SecretArguments = "AllowedWhenUntainted"`, i.e. our tainted call with a secret link errors (contained by `securecallfunction`, but silently loses the line).

**How to avoid:**
- Compute from `tooltipData.hyperlink` (or `guid`) through `C_Item.GetDetailedItemLevelInfo`, prefer `tooltipData.overrideItemLevel` when present, show only when `C_Item.IsEquippableItem(link)` and level > 1.
- Guard every read: `issecretvalue(link)` and `canaccessallvalues(tooltipData)` before touching; wrap the call in `pcall`. Skip silently.
- Format with `ITEM_LEVEL` ("Item Level %d", used by Blizzard UI) so it is localized, colour yellow `NORMAL_FONT_COLOR`, like the existing unit line (ItemLevel.lua AddLine).
- Performance: post-calls run on every tooltip show and on each throttled rebuild; the work is one API call and a string format. No per-line scans except the one type-31 check. Do not call `GetItemInfo` in a loop over `lines`.

**Warning signs:** "Item Level 1" on potions; an heirloom shows a different number than the one equipped; Lua error text mentioning "secret" in the error log from a tooltip hover in combat.

**Phase to address:** Item level on item tooltips.

---

### Pitfall 7: Saved-variable migration when deleting gear score; Settings registration writes defaults into the same table

**What goes wrong:** `Core.lua:266-279` only fills `DEFAULTS` (`schema = 1`); `GearScore.lua:272-273` creates `db.gs` on every login (so every v0.1 user has `TerribleGroupFinderDB.gs`, at least `{}`; dev-build testers have real cache entries). Deleting `GearScore.lua` without clearing it leaves dead data forever. Other traps:
- The Blizzard AddOnSetting keeps a REFERENCE to the variable table and writes defaults into it at registration if a key is nil (`Blizzard_Settings_Shared/Blizzard_Setting.lua:413-427`, `SecureSetVariableTblDefaultValue`). If migration code later REPLACES `TerribleGroupFinderDB` or `ns.db` (reset, `= {}`), the settings write into an orphan table and nothing saves. All resets must mutate in place (`wipe`/field assign), never rebind `TerribleGroupFinderDB`.
- Order: run migration BEFORE `Settings.RegisterAddOnSetting`, otherwise a renamed key's old value is overwritten by the default.
- `CLAUDE.md` names `DB.autoRefresh` (`/tgf auto`) from the dev branch; this branch's code reads no such key (grep found none) but a tester's saved file may carry it. Decide the setting's final key and map the old one once, then delete it.
- Region: `db.shards` is read by reference (`Region.lua:111-116`, `learned = db.shards`); numeric keys fine, but the table is rewritten by `Init` merge each load.

**How to avoid:**
- Bump `schema` to 2 in `DEFAULTS` and add a `Migrate(db)` in `Core.lua` run in `ADDON_LOADED` before every module `Init`: if `(db.schema or 0) < 2` then `db.gs = nil` (and any other removed key, e.g. old gear-score options, `autoRefresh` mapped to the new key), then `db.schema = 2`. The existing "No preset migration from the dev build" decision applies to dev-only data, but `gs` exists in a RELEASED version, so this migration is required and invisible to users (no changelog mention beyond "Removed: gear score").
- Remove `ns.GEAR_SCORE`, `ns.GS.Init(ns.db)` (Core.lua:275), the GS column code and the `GearScore.lua` TOC line together; stale TOC lines to a deleted file produce a load error, and `scripts/install.ps1` derives files from the TOC. `GS` colours in `UI/Widgets.lua` and the 12 `GEAR_SCORE` references (grep) must go in the same change; stylua and a smoke test in the preview catch nil references.
- Keep `.planning/research/GEARSCORE.md` as the project says.

**Warning signs:** `TerribleGroupFinderDB.gs` still present after a login with v0.2; settings checkboxes that reset after `/reload`; "attempt to index nil `ns.GS`" from the table code.

**Phase to address:** First phase (gear score removal and migration), before Settings.

---

### Pitfall 8: Animation groups on pooled ScrollBox rows: recycled mid-animation, alpha stuck, wrong frame

**What goes wrong (existing code, UI/Table.lua:1835-1891):**
- Frames are pooled and re-bound to a different listing when the data provider changes (`ScrollBoxListView.lua:359-470`: Acquire/Release; initializers run AFTER layout, `InvokeInitializers`). A swipe-out plays on the frame that holds the listing NOW; after `SetItems`, the same frame may show another listing. The reuse guard exists in `FillRow` (stop and `SetAlpha(1)`, line 1144), but a frame released and NOT re-acquired (list got shorter, row scrolled out) keeps `SetToFinalAlpha(true)` alpha 0 and a running group until the next acquire. Safer: also stop and reset in `SetElementResetter` (Table.lua:1541, used today only for tooltips) which runs in `Release`.
- `SwipeIn` finds frames by listing key AFTER `SelectKey` -> `RefreshAll`. Whether the new frames exist at that time depends on the update being immediate: `FullUpdate(immediately)` is deferred to `OnUpdate` unless `ScrollBoxConstants.UpdateImmediately` (`ScrollBox.lua:133-143`). `SetDataProvider` may or may not update synchronously; if not, `ForEachFrame` returns the old frames and the swipe-in plays on the wrong rows or none (fails silently inside `pcall`). Verify with a frame-count check, or play the swipe-in from `OnAcquiredFrame`/after `box:ForEachFrame` in the next frame.
- Translation animations are visual only; the real frame stays on its anchor, so the hover/click area is NOT where the row appears during the 0.25 s slide. Keep durations short, accept it, but do not put the tooltip re-show for "row under the mouse" inside the animation window.
- "Rows sliding up when one leaves" is a different animation: after the data changes, the ScrollBox has already laid rows out at their NEW positions, so the slide must be "from old offset to 0" (Translation with offset = oldTop - newTop played AFTER layout). That requires recording each surviving row's key and `GetTop()` BEFORE the update and applying after it; a `Translation` that runs "up" by one row height after layout would be wrong when several rows left, when scrolled, or when the removed row was above a section header. Sections and headers (items with `header`) shift too.
- Scrolling during the animation: ScrollBox re-lays out frames on scroll; the Translation is relative to anchors, so it follows, but newly acquired frames while scrolling are not animated and old ones are released mid-slide (needs the resetter stop above). Disable animation when the list is scrolled (`GetScrollPercentage() > 0` or the top row isn't the first data row) or reduce motion.
- Alpha: an `Alpha` animation with `SetToFinalAlpha(false)` snaps back to 1 when it ends, flashing the row before the data update; `SetToFinalAlpha(true)` keeps 0 until reset. The code's choice (`out`) is right but depends on every path that reuses the frame calling `SetAlpha(1)`; make that part of the resetter, not only `FillRow`.
- Slower swipes (the milestone's tuning) widen the window in which `Read()` is deferred (`swiping`/`readAfterSwipe`, InPlace.lua:92-141): a user clicking Browse, switching activity, or a quiet refresh answering a second time during the longer swipe sees the old list. Make `swiping` cancel on a new search (`OnSearch` should clear it and `Stop()` playing groups) and keep the total delay short (0.4 s max).
- Swipes in preview mode (backlog): `SwipeRows` uses `T.instances`' `list:ForEachFrame`, and the stand-in's fallback list is `W.List` (UI/Widgets.lua:704). The preview must produce the same went/came key sets; `ns.Listings.Key(item)` for preview listings must be stable across "refreshes" (Preview.lua rebuilds `ns.state.listings`, `ResetState` copies), or every row swipes.

**How to avoid:** One shared `ResetRow(frame)` (stop group, alpha 1, clear offsets) called from the resetter and from `FillRow`; guard all play calls with `frame:GetParent() and frame:IsVisible()`; a global "animations enabled" check including the setting and `InCombatLockdown()`-independent (animations are not protected, combat is fine).

**Warning signs:** Invisible row that reappears when scrolled; a row sliding that belongs to a different listing; flicker on the last row of a swipe; rows jump instead of sliding up; preview swipes every row.

**Phase to address:** Dynamic refresh polish (including the preview swipes).

---

### Pitfall 9: Tooltips on inline `|T..|t`/`|A..|a` markup need hit frames, and hit frames break the row's mouse handling

**What goes wrong:** The region flag, new-player icon, friend marks and role icons in the name/roles cells are inline markup in a FontString (`Table.lua:1183`, `ns.Region.Markup`, `W.Marks`, `W.Icon`, `RoleMarkup`). A FontString has no mouse events, so a tooltip needs an overlay frame positioned over the icon. Problems:
1. Position: icon x-offset = width of the text before it. The name FontString is width-bound (`row.name:SetWidth(NAME_W)`) and ellipsized; `GetStringWidth()` may return the untruncated width, so a hit frame can sit beyond the clip. The existing Discord icon already solves it as a separate texture placed at `20 + min(GetStringWidth(), maxW) + 4` (Table.lua:1186-1191); follow that: promote icons that need tooltips to textures (frames) rather than markup, and hide them when clipped. Measure the prefix with a hidden measuring FontString of the same font if markup must stay.
2. Mouse focus: a mouse-enabled child frame takes focus from the row, so the row's `OnLeave` fires (hover highlight flickers, the re-shown row tooltip hides), and clicks (select, Whisper right-click menu `CreateSearchEntryMenu`) never reach the row. Use `hit:SetPropagateMouseMotion(true)` and `hit:SetPropagateMouseClicks(true)` (both documented, `Blizzard_APIDocumentationGenerated/SimpleScriptRegionAPIDocumentation.lua:677,689`) and call the row's tooltip-owner logic from the icon `OnEnter`.
3. Ownership: the ScrollBox resetter hides the tooltip only `if GameTooltip:GetOwner() == frame` (Table.lua:1541-1545). When the owner is an icon hit frame this is false and the tooltip survives a recycled row, then the "re-shown for the row under the mouse whenever results update" logic can show the previous listing's icon text. Compare against `owner == frame or owner:GetParent() == frame` or use a `row.tgfHits` list.
4. Pooling: hit frames belong to the row, are reused with new data in `FillRow`; every fill must `Hide()` those not needed and rewrite their text, or a stale flag tooltip shows on a row without a flag. Greyed rows use `Plain(text)` (colour stripped) for markup; the hit frames must follow the greyed state too.
5. Don't make frames per row per fill: create them once per row (in the row `Init`, not `FillRow`) or 100 listings leak frames on each refresh.

**Phase to address:** Tooltips on every row icon (and region flags, which add the first new icon).

---

### Pitfall 10: Region flags: the shard table is shared, persistent and partly unconfirmed

**What goes wrong:** `Region.lua` learns shard IDs from your own realm and Battle.net friends' game accounts and saves them in `db.shards` (line 111-116); `KNOWN` has 5 IDs from one observation. Pitfalls:
- `learned` OVERRIDES `KNOWN` in `R.Of` and is persisted forever. One wrong learn (a friend's game account on another ruleset or a differently named shard, `R.Group` regex `^CAMWOW(%a%a%d*)REALM` on a name that happens to match) permanently mislabels a shard. There is no expiry or revalidation.
- The mapping "US1 = West, US2 = East" is still an assumption (`PLACES` in Region.lua, comment line 19). A wrong mapping shows a confidently wrong flag, worse than none. Confirm in game (the milestone requires it) with two independent signals (e.g. players you know, latency, the preferred-play-setting localities in the probe) before shipping; keep the label wording neutral ("US East") only after that.
- The shard ID comes from `partyGUID`; it is the LEADER's shard for groups. For solo listings `info.partyGUID` is still read (Listings.lua:207) but it is unverified that it carries the player's shard; if it is empty/secret, `Server()` returns nil and no flag shows (correct). Make sure a `nil` shard never matches `learned[nil]`.
- Several realms share a group: observed shard IDs 6930/6933/6934 are all `US2`; unknown new realms appear as the server adds them. Unknown = no flag, correct, but the table needs a visible diagnostic path (`/tgf region`) and a hard rule to never guess by numeric closeness.
- Different rulesets (PvP/PvE/RP) are different shards of the same group; the finder lists only your ruleset, so one group name per ID is enough, but IDs learned from friends on other rulesets are stored too, harmless except for table growth. Cap or prune entries with a small ceiling.
- `GetRealmID()/GetRealmName()` and BN account info can return secret values; the code guards with `Plain()`; keep every new reader through the same guard.
- The flag assets: `Media/Textures/flag_us.tga`/`flag_au.tga` ship only if git tracks them (install/package scripts filter by `git ls-files`, scripts/package.ps1:59-67); adding an EU or other flag untracked silently drops it from the zip. The TGA must be power-of-two (the markup uses 64x64, `Region.lua:79`).
- Inline markup coordinates `:64:64:0:64:12:52` crop the flag; if the texture is replaced at another size the crop silently distorts.

**How to avoid:** Keep `KNOWN` as ground truth for confirmed IDs and only let `learned` ADD unknown IDs (never override), record when and from what a shard was learned, and make a `/tgf region` row show which source decided. Ship "unknown = no flag" and only show the E/W letter once the mapping is confirmed.

**Phase to address:** Region flags (needs a live confirmation step before the Release Review).

---

## Moderate Pitfalls

### Pitfall 11: Settings API: combat, restricted open call, unique variable names, function arguments

**What goes wrong:**
- The modern Settings API is fenced: every inbound call goes through `SettingsInbound` attribute delegates (`Blizzard_Settings_Shared/Blizzard_SettingsInbound.lua:98-140`), table writes happen under `securecallfunction` (`Blizzard_Setting.lua:404-427`), so registering a category and checkboxes does NOT taint the panel the way old `InterfaceOptions` did. Use `Settings.RegisterVerticalLayoutCategory` + `Settings.RegisterAddOnSetting` + `Settings.CreateCheckbox` + `Settings.RegisterAddOnCategory` (`Blizzard_Settings.lua:119-176`); do not build a hand-made options frame and do not write fields on `SettingsPanel`.
- `Settings.OpenToCategory` calls `C_SettingsUtil.OpenSettingsPanel` which is documented `HasRestrictions = true` (`Blizzard_APIDocumentationGenerated/SettingsUtilDocumentation.lua:15`); the precondition's failure mode is `ReturnNothing` (`ActionDocumentation.lua`), i.e. it silently does nothing when restricted. The exact restriction (combat? hardware event?) is not stated in the docs: LOW confidence. Gate our slash command/button with `InCombatLockdown()` and print a message (the project already does this in `IP.Open`).
- Variable names must be unique across all addons (`Blizzard_Setting.lua:390-395`); prefix `TGF_`. `ErrorIfFunctionArgs` rejects function values for most arguments (`SettingsInbound.lua:105-116`): defaults and names must be plain values (or wrapped getters through the proxy setting). Default type must match the declared type (`Blizzard_Setting.lua:31-50`).
- `Settings.GetValue` can return nil before registration; our readers must read `ns.db.<key>` directly (the AddOnSetting writes that same key, `SecureSetValueDerived`), not cache booleans at load, or toggling in the panel has no effect until `/reload`. Apply changes immediately through `Settings.SetOnValueChangedCallback(variable, fn)` for ones with live state (hide the sheet row, stop swipes).
- Commit semantics: settings with `CommitFlag.Apply` are pending until the panel's Apply; addon checkboxes default to immediate, keep it that way.
- A button that "opens the finder on the Messages tab" uses `CreateSettingsButtonInitializer` (`Blizzard_SettingControls.lua:1040`). Its click calls our code which calls Blizzard's `LFGVanilla_ToggleFrame` (restricted-open rules, existing combat guard). Do not call `HideUIPanel(SettingsPanel)` or `SettingsPanel:Close()` from our tainted click: closing runs the panel's commit/revert logic. Open the finder alongside and let the player close the panel; verify both panels show at once (UIPanel area clash), else print a hint. LOW confidence: untested.
- The preview stand-in (`UI/MainFrame.lua`, used where the game finder is missing) has no Blizzard Settings panel to show; the settings window needs a fallback or the preview toggles must still work from the DB. Since the finder is "in place only", do not create a second custom settings window as the main path.
- Settings changes while a quiet refresh/swipe is playing must not leave animations paused or `swiping` stuck true.

**Phase to address:** Settings window (after the item level and Dynamic refresh phases exist, since each toggle needs a hook point; build the DB keys first).

### Pitfall 12: Dynamic refresh and Blizzard's restricted search

**What goes wrong:** `C_LFGList.Search` is restricted; from a timer it raises `ADDON_ACTION_BLOCKED` (known fact). Everything in Dynamic refresh polish must keep the rule: our own search call only from the click or key press that opens Browse (`topic/dev` exception in CLAUDE.md). The `REFRESH_WAIT = 10` timer (InPlace.lua:60) only drops a stale state, it does not call Search. Do not add "refresh every N seconds" while the window is open, however tempting after making swipes pretty; the quiet-merge path should only change how an answer is read. Also never write fields on `LFGBrowseFrame` (the code reads `LFGBrowseFrame.searching`/`searchFailed` and `CategoryDropdown.selectedValues`; reading is fine, `Hook`/`hooksecurefunc` fine).
- A quiet search's `refresh.pending` suppresses the spinner; if the answer never comes and the user changes filters, `FilterKey` guards it. Keep every new state bit reset in `OnSearch`.
- Making the setting off must restore stock behaviour (spinner, list blank) with no leftover hook reading nothing.

**Phase to address:** Dynamic refresh polish; Settings (toggle off path).

### Pitfall 13: Player tooltip async line and secret units

**What goes wrong:** `OnTooltipUnit` filters `tooltip ~= GameTooltip`, so unit tooltips on other tooltips (nameplates, `ItemRefTooltip`) never get the line; fine. `tooltip:GetUnit()` can return secret unit tokens in restricted contexts (the code already guards `Secret(unit)`). The async refresh (`RefreshTooltip`) re-shows the tooltip with `GameTooltip:Show()`, which re-runs nothing but resizes; keep it and add a line only if the tooltip still shows the same GUID and does not already contain an "Item Level" line (a `TOOLTIP_DATA_UPDATE` rebuild between inspect and read would already have added it: re-check `FindUnit` and scan existing lines). Hostile/attackable players never looked up (stay as is). Rate limit stays (1.5 s gap, 30 s retry); keep it independent of the new Inspect window text so the two readers do not both trigger inspects.

**Phase to address:** Item level on player tooltips.

### Pitfall 14: `/tgf ilvl` probe and gear score leftovers keep NotifyInspect behaviour alive

**What goes wrong:** Removing GS removes the ready-check group inspect (`GearScore.lua`), which shared `Busy()`/queue code with nothing but may still be referenced from `ItemLevel.lua` through `ns.GS`. After deletion any `ns.GS.` call errors in a rarely used path (ready check, tooltip). Grep for `ns.GS`, `GEAR_SCORE`, `GS(` in `UI/Widgets.lua`, `UI/Table.lua` (sort key `gs`, `ListingGS`, `row.gs`), `Messages.lua` (`{gs}` placeholder, if any remains), `Preview.lua` before deleting the file.

**Phase to address:** Gear score removal.

---

## Minor Pitfalls

- **Character sheet value colour:** `PaperDollFrame_SetItemLevel` returns a number but only `PaperDollFrame_UpdateStatsInternal` (old pane) colours via `GetItemLevelColor()`; the scroll pane shows white text. Do not set colours by writing to the frame (frames are pooled).
- **Pet pane:** the pet scroll box shares `PAPERDOLL_STATCATEGORIES` and filters on `unit`; verify the new row never appears for pets (`PaperDollFrame_SetItemLevel` hides it for non-player units but the `hideAt` row may still reserve space).
- **Sheet row tooltip:** statFrame `tooltip/tooltip2` are set by Blizzard's function; if you make your own `updateFunc`, set them too or hovering shows nothing.
- **`stylua .` and XML:** new files must be added to the TOC load list in dependency order; `install.ps1` derives files from the TOC and a forgotten file never ships.
- **Changelog rule:** a bug created and fixed inside v0.2 (e.g. a double tooltip line during development) must not be mentioned outside `.planning/` (project rule).
- **Settings text:** hard-coded English strings; `Interface Options` search tags are optional.

---

## Technical Debt Patterns

| Shortcut | Immediate Benefit | Long-term Cost | When Acceptable |
|----------|-------------------|----------------|-----------------|
| Write `PAPERDOLL_STATCATEGORIES` once at load | Only practical way to add a sheet row | A taint point on the character sheet | Acceptable, once, documented, behind a toggle |
| Keep `ItemLevel.lua` as one 580-line file with probe + tooltip + inspect queue | No refactor | Inspect window, sheet, item tooltip all want the same cache and guards; duplication creeps | Split the cache/inspect queue from the display spots in this milestone |
| Markup icons in the name FontString with hit frames on top | Re-uses existing markup | Position drift, clipping, mouse focus bugs | Only for icons that need no tooltip; tooltip icons become real textures |
| `learned` overrides `KNOWN` | Self-healing table | One wrong learn is permanent | Never; let `learned` only fill gaps |
| Animations on frames, keyed by listing at play time | Simple | Pool reuse bugs | Acceptable if reset in the resetter and guarded by key at play time |
| `pcall` around every Blizzard-facing read | No crash | Silent feature loss | Fine, but log at most once (debug flag) |

## Integration Gotchas

| Integration | Common Mistake | Correct Approach |
|-------------|----------------|------------------|
| Item tooltips | End-of-tooltip post-call, adding on every `Show` hook | `AddLinePostCall(ItemName)` only; skip when a type-31 line exists |
| Inspect window | Reading at ADDON_LOADED, assuming `InspectFrame` exists | `EventUtil.ContinueOnAddOnLoaded("Blizzard_InspectUI")`, read at paper-doll update |
| Inspect data | Trusting `GetInspectItemLevel(unit)` for whoever the token points at | Check `INSPECT_READY` GUID equals `UnitGUID(unit)` at read |
| Character sheet | Hand-anchoring under the Movement Speed frame | Add a stat entry to the player General category; reuse `PAPERDOLL_STATINFO.ITEMLEVEL` |
| Settings | Own options frame, caching settings at load, rebinding the DB table | Vertical layout category, read `ns.db` live, mutate DB in place |
| Settings panel | Closing it from our click | Leave the panel open, open the finder next to it |
| ScrollBox | Playing animations on whichever frame `ForEachFrame` gives before layout | After the update, find frames by key, reset in the element resetter |
| Search | Timer-driven `C_LFGList.Search` | Only from the opening click or key press; quiet merge only changes reading |
| Region | Trust "US1 = West" | Confirm, label neutrally until confirmed |

## Performance Traps

| Trap | Symptoms | Prevention | When It Breaks |
|------|----------|------------|----------------|
| Item tooltip post-call doing `GetItemInfo` + type scan on every rebuild | Stutter hovering inventory/merchant | One `GetDetailedItemLevelInfo`, one linear scan of ~15 lines | Fast mouse-over of bags (100s/s) still fine |
| Per-row hit frames recreated each `FillRow` | Memory growth, GC hitching on refresh | Create once per pooled row | Lists of 100+ listings refreshed repeatedly |
| Sheet row `updateFunc` called twice per update | Doubled work if it inspects or prints | Cheap pure function | Every equipment or speed event |
| Animation groups per row created lazily | One-time cost per frame | Fine, bounded by pool size | n/a |
| Inspect queue plus Inspect window reader both inspecting | Server throttling ("inspect flood") | One inspect owner, 1.5 s gap, none while the window is pending | Group of 5+ with hovering |

## Security Mistakes

| Mistake | Risk | Prevention |
|---------|------|------------|
| Writing fields on `LFGBrowseFrame`, `LFGParentFrame`, `InspectFrame`, `SettingsPanel` | Taint, blocked restricted calls (Search, Invite) | Hooks and our own child frames/regions only |
| Calling `C_LFGList.Search` from a timer | `ADDON_ACTION_BLOCKED` | Hardware-event-only, as documented |
| Sending addon messages during chat messaging lockdown | Error/ban risk | `C_ChatInfo.InChatMessagingLockdown()` guard, unchanged |
| Acting on secret values (compare, concatenate) | Lua errors in the tooltip/sheet paths | `issecretvalue`/`canaccessallvalues` first |

## UX Pitfalls

| Pitfall | User Impact | Better Approach |
|---------|-------------|-----------------|
| Item level shown on non-gear or with wrong heirloom value | Mistrust of the number | Equippable only, effective level |
| Item level line visually different from Blizzard's | Looks pasted-on | Yellow "Item Level N" under the name like the game's other levels |
| Swipes slower and also block reading | Feels laggy | Max ~0.4 s, cancel on new search/scroll, honour the setting |
| Flag guess wrong | Wrong region trust | Unknown = no flag, confirmed mapping only |
| Settings button opens the finder in combat | Silent failure | Print "can't open in combat" |
| Hit frames eat right-click on icons | Whisper menu unreachable on part of the row | Propagate clicks and motion |

## "Looks Done But Isn't" Checklist

- [ ] **Sheet row:** missing after `/reload` with the sheet open, in the pet pane, after equipping — verify all three and that the General category is the player's
- [ ] **Inspect text:** first inspect after login (addon not yet loaded), inspect of target vs group member, close during a quiet inspect, hover-inspect then click Inspect
- [ ] **Item tooltip:** inventory, bags, merchant, chat link (ItemRefTooltip), comparison tooltips, no duplicate on mouse hover for 3 s (data update rebuilds), item with no data yet
- [ ] **Settings:** every toggle takes effect without `/reload`, survives `/reload`, defaults correct on a fresh DB and on a v0.1 DB, opens in preview, in combat blocked with message
- [ ] **Migration:** v0.1 save with `gs` present loads clean, `gs` gone, `schema` 2, no new keys overwritten
- [ ] **Swipes:** list scrolled, row removed above/below a section header, two refreshes in a row, switch activity mid-swipe, preview mode
- [ ] **Row icon tooltips:** each icon, greyed rows, recycled rows, tooltip hides when the row is released, right-click still opens the menu, click still selects
- [ ] **Region:** unknown shard shows nothing, solo and group both, secret partyGUID shows nothing, zip contains flag textures (`git ls-files Media/Textures`)

## Recovery Strategies

| Pitfall | Recovery Cost | Recovery Steps |
|---------|---------------|----------------|
| Sheet row taint trouble | LOW | Ship a default-off toggle; remove the global write; fall back to ilvl only on tooltip/Inspect |
| Wrong shard mapping shipped | LOW | Patch `KNOWN`/`PLACES`, add `db.shardsVersion` and wipe `db.shards` on mismatch |
| Orphaned settings table | LOW | Re-point settings to `ns.db` after migration; remove any `TerribleGroupFinderDB = {}` |
| Stuck invisible rows | LOW | Stop+reset in resetter; `/tgf reset` already refreshes |
| Duplicate tooltip lines | LOW | Remove secondary add paths, keep processor-only |
| Inspect data cleared by us | MEDIUM | Add the pending-inspect guard; requeue |

## Pitfall-to-Phase Mapping

| Pitfall | Prevention Phase | Verification |
|---------|------------------|--------------|
| 7 Migration and GS removal | Gear score removal (first) | v0.1 save loads, no `gs`, no nil `ns.GS` |
| 3 Inspect collisions | Item level on player tooltips / Inspect | Click Inspect while hovering; data not cleared |
| 4 LoD Inspect UI | Inspect window text | First inspect after login shows the text |
| 5, 6 Item tooltip | Item tooltips | No duplicates, comparison tooltips, equippable only |
| 1, 2 Sheet row | Character sheet | Live check list, player pane only, no taint report |
| 11 Settings | Settings window | Toggles live, survive reload, combat message |
| 8, 12 Swipes and refresh | Dynamic refresh polish | Frame-reuse and scroll cases above, preview parity |
| 9 Hit frames | Tooltips on every row icon | Hover, click, right-click, recycle cases |
| 10 Region | Region flags | Confirmed mapping, unknown shard, packaged textures |
| 13, 14 | Item level phases; GS removal | Grep clean, no extra inspects |

## Needs a live check (could not be proven from source)

- Does tainted `UpdateStats` break the sheet in combat after our `PAPERDOLL_STATCATEGORIES` write (watch `ADDON_ACTION_*`, `/console taintLog 2`)?
- Does Forever's item tooltip data already carry an `ItemLevel` (type 31) line for any item?
- What exactly does `C_SettingsUtil.OpenSettingsPanel`'s `HasRestrictions` forbid (combat or hardware event)?
- Is `InspectFrame.unit` set before `INSPECT_READY` fires when the window is opened by clicking a unit (assumed from `InspectFrame_Show`)?
- Is `partyGUID` present and equal to the player's shard for SOLO listings?
- Is US1 West and US2 East (not just assumed)?
- Does `SetDataProvider` acquire frames synchronously in our ScrollBox setup (affects `SwipeIn`)?

## Sources

- `Blizzard_UIPanels_Game/Camelot/CharacterFrame.lua` (823, 1036-1290), `PaperDollFrame.lua` (110-145, 1378-1470, 2403-2500), `PaperDollFrameConstants.lua` (35-125) in wow-ui-source `forever` (HIGH)
- `Blizzard_InspectUI/Blizzard_InspectUI.toc`, `Camelot/Blizzard_InspectUI.lua`, `Mainline/InspectPaperDollFrame.lua`, `Mainline/Blizzard_InspectUI_Bootstrap.lua` (HIGH)
- `Blizzard_SharedXMLGame/Tooltip/TooltipDataHandler.lua`, `TooltipDataRules.lua`; `Blizzard_GameTooltip/Mainline/GameTooltip.lua:970` (HIGH)
- `Blizzard_APIDocumentationGenerated/{PaperDollInfo,Item,TooltipInfoShared,SettingsUtil,SimpleScriptRegionAPI,Unit}Documentation.lua` (HIGH)
- `Blizzard_Settings_Shared/{Blizzard_Settings,Blizzard_SettingsInbound,Blizzard_Setting,Blizzard_SettingsPanel,Blizzard_SettingControls}.lua` (HIGH)
- `Blizzard_SharedXML/Shared/Scroll/{ScrollBox,ScrollBoxListView}.lua`, `Blizzard_SharedXML/EventUtil.lua:67` (HIGH)
- Addon repo: `Core.lua`, `ItemLevel.lua`, `Region.lua`, `Listings.lua`, `UI/Table.lua` (1130-1275, 1525-1580, 1835-1891), `UI/InPlace.lua`, `.pkgmeta`, `scripts/*.ps1` (HIGH, own code)
- Taint spread through `securecallfunction` initializers and the HasRestrictions semantics: reasoning from source only (LOW-MEDIUM)

---
*Pitfalls research for: WoW Forever group finder addon, milestone v0.2*
*Researched: 2026-11-14*
