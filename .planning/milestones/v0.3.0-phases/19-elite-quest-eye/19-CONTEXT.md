# Phase 19: Elite Quest Eye - Context

**Gathered:** 2026-11-24
**Status:** Ready for planning
**Mode:** Autonomous smart discuss: the recommended answers were taken, building on the author's
kickoff answers in `.planning/research/v0.3.0/KICKOFF-DECISIONS.md` (locked)

<domain>
## Phase Boundary

An eye button of our own beside tracked elite quests in the objective tracker. A click (out of
combat) opens Forever's group finder on its Listing tab and shows a hint box of our own with what
the player needs to list a group for the quest. Nothing of Blizzard's finder is selected, filled or
written; the player picks the category / activity, types the description and posts. Gated by
`eliteQuestButton` (Phase 18, default on). Requirements: QST-01..04.

</domain>

<decisions>
## Implementation Decisions

### The eye (QST-01)
- New file `QuestButton.lua` (`ns.QuestButton`), in the TOC after `ItemLevelUI.lua` / before the UI
  files as fits the load order; an independent pcall-guarded installer
- Hook: `hooksecurefunc(<module instance>, "EndLayout", pass)` on `QuestObjectiveTracker` and
  `CampaignQuestObjectiveTracker` (elite campaign quests included; a list of module globals, each
  hooked if present; never the mixin tables). If the tracker isn't loaded at our load, install
  through `EventUtil.ContinueOnAddOnLoaded("Blizzard_ObjectiveTracker", ...)`
- The pass walks the module's `usedBlocks` (read only); for each block with a numeric `block.id`
  (not secret): eligible = setting on AND `C_QuestLog.IsEliteQuest(id) == true` (pcall; fallback
  `C_QuestLog.GetQuestTagInfo(id).tagID == 1`, `Enum.QuestTag.Group` / `QUEST_INFO_ELITE_ID`
  where defined) AND `C_LFGInfo.CanPlayerUsePremadeGroup` true where it exists; never the
  localized "(Elite)" title text, never `suggestedGroup`
- Eligibility cached per questID, cleared on `QUEST_LOG_UPDATE`
- Our button per block in a weak-keyed table `eyes[block]` (never a field on the block); a plain
  `Button` of ours parented to the block with retail's art: 30x30 (or the template's size),
  `UI-SquareButton-Up/Down/Disabled` textures, `socialqueuing-icon-eye` 13x13 icon, the mouse
  highlight and the icon's press nudge; atlas checked with `C_Texture.GetAtlasInfo`, a plain
  texture / text fallback where missing (no generated art)
- Tooltip in the addon's tooltip style (`W.ShowTip`): title "Find a group for this quest"
  (`TOOLTIP_TRACKER_FIND_GROUP_BUTTON` is not used as the title: the action differs), a note line
  "Opens the group finder's Listing tab with this quest's details."
- Position: at the block's `TOPRIGHT` with retail's offset (5, 2) when `block.rightEdgeFrame` is nil
  (read only); otherwise `RIGHT` to that frame's `LEFT` with 2 px spacing (the quest item button is
  secure: anchor ours to it, never the other way)
- Header room: re-anchor `block.HeaderText`'s right edge only when the narrower width does not
  change its line count (`GetNumLines` / string height before vs after); otherwise leave it and let
  the eye sit over the end of the title (accepted by the author). Anchors only; the block's
  `Reset` restores them each layout
- Duplicate guard: a block whose `rightEdgeFrame` is Blizzard's find-group button (has `Icon` and
  the template's mixin or `questID`) gets no eye of ours (read only); no shim for
  `LFGListUtil_FindQuestGroup`
- `ns.Settings.OnChange("eliteQuestButton", ...)` re-runs the pass over every hooked module's
  `usedBlocks` (no call into Blizzard code); hidden when off

### The click (QST-02)
- The handler reads the quest at click time from `self:GetParent().id` (blocks are recycled)
- In combat: `ns.Print("can't open the group finder in combat.")` and nothing else
- New `IP.ShowFinder(tab)` in `UI/InPlace.lua`, extracted from `IP.OpenMessages`'s middle block:
  out of combat, "isn't ready" when the finder isn't loaded, then `LFGVanilla_ShowFrame(tab)`
  (`LFGVanilla_ToggleFrame` fallback only when not shown); `IP.OpenMessages` keeps its Settings
  wait and final `ShowMessages()` and calls `IP.ShowFinder(BROWSE_TAB)` in between (no behaviour
  change); the eye calls `IP.ShowFinder(LISTING_TAB)` (tab 1)
- No `C_LFGList.SetSearchToQuestID` / `SetSearchToActivity` call this milestone (route A is a
  future requirement); no dropdown, category, activity or Listing call of Blizzard's

### The hint box (QST-03)
- A small frame of ours in the game's dialog style (a Blizzard dialog / inset template, with a
  `UIPanelCloseButton`), parented to `LFGListingFrame` (or the finder's Listing frame) and placed
  at the top of the Listing tab without covering the category buttons' clicks (above them, or
  the finder widened like Browse if no room; the planner checks Forever's Listing geometry)
- Lines: the quest name in gold as the title with an "Elite" tag; "Category: Quests & Zones";
  "Zone: <the quest's zone>" (from the quest's map: `C_TaskQuest.GetQuestZoneID` /
  `GetQuestUiMapID` / the quest log header the quest sits under, whichever Forever gives; omit the
  line when unknown); "Description: type \"<quest name>\""
- Clears (hides) when: the finder hides, another tab is selected, a listing is made
  (`LFG_LIST_ACTIVE_ENTRY_UPDATE` with an active entry), the close button, combat start
- Our own outline frame over the Listing tab's category button whose `categoryID == 116` (read
  only; found by walking the Listing frame's category buttons; skipped quietly if not found),
  shown with the hint, hidden with it
- Quest name from `C_QuestLog.GetTitleForQuestID` (secret / nil guarded); nothing shown when the
  name can't be read

### Safety and preview (QST-04)
- Nothing written on Blizzard's tracker, blocks (beyond the anchors-only header move), finder or
  Listing frame; the restricted calls stay the player's
- `/tgf quest`: a debug command listing tracked quests with `IsEliteQuest`, tag info,
  `CanCreateQuestGroup`, whether an eye is shown, and the category-116 activities
  (`C_LFGList.GetAvailableActivities(116)` names) — a tool shipped alongside, not a gate
- In the preview / stand-in (no tracker or no finder API) nothing errors; the hint can show on the
  stand-in Listing tab if cheap, else the click prints the hint as a chat line

### Claude's Discretion
- Exact hint frame template and size, fonts (GameFontNormal / Highlight), the outline art (an atlas
  of Blizzard's glow / `UI-Achievement` style frame or a plain border)
- Whether to also print the hint as one chat line (default: no, the box is the hint)

</decisions>

<code_context>
## Existing Code Insights

### Reusable Assets
- `IP.OpenMessages` (UI/InPlace.lua:434-457): the finder-opening pattern to extract into `IP.ShowFinder`
- `W.ShowTip`, `W.IconButton`, `W.AtlasMarkup` (UI/Widgets.lua): tooltip style and atlas fallbacks
- `ns.ILvlUI` installers (ItemLevelUI.lua): independent pcall-guarded installers, `ContinueOnAddOnLoaded`
  for load-on-demand addons (ItemLevelUI.lua:352)
- `ns.Settings.Get` / `OnChange`

### Established Patterns
- hooksecurefunc + own frames in weak tables; settings read where acting
- No art generated; Blizzard atlases with plain fallbacks

### Integration Points
- Blizzard_ObjectiveTracker (forever branch): `QuestObjectiveTracker` / `CampaignQuestObjectiveTracker`
  instances, `EndLayout` (Blizzard_ObjectiveTrackerModule.lua:201-217), `usedBlocks`,
  `block.rightEdgeFrame`, `block.HeaderText`; retail button spec Blizzard_ObjectiveTrackerShared.xml:65-88
- Blizzard_GroupFinder_VanillaStyle (Mainline): `LFGVanilla_ShowFrame(tab)`, Listing frame's category
  buttons (`categoryID`), `LFG_LIST_ACTIVE_ENTRY_UPDATE`
- Research: `.planning/research/v0.3.0/ARCHITECTURE.md` Feature 2, `PITFALLS.md` 1-6, `STACK.md`

</code_context>

<specifics>
## Specific Ideas

- The author's chosen hint mock-up:

```
+------------------ Listing ------------------+
| [Elite] The Stockade Riot      (x)          |
|  Category: Quests & Zones                   |
|  Zone: Stormwind City                       |
|  Description: type "The Stockade Riot"      |
|---------------------------------------------|
|  [Dungeons] [Raids] [*Quests & Zones*] ...  |
```

- Look like retail's tracker find-group eye (checked against the reference UI source)

</specifics>

<deferred>
## Deferred Ideas

- Route A: let the game pre-select the quest's search via `SetSearchToQuestID` (future requirement)
- A quest log eye (backlog 999.5)

</deferred>
