# Feature Research: v0.3.0 (Elite quest button, per-slot gear info, opt-in defaults, settings sections)

**Domain:** WoW Forever (`camelot`, interface 16001) group-finder addon, subsequent milestone
**Researched:** 2026-11-24
**Confidence:** MEDIUM overall. Blizzard-source claims are HIGH (read on the `forever` branch, cited file:line). Forever gameplay facts (sockets, which quests are elite, ring enchants) are LOW to MEDIUM (fan sites, beta data, no Blizzard statement). Taint behaviour of the create route is untested, LOW.

Paths below are relative to `C:\Users\jonat\Repositories\wow-ui-source\Interface\AddOns\` (branch `forever`) unless they start with a project name.

---

## Headline findings (read these first)

1. **Forever has no `LFGListUtil_FindQuestGroup`.** `Blizzard_GroupFinder` (the retail finder that owns it, `LFGList.lua:4594`) is `## ExcludeLoadGameType: camelot` (`Blizzard_GroupFinder/Blizzard_GroupFinder.toc:10`). Forever's `Blizzard_GroupFinder_VanillaStyle` has no quest code at all: a grep for `Quest` / `questID` over its Lua and XML finds only the category 116 icon constant (`Mainline/LFGVanilla_Constants.lua:12,19`). The button's retail click path (search first, then "create group" with the quest filled in) does not exist here and cannot be called. Our button must build its own route out of the vanilla finder's pieces.
2. **The description box cannot be written by an addon.** The Listing tab's comment edit box is created with `SetSecurityDisableSetText()` and `SetSecurityDisablePaste()` (`Blizzard_GroupFinder_VanillaStyle/Mainline/Blizzard_LFGVanilla_Listing.xml:615-617`). "Quest name as the description" is impossible by direct write. Drop it, or replace it with a hint of our own (see F2).
3. **Forever's finder cannot tag a listing with a quest.** `CreateOrUpdateListing` calls `C_LFGList.CreateListing` with only `activityIDs`, `newPlayerFriendly`, `generalPlaystyle` and `voiceMode` (`Blizzard_LFGVanilla_Listing.lua:315-320`). No `questID`, and the comment is not passed (it goes through the creation text fields). A quest group on Forever is identified by its activity and description text only. So "find groups for this quest" is a text match, not a quest-ID search.
4. **Sockets and gems probably never appear on Forever.** Vanilla-era itemization has no sockets and nothing found says Forever adds them. Blizzard's own socket overlay on the slot buttons is hard-gated to Timerunning (`Blizzard_UIPanels_Game/Camelot/PaperDollFrame.lua:3578`, `PlayerIsTimerunning()`). Build the socket display so it shows nothing when an item has no sockets, and treat it as a low-value row to verify in game before investing.
5. **Enchant slots differ from retail and Forever adds some.** Neck and off-hand are new enchantable slots in Forever (Warcraft Tavern: "Neck items can't be enchanted in any version of WoW Classic" before this). Ring enchants are mentioned by one source only (LOW). A hard-coded per-slot "enchantable" table is needed, because no API says whether a slot can take an enchant.

---

## Feature Landscape

### F1. Opt-in defaults (all extras off for new installs)

#### Table Stakes

| Feature | Why Expected | Complexity | Notes |
|---------|--------------|------------|-------|
| Defaults: only Elite quest button, Dynamic refresh, Swipe animations, Region flags on | The milestone's goal; avoids clashing with other addons | LOW | Change `default` on `ilvlPlayerTooltip`, `specPoints`, `ilvlItemTooltip`, `ilvlCharacterSheet`, `ilvlInspect`, `meterResetOnInstance` to `false` in `Settings.lua:122-185` (all currently default true, see `Settings.lua:186-190`). `meterResetOnGroup` is already false. |
| Existing players keep today's behaviour | Silent loss of a feature on update is the worst outcome | MEDIUM | `ns.Migrate` schema 4 (`Core.lua:25-47`). Settings are saved only once set (`Settings.lua:70-73`), so a player who never touched an option has NO key stored and would flip to the new default. The step must write explicit `true` for each of the six keys above whose saved value is not a boolean, when `existing` (table held any key before the step). |
| Migration never overrides a choice the player made | Same | LOW | Same guard as v0.2.2's `type(db.meterResetOnGroup) ~= "boolean"` check (`Core.lua:42`). |
| New gear-info keys default off, with nothing to migrate | Existing players never had them | LOW | Nothing to save for existing players: absent = off. |
| `/tgf set <key> on|off` and the settings page keep working on the new keys | Existing surface | LOW | New keys go through `ns.Settings.Register`; they must not collide with `RESERVED` (`Settings.lua:20-21`). |

#### Differentiators

| Feature | Value Proposition | Complexity | Notes |
|---------|-------------------|------------|-------|
| Panel "Defaults" button restores the new opt-in defaults | Consistency (the panel's Defaults already saves defaults, per CLAUDE.md) | LOW | Falls out of changing `default`. Verify the Defaults click saves `false` for the six moved options. |

#### Anti-Features

| Anti-Feature | Why Requested | Why Problematic | Alternative |
|--------------|---------------|-----------------|-------------|
| Pop-up on first run asking which extras to enable | Discoverability | Intrusive, another dialog, taint-neutral but noisy | One line in the changelog; the settings page lists everything. |
| Migrating existing players to "off" to match new installs | Uniform behaviour | Breaks things players rely on | Keep their current values (the author's decision). |
| Version-gated `if schema < 4` that also wipes other keys | Tidy | Risk to `invite` / `request` / `shards` / `meterPos` | Touch only the six keys. |

Gotchas for requirements:
- A v0.2.2 player is "existing" once any key (even `schema`) was saved. `existing` is evaluated before DEFAULTS fill in (`Core.lua:35-38`); keep that ordering.
- `meterResetOnGroup`: schema 3 already saved `true` for pre-v0.2.2 players. A v0.2.2 fresh install has it unsaved and off; leave it off.
- CLAUDE.md's Settings paragraph ("default on except `meterResetOnGroup`") and the `Core.lua` architecture line must be updated to schema 4 in the same milestone.

---

### F2. Elite quest eye button in the objective tracker

#### How retail's button works (source-verified)

| Aspect | Retail behaviour | Source (forever branch) |
|--------|------------------|-------------------------|
| Template | `QuestObjectiveFindGroupButtonTemplate`, a `Button`, 30x30, `motionScriptsWhileDisabled` | `Blizzard_ObjectiveTracker/Blizzard_ObjectiveTrackerShared.xml:65-66` |
| Look | Icon texture atlas `socialqueuing-icon-eye`, 13x13, anchored CENTER at x=-1; Normal / Pushed / Disabled = `Interface\Buttons\UI-SquareButton-Up / -Down / -Disabled`; highlight `Interface\Buttons\UI-Common-MouseHilight`, ADD blend, alpha 0.5 | `Blizzard_ObjectiveTrackerShared.xml:66-80` |
| Press feel | Mouse down moves the icon to (-2,-1), mouse up to (-1,0) | `Blizzard_ObjectiveTrackerShared.lua:186-196` |
| Tooltip | `GameTooltip:SetOwner(self)`, one line `TOOLTIP_TRACKER_FIND_GROUP_BUTTON` in highlight (white) colour. The string is a client GlobalString, not in the UI source; reference it as `_G.TOOLTIP_TRACKER_FIND_GROUP_BUTTON` with a fallback (my recollection of the English text is "Find a Group for this Quest", LOW) | `Blizzard_ObjectiveTrackerShared.lua:198-203` |
| Click | `LFGListUtil_FindQuestGroup(questID, true)`; the `true` (`isFromGreenEyeButton`) means the Create Group button only appears when groups already exist | `Blizzard_ObjectiveTrackerShared.lua:205-210` |
| What the click does (retail) | Active listing: delist warning or open the finder. Otherwise `LFGListFrame_BeginFindQuestGroup`: needs the quest name loaded, looks up `C_LFGList.GetActivityIDForQuestID`, shows the finder, selects the category, starts the search, sets creation auto-fill mode "quest" | `Blizzard_GroupFinder/Mainline/LFGList.lua:4594-4604`, `:513-536`, `:4556-4592` |
| Where shown | Quest tracker and Bonus-objective tracker only, when `QuestUtil.CanCreateQuestGroup(questID)` is true (server answer, cached per quest) | `Blizzard_ObjectiveTracker/Blizzard_QuestObjectiveTracker.lua:308-310`, `Blizzard_BonusObjectiveTracker.lua:343-344`, `Blizzard_FrameXMLUtil/Mainline/QuestUtils.lua:375-387` |
| Placement | Not right of the title text: pinned to the block's TOPRIGHT at offset (5, 2), via `AddRightEdgeFrame`. A second right-edge frame (the quest item button) sits to its left with 2 px spacing. The block then shrinks the header text's right edge by the button's width, so a long title wraps instead of running under the eye | `Blizzard_QuestObjectiveTracker.lua:13-17`; `Blizzard_ObjectiveTrackerBlock.lua:347-372`, `:337-341`, `:156` |
| Scenario variant | A separate `ScenarioObjectiveTrackerFindGroupButtonTemplate` at TOPRIGHT (-30, 5), not relevant here | `Blizzard_ScenarioObjectiveTracker.lua:586-597` |

Forever specifics:
- The tracker is the modern one; Camelot only overrides the tag text (`Blizzard_ObjectiveTracker/Camelot/Blizzard_QuestObjectiveTrackerOverride.lua:5-7`). The title shows "(Elite)", "(Dungeon)", "(PvP)" or "(Raid)" as text (`Blizzard_FrameXMLUtil/Camelot/QuestUtilsOverrides.lua:20-35`) and a `[level+]` prefix where "+" means `C_QuestLog.IsEliteQuest` (`:6-9`).
- Whether `C_LFGList.CanCreateQuestGroup` returns true for anything on Forever is unknown; the retail finder it feeds isn't loaded. Do not depend on it. Decide by `C_QuestLog.IsEliteQuest(questID)` (documented, `Blizzard_APIDocumentationGenerated/QuestLogDocumentation.lua:749`) or tag ID 1 (`QUEST_INFO_ELITE_ID = 1`, `QuestConstantsDocumentation.lua:149`; `Enum.QuestTag.Group = 1`, `QuestLogDocumentation.lua:1507`). Elite and Group are the same tag ID.
- Which quests are elite in the vanilla-era game: no authoritative list found. Fan guides name elite quests in Duskwood (up to level 35) and Wetlands ("The Dark Iron War", level 30), and many dungeon quests. Dungeon and raid quests carry their own tags (81 and 62), distinct from Elite (1); the milestone says elite (group) only, so they get no button. Do not hard-code quest IDs; the tag is the source of truth and works for new Forever quests.

#### Table Stakes

| Feature | Why Expected | Complexity | Notes |
|---------|--------------|------------|-------|
| Eye button on tracked elite quest blocks, tracker only | Milestone scope; matches retail muscle memory | MEDIUM | Our own Button parented to the quest block, anchored TOPRIGHT (5, 2) like retail; re-attached after each tracker update by a `hooksecurefunc` on the quest module's update (`QuestObjectiveTrackerMixin:UpdateSingle`, `Blizzard_QuestObjectiveTracker.lua:291`). Blocks are pooled and reused, so show/hide per questID on every update. |
| Retail look | Milestone: "looking like retail's" | LOW | Copy the template's textures and atlas exactly (`socialqueuing-icon-eye` 13x13, the three UI-SquareButton files, MouseHilight). Atlas may be missing on Forever: check with `C_Texture.GetAtlasInfo` and fall back to a plain texture (the repo's `W.IconButton` already does atlas-first, plain fallback). |
| Retail tooltip | Same | LOW | `_G.TOOLTIP_TRACKER_FIND_GROUP_BUTTON` (client-localized) with an English fallback. |
| Click opens Forever's finder at the right place | The feature's point | HIGH | See "Click route" below. This is the milestone's riskiest item. |
| Never shown on non-elite quests, nor in the quest log | Scope | LOW | Backlog 999.5 (quest log) is folded in but the milestone narrows it to the tracker. |
| Setting "Elite quest button" in Group finder, default on | Opt-in rules | LOW | Read with `ns.Settings.Get` where it acts; toggling hides every button. |
| Out-of-combat only for the click | Protected UI / taint | LOW | Show/hide of our own frame is fine in combat; the click's finder-opening must be skipped in combat (the existing `IP.OpenMessages` already does this). |

#### Click route (what is and isn't possible)

| Step | Possible? | How / constraint |
|------|-----------|------------------|
| Open Forever's finder | Yes | Already done for Messages by `IP.OpenMessages()` (CLAUDE.md, `UI/InPlace.lua`): show `LFGParentFrame`, select a tab. Precedent exists. |
| Select the Quests & Zones category (116) on the Listing tab | UNCERTAIN, taint risk | `LFGListingFrame:SetCategorySelection(116)` (`Blizzard_LFGVanilla_Listing.lua:342-348`) writes `self.categorySelection` and, when the category auto-chooses activities, `self.activities` (`:373-374`). Called from addon code those writes are tainted; secure `CreateOrUpdateListing` (`:264`) then reads them and `C_LFGList.CreateListing` (`:315`) can be blocked. CLAUDE.md forbids writing fields on Blizzard's finder. Candidate route to test in game: make the eye a `SecureActionButtonTemplate` whose action clicks Blizzard's own category button securely (`type=click` / macro `/click`), so the handler runs untainted. Not testable from source. |
| Select the quest's specific activity | UNCERTAIN | Retail maps quest to activity with `C_LFGList.GetActivityIDForQuestID` (`LFGList.lua:4564`), which is not in the generated API docs for this branch (`Blizzard_APIDocumentationGenerated/LFGListInfoDocumentation.lua` has `CanCreateQuestGroup` and `SetSearchToQuestID` only). Existence on Forever must be checked in game. If the category auto-chooses (`autoChooseActivity`, `Blizzard_LFGVanilla_Listing.lua:889-905`), every activity is pre-selected and there is nothing to pick. |
| Quest name as description | NO (direct write) | See headline 2. The box is also "required" for auto-choose categories (`LFGListingActivityView_CanPostWithCurrentComment`, `:1164-1171`), so the player must type something anyway. |
| Search first (show groups already doing the quest) | PARTIAL | `C_LFGList.Search` is a restricted call and stays Blizzard's. We can drive our own table instead: open Browse and put the quest name in our own search box (`UI/Table.lua:1844-1862`, a filter over results, "Name, activity, note"). That filter is ours, so it is not a taint concern. |

Recommended route for the roadmap (opinionated): ship the button with the most conservative behaviour first (open the finder; Browse tab with our search box prefilled with the quest name; print the quest name in chat or show it in our own hint so the player can type it into the description), and gate "ready to create" (category 116 preselected) behind a spike that proves the secure-click route does not break the Post button. If the spike fails, the milestone still delivers the one-click shortcut.

#### Differentiators

| Feature | Value Proposition | Complexity | Notes |
|---------|-------------------|------------|-------|
| Hint banner on the Listing tab: "Quest: <name>" (our own frame, parented to `LFGListingFrame`) | Replaces the impossible description prefill; player copies by typing | LOW | Own FontString, not a write to Blizzard's box. Disappears on tab change or listing. |
| Prefill our table's search box with the quest name on click | One-click "find groups for this quest" | LOW | Uses `UI/Table.lua`'s existing search; clear it after use so a later search isn't surprising. |
| Dim or hide the eye while a listing is active, with tooltip "You already have a listing" | Retail shows a delist warning (`LFGList.lua:4595-4600`) | LOW | `C_LFGList.HasActiveEntryInfo()` read-only. |
| Eye for Dungeon / Raid tagged quests (setting, default off) | Dungeon quests are the commonest group content | LOW | Out of milestone scope; mention as a later option. |

#### Anti-Features

| Anti-Feature | Why Requested | Why Problematic | Alternative |
|--------------|---------------|-----------------|-------------|
| Calling `AddRightEdgeFrame` / replacing `findGroupButtonSettings` on the tracker module | "Native" layout, free header shrink | Writes fields on Blizzard's tracker blocks and module; CLAUDE.md taint rule; the tracker's quest item button is a secure template | Own button parented to the block, anchored TOPRIGHT; accept that a very long title may sit under the eye (or move the header's right anchor only if a spike shows it is safe). |
| Writing the description (`EditBox:SetText`) | The stated wish | Blocked by design (`SetSecurityDisableSetText`) | Hint banner. |
| Calling `C_LFGList.Search` / `CreateListing` / `LFGBrowse_DoSearch()` from the click | One-click search | Restricted calls; CLAUDE.md keeps them Blizzard's; the dynamic refresh already hit `ADDON_ACTION_BLOCKED` from a timer | Let the player press Blizzard's own Search / Post. |
| Eye in the quest log | Backlog 999.5 original wording | Milestone narrowed to the tracker; quest log is a bigger secure surface | Defer. |
| Hard-coded list of elite quest IDs | Avoids tag API | Rots with every Forever patch (new quests added) | `IsEliteQuest` / tag 1. |
| Opening the finder automatically on accepting an elite quest | "Helpful" | Surprise UI, steals focus | Button only. |

---

### F3. Per-slot gear info (character sheet and Inspect window)

#### What players expect (generic behaviour of popular retail slot-overlay addons)

Evidence is thin: the one addon page read (SimpleItemLevel on GitHub) confirms item level on the character and inspect panels, flagging of missing enchants and gems, toggles per surface (`bags`, `character`, `inspect`) and a quality-colour switch. Everything else below is common practice from my own knowledge of such addons (MEDIUM/LOW).

- Item level as a small number on the slot icon corner, coloured by item quality.
- Enchant: short text beside the slot (name trimmed) or a red/"missing" mark when the slot is enchantable and empty. Text goes on the side away from the model.
- Gems: small icons beside the slot, empty-socket marker when a socket is unfilled.
- Inspect: same overlays once the inspected player's items have loaded; may be partial until item data arrives.
- Per-surface and per-element toggles (ilvl / enchant / gems each separate), a quality-colour option.

#### Forever specifics

| Question | Finding | Source / confidence |
|----------|---------|---------------------|
| Slot buttons | Character sheet and Inspect use the modern slot buttons, with left / right / bottom variants and named globals `CharacterHeadSlot` ... `CharacterRangedSlot`, `InspectHeadSlot` ... | `Blizzard_UIPanels_Game/Camelot/PaperDollFrame.xml:128-164, 779-870`; `Blizzard_InspectUI/Camelot/InspectPaperDollFrame.xml:44-52, 205-312`. HIGH |
| Update hooks | Character: `PaperDollItemSlotButton_Update(button)` (`PaperDollFrame.lua:2177`); Inspect: `InspectPaperDollItemSlotButton_Update(button)` (`Blizzard_InspectUI/Mainline/InspectPaperDollFrame.lua:245-272`) and `InspectPaperDollFrameMixin:UpdateButtons` (`:63-69`), already hooked by `ItemLevelUI.lua:330`. HIGH |
| Stock socket display | Each side slot template has a `SocketDisplay` frame, filled from `GetInventoryItemLink` in both updates, but `SetItem` shows it only for Timerunning (`PaperDollFrame.lua:2213-2215`, `:3574-3612`, gate at `:3578`). It uses `C_Item.GetItemNumSockets` and `C_Item.GetItemGemID`. HIGH. Do not reuse or call it (Blizzard state); build our own and use the same APIs. |
| Vanilla sockets | Vanilla-era items have no sockets. No source says Forever adds them (Method itemization article, Warcraft Tavern enchanting article: silent). LOW. In-game check needed with a `/tgf` probe; if no item reports sockets, ship the socket row as a no-op or drop it from the milestone. |
| Enchantable slots | Vanilla: head, shoulder (Zul'Gurub only), chest, legs, wrist, hands, feet, back, weapons, shield. Not neck, belt, rings, trinkets (Blizzard Watch, Warcraft Tavern; MEDIUM). Forever adds neck and off-hand (Warcraft Tavern, Blizzard Watch Sept 2026; MEDIUM) and one source mentions personal ring enchants (LOW). Ranged slot (scopes) unverified (LOW). Belt, trinkets, tabard, shirt: no. |
| Missing-enchant noise | Most players level without enchants; a red mark on every slot of a levelling character is noise. Beta cap is 30; final cap 60. Decide a policy (see Differentiators). |
| Enchant text source | `GetInventoryItemLink(unit, slot)` carries the enchant ID as field 2 after the item ID; the readable name needs the tooltip line `Enum.TooltipDataLineType.ItemEnchantmentPermanent` (= 15, `TooltipInfoSharedDocumentation.lua:49`) from `C_TooltipInfo.GetInventoryItem(unit, slot)` (`TooltipInfoDocumentation.lua:389-405`). No enchant-ID-to-name table is needed. Tooltip fields may be secret on the modern client: guard with `issecretvalue` as the rest of the addon does. HIGH (API), MEDIUM (line content on Forever, verify in game). |
| Gem icons | `C_Item.GetItemGemID(link, i)` then `C_Item.GetItemIconByID` after item load (the stock pattern, `PaperDollFrame.lua:3589-3607`). Gem data may arrive late; needs a retry or `ContinueOnItemLoad`. |
| Inspect data timing | The Inspect window triggers its own `NotifyInspect`; items may load after the first `UpdateButtons`. The existing text spot already hooks `UpdateButtons` and `SetLevel`, re-runs after a 0 s defer and retries three times 1 s apart (`ItemLevelUI.lua:262-313`). Reuse that pattern. |

#### Table Stakes

| Feature | Why Expected | Complexity | Notes |
|---------|--------------|------------|-------|
| Item level number on each slot (character sheet) | The headline of the feature; milestone text | MEDIUM | Our own FontString on a frame we parent to each slot button; `GetInventoryItemLink("player", slot)` then `C_Item.GetDetailedItemLevelInfo`, as `ILvl.Read` does (`ItemLevel.lua:333-366`). Colour by quality (`GetInventoryItemQuality`, or the item link's quality). Redraw on `hooksecurefunc(PaperDollItemSlotButton_Update)` plus `PLAYER_EQUIPMENT_CHANGED`. |
| Same on the Inspect window | Milestone | MEDIUM | Unit is `InspectFrame.unit`. Read the live inspect items (they are valid while the window is open); no cache. Redraw from the existing `UpdateButtons` hook and `INSPECT_READY`. |
| Enchant text or "missing" mark per enchantable slot | Milestone | MEDIUM | Static table of slots per item type (e.g. 1h/2h weapon yes, shield/off-hand yes, held-in-offhand no, wand/ranged unknown), read enchant ID from the link, name from the tooltip line. |
| Socket gem icons per slot | Milestone | MEDIUM | Only when `C_Item.GetItemNumSockets(link) > 0`. May be a no-op on Forever. |
| Empty slot shows nothing | Basic correctness | LOW | |
| Setting toggles in "Player inspection", default off | Opt-in milestone | LOW | One key per element or a master plus children (the settings registry supports `parent`, `Settings.lua:30-32`). I recommend three keys: item level per slot, enchants, sockets, so the sockets row can be dropped later without touching the others. |
| No taint | CLAUDE.md | MEDIUM | Own frames only, children of the slot buttons or of the paper doll; never write on slot buttons (`SocketDisplay`, `IconBorder`); only `hooksecurefunc`. The character sheet note in CLAUDE.md (stats data is read by secure code) applies to the stats list, not to slot buttons; an own child frame on a slot button is the same pattern as our own frames on `LFGParentFrame`. |
| Existing overall Item Level row and Inspect text stay | Milestone | LOW | `ItemLevelUI.lua:348-360, 483-560` untouched; new code is a separate installer (`UI.Install("slots", ...)`, `ItemLevelUI.lua:56-68, 681-685`), so one failure cannot break the others and `/tgf ilvl` lists it. |

#### Differentiators

| Feature | Value Proposition | Complexity | Notes |
|---------|-------------------|------------|-------|
| Smart missing-enchant policy: only flag when the slot is enchantable AND the player is at or above a level threshold (or the item is above a quality) | Avoids a wall of red on levelling characters | LOW | Needs a decision from the author; suggested default: flag only for level 60 (cap) or item level above a number. LOW confidence on thresholds. |
| Quality-coloured item level, white fallback toggle | Matches what players know from retail addons | LOW | |
| Tooltip on our enchant text (full enchant line) | Truncated names need it | LOW | Own tooltip via `W.ShowTip`-style helper, not the slot's tooltip. |
| Inspect shows slot data for another player once loaded, with "..." while loading | Honest partial state | MEDIUM | Reuse the retry pattern. |
| Feed ILvl's per-slot read with enchant and gem data so the tooltip spots could use it later | Single reader | MEDIUM | `ILvl.Read` already loops 19 slots (`ItemLevel.lua:335-360`); extend it rather than a second loop over slots. Keep the inspect cache unchanged (no per-slot storage). |

#### Anti-Features

| Anti-Feature | Why Requested | Why Problematic | Alternative |
|--------------|---------------|-----------------|-------------|
| Per-slot data on player tooltips or the group-finder rows | Seen as "gear check" | Needs a quiet inspect per hover (already rate-limited), more load, other addons clash | Out of scope; character sheet and Inspect window only (milestone). |
| Caching per-slot gear for others in the session cache | Faster redraws | Memory, stale data, the cache is deliberately small (`known[guid]`, `ItemLevel.lua:95-98`) | Read live from the open Inspect window. |
| Using Blizzard's `SocketDisplay` (calling `SetItem`, un-gating Timerunning) | Reuse | Writes on Blizzard frames and calls Blizzard methods from addon code | Own frames and own icons. |
| Hard-coded enchant ID to name tables | Offline names | Rot every patch, Forever adds enchants | Tooltip enchant line. |
| Gem/enchant stat totals, gear score, "BiS" advice | Appeals to min-maxers | v0.1 removed gear score on purpose (`Core.lua:39`); scope creep | None. |
| Upgrade arrows and bag overlays | Present in retail addons | Not in milestone; separate surface | Defer. |

---

### F4. Settings page sections: Group finder, Player inspection, Damage meter, Messages

#### Table Stakes

| Feature | Why Expected | Complexity | Notes |
|---------|--------------|------------|-------|
| Sections in the stated order | Milestone | LOW | Section headers come from consecutive `opt.section` values in registration order (`UI/SettingsPanel.lua:35-39`); the Damage meter's Move button is placed after the last option section and the Messages header is fixed after it (`:68, :80`). So reorder `OPTIONS` in `Settings.lua:122-185` (Group finder first, including the Elite quest button; then Player inspection; then Damage meter). Rename "Item level and talents" to "Player inspection". |
| Player inspection groups item level, talents, enchants, sockets | Milestone | LOW | Existing five keys move there; the three new gear keys follow. |
| Option labels and tooltips for the new keys | Same pattern as others | LOW | `label`, `tooltip`, optional `parent`. |
| `/tgf set` output and printed fallback list use the new section names | Consistency | LOW | `UI/SettingsPanel.lua:141` prints `section: label`. |

#### Anti-Features

| Anti-Feature | Why Requested | Why Problematic | Alternative |
|--------------|---------------|-----------------|-------------|
| Renaming keys when moving options | Tidiness | Saved variables key off them; the migration depends on them | Keep every existing key. |
| Per-slot sub-pages | Many options | The page is one vertical list | Keep one page, use `parent` for nesting. |

---

## Feature Dependencies

```
F1 opt-in defaults
    └──requires──> Migrate schema 4 (Core.lua) ──before──> every module Init
    └──touches───> Settings.lua defaults (six existing keys)

F2 elite quest button
    ├──requires──> new setting key (Group finder section)  [F4]
    ├──requires──> hook on tracker module update (hooksecurefunc only)
    ├──requires──> UI/InPlace.lua opening route (IP.OpenMessages precedent)
    ├──enhances──> UI/Table.lua search box (prefill with quest name)
    └──blocked-by (spike) secure category selection; description prefill is NOT possible

F3 per-slot gear info
    ├──requires──> new keys in Player inspection  [F4]
    ├──requires──> ItemLevel.lua per-slot read (extend ILvl.Read, no new cache)
    ├──requires──> ItemLevelUI.lua installer (UI.Install) + hooks on both slot-update functions
    ├──reuses───> Inspect hook + retry pattern (ItemLevelUI.lua:262-346)
    └──does NOT use──> the quiet inspect queue (it stays away from an open Inspect window by design)

F4 settings order
    └──requires──> F1 (default changes), F2 and F3 (new keys), reorder of OPTIONS
```

### Dependency Notes

- **F1 before everything:** new keys must be registered with their intended defaults the first time, otherwise F2's "default on" and F3's "default off" are decided by accident. Do the Settings registry change first, with F4's reordering.
- **F3 does not need the inspect queue.** The queue (`ItemLevel.lua` guard, 1.5 s gap, never while the Inspect window is shown) exists for other players' tooltips. The Inspect window brings its own inspect and its own data.
- **F2's find half and create half are independent.** The find half (open finder, prefill our search box) can ship even if the create half's secure route fails.
- **F2 vs "in place" rule:** the button lives in the tracker, outside the finder. CLAUDE.md's narrow exceptions list will need one more line: our own button on the tracker's quest blocks (own frame, hooks only).

---

## MVP Definition

### Launch With (v0.3.0)

- [ ] F1: defaults flipped for the six keys and schema-4 migration, with a test that an existing player's effective values are unchanged and a new install gets the new defaults.
- [ ] F4: sections reordered and renamed, new keys registered.
- [ ] F2 (core): eye button on elite quest blocks in the tracker, retail look and tooltip, opens the finder, Browse search box prefilled with the quest name.
- [ ] F3 (core): per-slot item level and enchant/missing-enchant on the character sheet and Inspect window, with the enchantable-slot table.

### Add After Validation (v0.3.x)

- [ ] F2 create half: category 116 preselected through a secure click, only after the spike proves the Post button still works.
- [ ] F3 sockets: only if some Forever item turns out to have sockets (verify in game).
- [ ] F3 missing-enchant policy tuning (level threshold) after player feedback.

### Future Consideration

- [ ] Eye for Dungeon / Raid tagged quests, behind a setting.
- [ ] Quest log button (backlog 999.5's original wording).
- [ ] Per-slot overlays on other surfaces (bags, tooltips).

---

## Feature Prioritization Matrix

| Feature | User Value | Implementation Cost | Priority |
|---------|------------|---------------------|----------|
| F1 defaults + schema-4 migration | HIGH (author's reason for the milestone) | LOW | P1 |
| F4 sections order | MEDIUM | LOW | P1 |
| F2 eye button with finder opening and prefilled search | HIGH | MEDIUM | P1 |
| F2 create group preselected (secure route) | HIGH | HIGH (taint spike) | P2 |
| F3 slot item level (character sheet) | MEDIUM | MEDIUM | P1 |
| F3 slot item level (Inspect) | MEDIUM | MEDIUM | P1 |
| F3 enchant text / missing mark | MEDIUM | MEDIUM | P1 |
| F3 socket gems | LOW (likely no sockets on Forever) | MEDIUM | P3 |
| F2 hint banner on Listing tab | MEDIUM | LOW | P2 |
| Smart missing-enchant policy | MEDIUM | LOW | P2 |

**Priority key:** P1 must have; P2 should have; P3 nice to have or verify first.

---

## Competitor / Reference Feature Analysis

| Feature | Retail Blizzard | Retail slot-overlay addons | Our Approach |
|---------|-----------------|----------------------------|--------------|
| Quest find-group eye | Eye in tracker, calls `LFGListUtil_FindQuestGroup`, quest-ID search, auto-fill create | n/a | Same look, own click route; text-based search through our own search box; no description write |
| Per-slot item level | Not shown in the stock UI | Number on slot, quality colour, per-surface toggles (SimpleItemLevel: character, inspect, bags) | Character sheet and Inspect only, own frames |
| Missing enchant / gem flags | Not shown | Red mark / text where a slot is empty (SimpleItemLevel flags missing enchants and gems) | Static slot table tuned to Forever; gem row only when sockets exist |
| Opt-in defaults | n/a | Most addons default everything on | Everything but the group-finder features off |

---

## Risks and open questions for the roadmap

| Item | Severity | What to do |
|------|----------|------------|
| Taint when selecting category / activities for the Listing tab | HIGH | Dedicated spike phase with a real client; measure whether `C_LFGList.CreateListing` is still allowed after our click route. Keep it separate from the find-half so the milestone can ship either way. |
| `C_LFGList.GetActivityIDForQuestID` may not exist on Forever | MEDIUM | Probe in game (extend `/tgf` with a probe in the style of `/tgf ilvl`). |
| Quests & Zones category may auto-choose activities and require a description | MEDIUM | Probe `C_LFGList.GetLfgCategoryInfo(116).autoChooseActivity`. Changes what "ready to create" means. |
| Sockets and ring enchants on Forever are unverified | MEDIUM | In-game probe for `C_Item.GetItemNumSockets` over equipped items and a list of enchant IDs seen per slot; fix the enchantable table from observed data. |
| `TOOLTIP_TRACKER_FIND_GROUP_BUTTON` exists on Forever? | LOW | `_G` lookup with fallback text. |
| Header text under the eye on long quest titles | LOW | Visual check; the retail block shrinks its header via `AdjustRightEdgeOffset` (`Blizzard_ObjectiveTrackerBlock.lua:337-341`), which we must not call. |
| Per-slot overlays vs other addons' overlays on the same slots | LOW | They are off by default (that is the point of F1). |
| CLAUDE.md and PROJECT.md updates | LOW | Settings paragraph, schema line, tracker exception, and screenshot reminder (README prints for the settings page and the character sheet). |

## Sources

Blizzard source (`C:\Users\jonat\Repositories\wow-ui-source`, branch `forever`), HIGH:
- `Interface/AddOns/Blizzard_ObjectiveTracker/Blizzard_ObjectiveTrackerShared.lua:180-210` and `.xml:65-88` (button)
- `Blizzard_ObjectiveTracker/Blizzard_QuestObjectiveTracker.lua:13-17, 291-315` and `Blizzard_BonusObjectiveTracker.lua:15-17, 343-344`
- `Blizzard_ObjectiveTracker/Blizzard_ObjectiveTrackerBlock.lua:156, 337-373`; `Blizzard_ObjectiveTrackerModule.lua:591-606`
- `Blizzard_ObjectiveTracker/Camelot/Blizzard_QuestObjectiveTrackerOverride.lua`, `Blizzard_FrameXMLUtil/Camelot/QuestUtilsOverrides.lua`, `Blizzard_FrameXMLUtil/Mainline/QuestUtils.lua:375-387`
- `Blizzard_GroupFinder/Mainline/LFGList.lua:471-536, 4556-4604`; `Blizzard_GroupFinder/Blizzard_GroupFinder.toc:10`
- `Blizzard_GroupFinder_VanillaStyle/Blizzard_LFGVanilla_Listing.lua:199, 264-328, 342-377, 884-919, 1164-1190`; `Mainline/Blizzard_LFGVanilla_Listing.xml:602-632`; `Mainline/LFGVanilla_Constants.lua:12-19`; `Blizzard_LFGVanilla_ParentFrame.lua:17-60, 152-170`; `Blizzard_LFGVanilla_Browse.lua:233-284, 331`
- `Blizzard_UIPanels_Game/Camelot/PaperDollFrame.xml:46-164, 779-870`, `PaperDollFrame.lua:2177-2230, 3568-3612`
- `Blizzard_InspectUI/Camelot/InspectPaperDollFrame.xml`, `Mainline/InspectPaperDollFrame.lua:63-69, 245-272`
- `Blizzard_APIDocumentationGenerated/LFGListInfoDocumentation.lua` (`CanCreateQuestGroup`, `SetSearchToQuestID`, `autoChooseActivity`), `QuestLogDocumentation.lua:525-540, 749-760, 1500-1512`, `QuestConstantsDocumentation.lua:149-152`, `TooltipInfoDocumentation.lua:389-405`, `TooltipInfoSharedDocumentation.lua:49`

Project files read: `CLAUDE.md`, `.planning/PROJECT.md` (Current Milestone), `Core.lua:25-47`, `Settings.lua`, `UI/SettingsPanel.lua:27-80, 141`, `ItemLevel.lua:1-504`, `ItemLevelUI.lua:56-68, 255-360, 483-560, 681-685`, `UI/Table.lua:1844-1862`.

Web (MEDIUM to LOW):
- [WoW Forever overview, warcraft.wiki.gg](https://warcraft.wiki.gg/wiki/WoW_Forever): level cap 60; nothing on sockets, enchant slots or elite quests (read first 100k chars)
- [Method.gg itemization](https://www.method.gg/wow-forever/itemization-updates-in-world-of-warcraft-forever-expertise-spell-damage-more): no mention of sockets, gems or enchants
- [Blizzard Watch, every new enchant in WoW Forever (2026-09-21)](https://blizzardwatch.com/2026/09/21/every-new-enchant-world-warcraft-forever/): new neck, chest, wrist, hands, back, weapon and off-hand enchants; no sockets
- [Warcraft Tavern, new enchanting formulas](https://www.warcrafttavern.com/forever/news/new-enchanting-formulas-for-world-of-warcraft-forever/): neck and off-hand are new enchant slots; no rings, no sockets
- [Blizzard Watch, every enchant in WoW Classic](https://blizzardwatch.com/2020/07/23/enchants-available-wow-classic/) (via search): vanilla enchantable slots; rings, necks, belts, trinkets not enchantable; shoulders ZG only
- Search snippets only (LOW): one guide on personal ring enchants in Forever; games.gg Duskwood and Wetlands guides for elite quests; the Forever beta cap of 30
- [SimpleItemLevel (kemayo)](https://github.com/kemayo/wow-simpleitemlevel): item level on character and inspect panels, missing enchant and gem flags, per-surface toggles, quality colour switch

---
*Feature research for: WoW Forever group-finder addon, milestone v0.3.0*
*Researched: 2026-11-24*
