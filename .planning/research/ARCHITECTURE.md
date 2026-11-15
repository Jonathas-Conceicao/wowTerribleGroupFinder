# Architecture Patterns

**Domain:** WoW Forever addon, in-place group finder table; milestone v0.2 integration (item level spots, settings, Dynamic refresh, region flags, GS removal)
**Researched:** 2026-11-14
**Scope:** only what v0.2 adds or changes. Existing architecture is in CLAUDE.md.
**Confidence:** HIGH for integration points in our own code (read directly); MEDIUM for Blizzard hook points (read in wow-ui-source `forever`, not run in game); LOW where flagged.

## Recommended Architecture

Two new cross-cutting pieces carry the milestone; everything else is a small edit to an existing file.

1. **`ns.Settings`** (new `Settings.lua`): one registry of options (key, default, label, tooltip, optional `onChange`) plus `Get(key)` / `Set(key, v)`. Every feature reads `ns.Settings.Get(key)` at the moment it fires. That is the whole "live, no /reload" mechanism: no feature caches its toggle, and the few that own persistent frames (sheet line, Inspect text) register an `onChange` that shows/hides them. The registry also drives the settings window, so adding an option is one table entry.
2. **`ns.Motion`** (new `UI/Motion.lua`): the swipe-out / swipe-in / slide-up animations, moved out of `UI/Table.lua` (already 1910 lines), plus the refresh sequencing (`ShowRefresh` today in `UI/InPlace.lua`). Both the live path (InPlace) and the preview path (MainFrame / simulated refresh) call the same entry point, so the demo exercises the real code.

```
Core.lua  (DEFAULTS, ADDON_LOADED init order, /tgf)
  |-- Settings.lua  (registry, Get/Set, onChange)  <-- all features read it
  |-- ItemLevel.lua (data: ILvl.Read/Of/Remember/Probe + inspect queue)   [trimmed]
  |-- ItemLevelUI.lua (new: the four spots; each = one small installer)
  |       |-- player tooltip   (moved from ItemLevel.lua OnTooltipUnit)
  |       |-- item tooltip     (TooltipDataProcessor pre-call, Item)
  |       |-- character sheet  (PAPERDOLL_STATCATEGORIES entry ITEMLEVEL)
  |       |-- Inspect window   (FontString on InspectFrame)
  |-- Region.lua    (flags: Of/Markup + own-listing rule)
  |-- Listings.lua  (Read/Snapshot/Key; unchanged API)
  |-- UI/Motion.lua (new: Out/In/Slide + Refresh sequence)
  |-- UI/Table.lua  (rows, tooltips; GS removed; calls Motion)
  |-- UI/InPlace.lua (OnSearch hook; Read -> Motion.Show)
  |-- UI/MainFrame.lua + Preview.lua (preview refresh = simulated churn -> same Motion.Show)
  `-- UI/SettingsPanel.lua (new: window built from the registry)
```

### Component Boundaries

| Component | Status | Responsibility | Communicates With |
|-----------|--------|---------------|-------------------|
| `Settings.lua` (`ns.Settings`) | NEW | Option registry, saved values, `Get/Set`, `onChange` callbacks | Core (DB), every feature, SettingsPanel |
| `UI/SettingsPanel.lua` | NEW | Builds the options UI from the registry; "Edit whisper messages" button | Settings, InPlace (open Messages), Widgets |
| `ItemLevel.lua` | MODIFIED (trim) | Data only: `ILvl.Read/Of/Average/Hostile/Probe`, inspect queue, `known` cache, INSPECT_READY learning | ItemLevelUI (notifies on learn), Settings (gate quiet inspects) |
| `ItemLevelUI.lua` | NEW | The four display spots, each an `Install()`/`Update()` pair | ILvl, Settings, Blizzard tooltips/PaperDoll/Inspect |
| `UI/Motion.lua` (`ns.Motion`) | NEW | Swipe out/in, slide-up, `Motion.Show(previous, selected)` sequencing, `Motion.SIMULATE` helpers | Table (frames), Listings (Key), Settings |
| `UI/Table.lua` | MODIFIED | GS removal; row icon tooltips; region flag per row; `T.FramePositions()` helper; swipe code moved out | Motion, Region, W |
| `UI/InPlace.lua` | MODIFIED | `OnSearch` gated by setting; `Read` hands to Motion; `IP.OpenMessages()` public; preview-refresh hook | Motion, Settings, Listings |
| `UI/MainFrame.lua`, `Preview.lua` | MODIFIED | Refresh button calls `ns.Preview.Churn()` then `Motion.Show`; reserve listings; GS parsing removed; settings tab/button | Motion, Core state |
| `Region.lua` | MODIFIED | One US flag; `Of(shard)` plus `ForListing(l)` (own-listing rule); setting gate | Table, Listings |
| `GearScore.lua` | DELETED | n/a | n/a |

### Data Flow

Quiet refresh (live):
`Forever refresh button -> LFGBrowse_DoSearch -> (post-hook) IP.OnSearch` [if `Settings.Get("dynamicRefresh")` and same filter: snapshot, `refresh.pending`] `-> LFG_LIST_SEARCH_RESULTS_RECEIVED -> ReadSoon (0.2 s) -> Read -> Listings.Read(snapshot) -> Motion.Show(previous, selected)`. Motion: swipe-out removed rows (wait `Motion.Duration()`), record frame positions, `Table.SelectKey`/`RefreshAll` (SetItems), slide surviving rows from old to new position, swipe-in new rows.

Quiet refresh (preview): `refresh button -> ns.Preview.Churn() (mutates ns.state.listings) -> Motion.Show(previous, selected)` with `previous = Listings.Snapshot`-shaped table built from the preview items. Same code downstream.

Setting changes: `SettingsPanel checkbox -> Settings.Set(key, v) -> onChange(v)` (show/hide sheet line, Inspect text; `Table.RefreshAll()` for region flags). Read-at-fire features (tooltips, swipes, refresh gating) need no callback.

## Integration Points (file:function)

### Settings storage and live read

- `Core.lua` `DEFAULTS` (line 29) is only filled one level deep by `ADDON_LOADED` (`for key, value in pairs(DEFAULTS)`). A nested `settings = { ... }` table would not get new keys added later for existing users. **Use flat top-level keys** in `TerribleGroupFinderDB`, or deep-fill. Recommended flat keys (booleans, default `true`):
  - `ilvlPlayerTooltip`, `ilvlItemTooltip`, `ilvlCharacterSheet`, `ilvlInspect`, `dynamicRefresh`, `swipeAnimations`, `regionFlags`
  - Existing keys stay where they are (Messages' Auto-send/Auto-invite, presets in `ns.db` via `ns.Messages.Init(ns.db)`; `shards` from `Region.Init`). Decision to settle: show Auto-send/Auto-invite in the settings window too (read/write the same keys through the Messages API, never a second copy) or leave them in the Messages tab. Recommend leave them (the settings window only links to the Messages tab).
  - Add `DEFAULTS` entries in `Core.lua` for all seven keys. `Settings.lua` loads before features and exposes `ns.Settings.Get(key)` that falls back to the registry default when `ns.db` is not ready yet (hooks installed before `ADDON_LOADED` finishes must not error).
- Load order in the TOC: `Core.lua`, `Settings.lua` (right after Core, before `Preview.lua` is fine), then features. In `ns:ADDON_LOADED` (Core.lua:262) remove `ns.GS.Init(ns.db)`, add `ns.Settings.Init(ns.db)` first, then `ns.ILvl.Init()`, `ns.ILvlUI.Init()`, `ns.Region.Init(ns.db)`, `ns.Messages.Init`, `ns.InPlace.Init`.
- Live-read rules (one rule per feature, no cached copies):

| Feature | Where the toggle is read | onChange needed |
|---------|-------------------------|-----------------|
| Player tooltip item level | top of the Unit post-call (`OnTooltipUnit`): return early if off; also skip `RequestInspect` (no quiet inspects when off) | no |
| Item tooltip item level | inside the Item pre-call: return if off | no |
| Character sheet line | the stat entry's `showFunc` returns `Settings.Get(...)` | yes: call `PaperDollFrame_UpdateStats()` (out of combat) to redraw |
| Inspect text | `Update()` does `fs:SetShown(on and known)` | yes: re-run `Update()` |
| Dynamic refresh | `IP.OnSearch`: `same = same and Settings.Get("dynamicRefresh")`. Off = stock behaviour (spinner, blank list, clear selection) | no |
| Swipe animations | `Motion`: `if not Settings.Get("swipeAnimations") then return false` (list still updates in place, rows just jump) | no |
| Region flags | `Region.Markup(shard)` returns `""` when off; tooltip line too | yes: `ns.Table.RefreshAll()` |

  Dynamic refresh off versus swipes off are independent: Dynamic refresh governs "keep list, no spinner, merge"; swipes govern animation only.
- Settings window: opinionated choice is the game's own Settings panel via `Settings.RegisterCanvasLayoutCategory(frame, "TerribleGroupFinder")` + `Settings.RegisterAddOnCategory` (API present in `Blizzard_Settings_Shared/Blizzard_Settings.lua`, README at `Blizzard_ImplementationReadme.lua`), with `/tgf config` calling `Settings.OpenToCategory(id)`. Guard everything with `if Settings and Settings.RegisterCanvasLayoutCategory` and fall back to a standalone frame (`PortraitFrameTemplate`/`BasicFrameTemplate` via `W.Create`) so the preview and the smoke harness (where `Settings` is stubbed or absent) still build the same checkboxes. One builder (`BuildOptions(parent)`) serves both, like `ns.Messages.BuildPanel`. LOW confidence: whether Forever's `SettingsPanel` can be opened to a canvas category from `/tgf` without taint; verify in game, fallback is the standalone frame.
- "Open the finder on Messages" button needs a public `IP.OpenMessages()`: `LFGVanilla_ToggleFrame(BROWSE_TAB)` / show `LFGParentFrame` if hidden, then the existing local `ShowMessages()` (InPlace.lua:218). Refuse in combat (as `IP.Open` does) and close/hide the Settings panel first (`HideUIPanel(SettingsPanel)`; if that is protected, leave it open). In the preview: `ns.UI.Show("messages")`.

### Gear score removal surface (complete grep)

Delete / edit:

| File | What |
|------|------|
| `GearScore.lua` | delete the file |
| `TerribleGroupFinder.toc` | remove the `GearScore.lua` line (install/package scripts derive the file list from the TOC, so no script edit) |
| `Core.lua` | lines 13-15 (`ns.GEAR_SCORE` and comment); `ns.Me()` lines 122-128 (`me.gs` block); line 275 `ns.GS.Init(ns.db)`; add `ns.db.gs = nil` once in `ADDON_LOADED` (saved-data cleanup; leave in for this release, drop after) |
| `UI/Widgets.lua` | `W.GS_OUTDATED` (line 74), `W.GS` (line 75-~85), GS colour helpers |
| `UI/Table.lua` | header comment lines 7-8, 16; `LEFT[#LEFT+1] = {key="gs"}` (64-66), `ACTIVITY_X` ternary (67), `FIRST_DESC.gs` (71); `ListingGS` (148-160); `VALUES.gs` (244-247); `GSLine` (300-310); `RightText(m, gs)` (481, simplify to zone-only); tooltip `leaderGS`/`memberGS` (526-535); `BuildRow` `cells.gs`/`row.gs` (957-959, 983); `FillRow` (1203-1206); text list (1248) and `row.gs or row.count` (983, 1260); `Refresh` `myGS` (1474-1477); `Attach` `myGS` + `gsHover` (1670-1680), header `gs` tooltip (1745-1753), `myGS` anchoring (1770-1776) leaving only `status` anchored to `fits.Label` |
| `Preview.lua` | `GS()` helper (72-76), member spec parse `:gs` + `gs/gsStale` fields (81-90), solo parse (139-147), header comment (5, 71, 77, 136); sample strings carrying `:22.4` / `:~21.0` style GS tokens become plain `Name:CLASS:level:ROLE` |
| `CLAUDE.md` | `GearScore.lua` bullet, GS mentions in `UI/Widgets.lua` / `UI/Table.lua` bullets, `ItemLevel.lua` (stays) — Release Review rewrite; keep `.planning/research/GEARSCORE.md` |
| `.planning/ROADMAP.md` | close backlog 999.1 |

Messages has no `{gs}` key (removed in v0.1), nothing to do there. A `FitColumns`/`COLUMNS`/`CELL_KEYS` loop derives from `LEFT`, so removing the entry removes the header and cell automatically; check `ACTIVITY_X` becomes the constant 292. The smoke harness "gear score" mode (RETROSPECTIVE.md) disappears.

### Item level module split

Today `ItemLevel.lua` (580 lines) mixes data (read slots, game figure, Remember, inspect queue) and one display spot (`OnTooltipUnit`, `AddLine`, `RefreshTooltip`). Split along that seam:

- **`ItemLevel.lua` (keep, trim)**: `ILvl.Read/Of/Average/Hostile/Probe`, `Remember`, queue/`Inspect`/`Next`/`RequestInspect`, `OnInspectReady`, the `known` table. Add a tiny observer: `ILvl.OnLearned(fn)` called from `Remember` with the guid, so display spots refresh when a value arrives (replaces the hard-wired `RefreshTooltip(c.guid)` in `ReadCurrent`). Expose `ILvl.OfGUID(guid)` / `ILvl.Of(unit)`; `Format(ilvl)` returns the displayed whole number (`math.floor`, already used).
- **`ItemLevelUI.lua` (new, `ns.ILvlUI`)**: four installers, each independent and safe to fail (`pcall`/guards, one missing API disables only that spot):
  1. **Player tooltip**: move `AddLine`, `RefreshTooltip`, `OnTooltipUnit` here; same `TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Unit, fn)`; add the setting gate.
  2. **Item tooltip** (backlog 999.2): `TooltipDataProcessor.AddTooltipPreCall(Enum.TooltipDataType.Item, fn)` per the backlog note (`Blizzard_SharedXMLGame/Tooltip/TooltipDataHandler.lua`). Pre-call receives `tooltipData`; insert a line table at index 2 (`{ type = Enum.TooltipDataLineType.None, leftText = "Item Level N", leftColor = NORMAL_FONT_COLOR }`) only if the item has a level and no existing "Item Level" line (guard against Forever already printing one and against double insertion on `TOOLTIP_DATA_UPDATE` rebuilds: scan `lines` for our text). Level from `C_Item.GetDetailedItemLevelInfo(tooltipData.hyperlink or tooltipData.id)`; skip when nil/0 or when the item is not gear (`C_Item.GetItemInfoInstant` class weapon/armor only; retail shows it for gear). LOW confidence on the exact line field names and on taint in combat / action-button tooltips: needs an in-game check; read `Blizzard_SharedXMLGame/Tooltip` in wow-ui-source first. Keep this spot behind `pcall` so a bad shape cannot break all tooltips.
  3. **Character sheet**: Forever's Camelot `PaperDollFrameConstants.lua` has `PAPERDOLL_STATCATEGORIES[1]` (General: HEALTH, POWER, MOVESPEED, unit "player") and `PAPERDOLL_STATINFO["ITEMLEVEL"]` already exists (`PaperDollFrame_SetItemLevel`, which gives the game's own label and tooltip) but is not listed in Camelot. Recommended: once at init, insert `{ stat = "ITEMLEVEL", showFunc = function() return ns.Settings.Get("ilvlCharacterSheet") end }` right after the MOVESPEED entry of the first category with `unit == "player"`; `showFunc` is the game's own conditional, so the toggle is live (redraw with `PaperDollFrame_UpdateStats()` out of combat; it already runs on `PLAYER_EQUIPMENT_CHANGED` etc.). Risk: writes into a Blizzard global config table (our taint rule is about the finder, but this is the same family): the stats pane has no protected actions, widely done by addons, but verify no `ADDON_ACTION_FORBIDDEN` when opening the sheet in combat. Fallback if rejected: `hooksecurefunc("PaperDollFrame_UpdateStats", ...)` and anchor our own FontString line under the MOVESPEED stat frame (found via the pool's frames whose `Label:GetText()` is `STAT_MOVEMENT_SPEED`), more fragile. MEDIUM confidence (source read; not run).
  4. **Inspect window**: `InspectFrame` (Blizzard_InspectUI Camelot, `ButtonFrameTemplate`) is load-on-demand. Install on `ADDON_LOADED == "Blizzard_InspectUI"` (or immediately if loaded): create one FontString on `InspectFrame` anchored `TOPRIGHT` (raw text, e.g. `Item Level 48`), `InspectFrame:HookScript("OnShow", Update)`, `hooksecurefunc("InspectFrame_Show", Update)`, plus `ILvl.OnLearned` and a register on `INSPECT_READY` (our own listener already exists in `ILvl.Init`). Unit is `InspectFrame.unit`; ask `ILvl.Of(unit)`; when unknown hide the text (the game's Inspect already triggered `NotifyInspect`, so `OnInspectReady` learns it, then `OnLearned` updates). Never create a second `NotifyInspect` while the window is open (`Busy()` already enforces this).
- Shared decisions: format helper (`"Item Level " .. floor`) and gold colour in one place (`ILvlUI.Line(ilvl)`); use `STAT_AVERAGE_ITEM_LEVEL` / `ITEM_LEVEL` globals with plain-text fallbacks (preview/harness has no globals).

### Region flags

- `Region.lua`: one US flag. `PLACES.US1`/`US2` already share `flag = "us"`; remove the `short` E/W letters from `Markup` (the grey letter) and keep `label` ("US West"/"US East") and `group` for the tooltip. `R.Of` stays. Remove assumed/confirmed wording: PROJECT.md says mapping confirmed (US1 West, US2 East); update the header comment in the Release Review.
- Own listing: Listings read `l.shard` from `info.partyGUID` (Listings.lua:207). Your own row (`l.mine`) in the live search may carry your party's GUID but the leader of your party can be someone else. Rule: "flag on own listing based on the leader": `Region.ForListing(l)` returns `Of(l.shard)`; when `l.mine` and you are not the leader, use the leader's server from `UnitGUID(leaderUnit)` (`R.Server(UnitGUID("party"..i))`); when you lead or are solo, use `GetRealmID()` (already used by `LearnAround`). `Preview.lua` `MyEntry()` (Core.lua:179) has no `shard`: set `shard = 6934` (US East) so the preview shows it. `UI/Table.lua` `FillRow` line ~1183 (`ns.Region.Markup(l.shard)`) changes to `ns.Region.MarkupFor(l)`; tooltip line ~611 (`ExtrasTooltip`) to `ns.Region.Of`-for-listing as well, still gated by `Settings.Get("regionFlags")`.
- The tooltip also needs the region for own listing; keep one function so row and tooltip never disagree.

### Dynamic refresh: preview simulation

Current preview refresh (`UI/MainFrame.lua:315`): `RelistOneHidden` + `ClearSelection` + `RefreshBrowse`, no snapshot, no motion. In game with `/tgf preview`, the real Forever refresh button still runs `LFGBrowse_DoSearch` but `OnSearch` sees `UsingPreview()` and does nothing special.

Plan:
- `Preview.lua`: add `P.reserve` (extra sample listings, same constructors `Group`/`Solo`, not placed in `P.listings`; `Add` assigns ids). Add `ns.Preview.Churn(state, category)`: pick 1 to 3 non-mine listings of the shown category (including one mid-list so rows below must slide up, and optionally one in each section) and remove them from `ns.state.listings`; pull 0 to 2 from the reserve (deep-copied via the same `ResetState` copy logic: leaders re-linked) and append them with `listedAt = time()`; keep one case where a hidden player relists (existing `T.RelistOneHidden`). Reserve cycles so repeated clicks keep producing changes (departed listings go back to the reserve). `ns.state` reset (`/tgf reset`) restores both.
- `Listings.Key` works on preview listings (solo/leader name), so `Motion.Show` needs a `previous` set: build it from `ns.PreviewListings(...)` before `Churn` (`previous[key] = l`, not mine), and `now` after. Move `ShowRefresh` into `Motion.Show(previousKeySet, selectedKey)`, taking sets so it does not care where they came from; `InPlace.Read` computes the sets from `Listings.items`, `MainFrame` from `ns.PreviewListings`. (`ShowRefresh` already works with key sets; only its `ns.Listings.items` source is live-specific, parameterise it as `currentKeys()`.)
- `MainFrame` refresh: `local before = KeysOf(source.listings()); local sel = Table.SelectedKey(); Preview.Churn(...); Motion.Show(before, sel)`. In game with `/tgf preview`: add a branch in `IP.OnSearch` (`if ns.UsingPreview() then <same Churn + Motion.Show>`, still after the real search call, which is harmless); `Read` already skips live merges in preview. Gate by `Settings.Get("dynamicRefresh")`: off in preview shows the stock-like blank-then-fill (set `searching` for 0.4 s) so the toggle is demonstrable too.
- Also simulate a failed refresh occasionally? Not needed; list as optional.

### Dynamic refresh: rows sliding up with pooled ScrollBox frames

Facts from code: `host:SetItems` (Table.lua:1566) builds a new `DataProvider` and calls `box:SetDataProvider(dp, RetainScrollPosition)`; in Blizzard's `ScrollBox.lua` that goes to `view:SetDataProvider` which triggers `OnViewDataProviderReassigned`/`FullUpdate(UpdateImmediately)` (verified in `Blizzard_SharedXML/Shared/Scroll/ScrollBox.lua`), so frames are re-anchored synchronously and `ForEachFrame` immediately reflects the new layout (verify in game: if `GetTop()` still returns old values, wait one frame with `C_Timer.After(0, ...)`). Frames are pooled and re-`Init`ed, so a frame is identified by what it shows now (`item`), not by identity. `FillRow` already calls `row.tgfSwipe:Stop()` on reuse (Table.lua:1144), which is the right cleanup for any extra animation group.

FLIP approach (First, Last, Invert, Play), implemented in `Motion`:
1. **First**: before `SetItems`, `list:ForEachFrame(function(frame, item) tops[keyOf(item)] = frame:GetTop() end)`; `keyOf` = `ns.Listings.Key(item)` for rows, `"h:"..item.key` for section headers (so headers slide too when a section above shrinks). Skip rows swiped out (they have no key in the new list).
2. Swipe out removed rows (alpha 0 at final), wait `Motion.Duration()`.
3. **Last**: `Table.RefreshAll()` (SetItems); frames now sit at final positions. Do not wait a frame unless the verify above fails.
4. **Invert + Play**: `ForEachFrame` again; for every frame whose key had an old top and `delta = oldTop - newTop ~= 0` (non-zero beyond 1 px), play a per-frame animation group: order 1 `Translation` offset `(0, delta)` duration 0 (start visually at the old spot; `delta` is negative when the row moves up, since screen Y grows upward) and order 2 `Translation` offset `(0, -delta)`, smoothing `OUT`, duration `Motion.Duration()`. This is the existing shift+move pattern of `Swipe()` (Table.lua:1841), net zero, so the frame ends exactly on its anchor with no state to restore. Reuse one animation group per frame stored in a new field (`row.tgfSlide`) separate from `tgfSwipe` so slide and swipe-in can play together on a new row without clobbering (new rows only swipe in; they have no old top).
5. **Selection / hover**: `T.SelectKey` already re-selects by key; after the slide a hovered row's tooltip refreshes via `Instance:RefreshTooltip` (re-shown for the row under the mouse after updates), unchanged.
6. **Edge cases**: rows entering from below the viewport (no old top) do not slide; rows leaving the viewport are just recycled; scroll position retained by `RetainScrollPosition`. A new row inserted above others pushes rows down: the same FLIP slides them down, which is correct and nice. Cap total frames animated (e.g. only frames returned by `ForEachFrame`, always <= ~15). The `W.List` fallback has `list:ForEachFrame` (Widgets.lua:704) and its own pooled frames, so the same code works; positions come from the same `GetTop()` calls. When `swipeAnimations` is off return before steps 1/4 (the list updates and rows jump).
7. **Click guard** (backlog): while `Motion.busy` (swipe-out running) set a flag the contact buttons and row click handlers check (`T.Instance:Message/Invite/Select` early return), because during swipe-out the list still holds old results.
8. **Timing**: `T.SWIPE` (0.25 s, Table.lua:1838) moves to `Motion.DURATION` (suggest 0.45 s out/in, 0.30 s slide, tune in game; keep them as named constants in one place, not settings, per "slower swipes" being a tuning change). `InPlace.ShowRefresh` currently waits `ns.Table.SWIPE` with `C_Timer.After`; the animation `OnFinished` is the better trigger but the timer is fine and already works with `swiping`/`readAfterSwipe`. Keep that state machine, just move it into Motion.

### Tooltips for every row icon

Row icons today: class icon / leader icon (`row.icon`), Discord icon (`row.discord`), micro/large role icons (`cells.role` slots), new-player marker, friend/BNet/recent-ally marks, region flag, hide button (`W.Tooltip` already?), delist button, whisper button. Pattern: `W.Tooltip(frame, title, note)` exists in Widgets; icons inside text (`W.Icon`/`W.AtlasMarkup` inline markup in the name string) can't take mouse events, so give them real child frames or put their explanation into the row tooltip (`ExtrasTooltip`, Table.lua:598). Recommendation: pure markup icons (new player, friend marks, region flag, Discord) get no hover target of their own; instead the row tooltip (already the single tooltip) states each one with the stock wording (Discord and new-player lines are already stock; add "US East" via the region line, friend marks via `FriendsLine`). Only real frames (role slots, hide, delist, whisper buttons) get `W.Tooltip`. Confirm with the author which meaning of "tooltips for every row icon" applies (row-level tooltip lines vs hover on the icon itself); it changes the row build (child hover frames per icon, pooled with the row).

## Patterns to Follow

### Pattern 1: Read the toggle where the work happens
**What:** `if not ns.Settings.Get("key") then return end` as the first line of each hook body; install hooks unconditionally at init.
**When:** Anything that hooks Blizzard functions or tooltips. Unhooking is impossible (`hooksecurefunc`), so gating inside the hook is the only live method.
```lua
local function OnTooltipUnit(tooltip)
	if not ns.Settings.Get("ilvlPlayerTooltip") then return end
	...
end
```

### Pattern 2: Registry-driven options
**What:** `ns.Settings.Register{ key=, default=, label=, tooltip=, onChange= }`; the panel iterates `Settings.List()`.
**When:** Every option now and later (backlog says options "now and later").

### Pattern 3: One sequence for live and preview
**What:** `Motion.Show(previousKeys, selectedKey)` takes key sets and a `currentKeys()`; callers differ only in how they got the sets.
**When:** Anything the preview must demonstrate; avoids a second, untested animation path.

### Pattern 4: Independent installers, pcall-guarded
**What:** Each item level spot has `Install()` returning false when its Blizzard hook point is missing; one failure never takes down the others or the table.

## Anti-Patterns to Avoid

### Anti-Pattern 1: Caching a setting in a local at file load
**Why bad:** needs /reload, which this milestone explicitly rules out. **Instead:** `Settings.Get` at fire time.

### Anti-Pattern 2: Nested defaults table with the one-level default fill
**Why bad:** `Core.lua` ADDON_LOADED only fills missing top-level keys; a later release adding `settings.newKey` leaves existing users with nil (falsey, flips defaults to off). **Instead:** flat keys, or deep-fill in `Settings.Init`.

### Anti-Pattern 3: Animating frame identity across a data refresh
**Why bad:** the ScrollBox pool re-inits frames for different items; keyed state on a frame leaks to the next listing. **Instead:** record by listing key before, play after, stop on reuse (`FillRow`).

### Anti-Pattern 4: Calling `C_LFGList.Search` to make the preview or Dynamic refresh "work"
**Why bad:** blocked from a timer (`ADDON_ACTION_BLOCKED`); the preview must never touch it. **Instead:** the preview mutates `ns.state.listings`; live only reacts to Forever's own searches.

### Anti-Pattern 5: Adding a GS-style per-row inspect for item level
**Why bad:** rows (listings) are not units; the finder lists players you cannot inspect. Item level here is for units you can see (tooltips, group, Inspect window), never for table rows. Keep it out of `Listings.lua`/`Table.lua`.

## Smoke-Test Harness Implications (tests live outside the repo; new behaviour to cover)

- GS removal: harness mode "gear score" is obsolete; default / fallback / attach modes must still build the table with 6 fixed columns (`ACTIVITY_X = 292`), no `row.gs`, no `myGS`, `ns.GS` nil, `ns.db.gs` cleared.
- Settings: defaults filled for all seven flat keys on first load and for an old DB lacking them; `Get` before `ADDON_LOADED` returns defaults; `Set` fires `onChange`; panel builds with and without the `Settings` API (stub absent); the Messages button calls `IP.OpenMessages` (stubbed finder, preview branch).
- Item level: Unit post-call adds the line only when the toggle is on and known; off also skips `RequestInspect` (`NotifyInspect` stub never called); Item pre-call inserts at index 2 exactly once across repeated calls on the same data and skips items without level; sheet entry inserted once (idempotent on re-init) with `showFunc` honouring the toggle; Inspect FontString shows/hides with toggle and on `OnLearned`; missing `InspectFrame` / `PAPERDOLL_STATCATEGORIES` stubs do not error.
- Dynamic refresh: `OnSearch` with toggle off behaves as a new list (clears selection, spinner); on with same filter snapshots; `Motion.Show` with swipes off updates without animation calls; with swipes on records positions and plays one slide per moved frame, none for unmoved, none for new rows; preview `Churn` changes the list on every call (removed + reserve added), keys stay unique, `/tgf reset` restores; preview refresh with the toggle off shows the blank-then-fill path. Stubs need `GetTop()` on fake frames and `CreateAnimationGroup`/`CreateAnimation("Translation")` recorders (existing swipe tests already stub these).
- Region: one flag for US1/US2, label in tooltip, hidden when toggle off, own listing uses leader's server (preview sets a shard), unknown shard shows nothing.
- Click guard: contact buttons ignore clicks while `Motion.busy`.

## Suggested Build Order (phases and dependencies)

1. **Foundation: Settings registry + gear score removal.** (`Settings.lua`, Core DEFAULTS/init order, delete `GearScore.lua`, strip Table/Preview/Widgets/Core). Removal first because it shrinks `Table.lua` and `Preview.lua` before they are edited again, and Settings first because every later feature reads it. No dependency on the rest. Verifies in the harness quickly.
2. **Item level spots.** Split `ItemLevel.lua`/`ItemLevelUI.lua`; player tooltip (move, gate) -> Inspect window (reuses `OnLearned`) -> character sheet -> item tooltips (highest uncertainty, last; may need in-game iteration). Depends on 1 (toggles). Independent of the table work, so it can run parallel to phases 3-4 if desired.
3. **Region flags finish.** Small: one flag, own-listing rule, tooltip, toggle, preview shard on own entry. Depends on 1 (toggle) and touches `Table.lua` FillRow/ExtrasTooltip lightly, so land before the tooltip-icons work to avoid conflicts.
4. **Motion extraction + Dynamic refresh.** Create `UI/Motion.lua`, move swipe code and `ShowRefresh`, slower timings, slide-up FLIP, click guard, `OnSearch` gating by `dynamicRefresh`/`swipeAnimations`. Then the preview: `P.reserve`, `Churn`, MainFrame refresh and the preview branch in `IP.OnSearch`. Depends on 1. Preview comes last in the phase because it needs the final `Motion.Show` signature.
5. **Row icon tooltips.** Table-only; depends on 3 (region icon) and the decision on row-level vs icon-level hover.
6. **Settings window UI.** Built last in feature work so it lists every option that exists, but the registry (phase 1) lets the panel be built any time; keep it after 2 to 4 so the "open Messages" button and all toggles can be exercised end to end. Depends on `IP.OpenMessages`.
7. **Release Review.** CLAUDE.md rewrite (remove GS, document Settings/Motion/ItemLevelUI), remove wording about assumed region mapping, close backlog 999.1/999.2/999.3/999.4, TOC load list check (`Settings.lua`, `ItemLevelUI.lua`, `UI/Motion.lua`, `UI/SettingsPanel.lua` added; `GearScore.lua` removed), README screenshots (settings window, region flag).

Install/package scripts derive from the TOC, so new files only need TOC entries. TOC order: `Core.lua`, `Settings.lua`, `Preview.lua`, `ItemLevel.lua`, `ItemLevelUI.lua`, `Region.lua`, `Messages.lua`, `Listings.lua`, `UI\Widgets.lua`, `UI\Templates.xml`, `UI\Motion.lua`, `UI\Table.lua`, `UI\MainFrame.lua`, `UI\InPlace.lua`, `UI\Listing.lua`, `UI\SettingsPanel.lua`.

## Discrepancies Found (fix at Release Review)

- CLAUDE.md says the quiet refresh keeps listings the answer lacks as delisted "gone" rows for up to 15 minutes; `Listings.lua` `L.Read(previous)` instead drops them and `ShowRefresh` swipes them out. The code is what ships; CLAUDE.md should follow it (or the backlog/requirements must say which is wanted: roadmap 999.4 describes rows swiping out and leaving, matching the code).
- `Region.lua` header still says "Assumed, not confirmed: US1 is NA-West, US2 is NA-East"; PROJECT.md says confirmed.

## Scalability Considerations

| Concern | Typical (20-60 rows) | Large (MAX_RESULTS) | Notes |
|---------|----------------------|---------------------|-------|
| Slide animation | <= 15 shown frames animated | same (only shown frames exist in the pool) | pooled ScrollBox bounds cost by viewport, not list size |
| Item tooltip pre-call | one scan of `lines` per tooltip | same | exit early when toggle off or no level |
| Quiet inspects | one every 1.5 s, out of combat | same | unchanged from prototype; gated by toggle |

## Sources

- Our code: `Core.lua`, `ItemLevel.lua`, `Region.lua`, `Listings.lua`, `UI/Table.lua` (Attach, BuildList, Swipe, Refresh), `UI/InPlace.lua`, `UI/MainFrame.lua` (HIGH)
- `wow-ui-source` branch `forever`: `Blizzard_SharedXML/Shared/Scroll/ScrollBox.lua` (`SetDataProvider`, `OnViewDataChanged`, `ForEachFrame`) (HIGH); `Blizzard_UIPanels_Game/Camelot/PaperDollFrame.lua` and `PaperDollFrameConstants.lua` (`PAPERDOLL_STATCATEGORIES`, `PaperDollFrame_SetItemLevel`, `PaperDollFrame_UpdateStatsInternal`) (HIGH for structure, MEDIUM that Forever uses the Camelot variant); `Blizzard_InspectUI/Camelot/Blizzard_InspectUI.lua` / `.xml` (`InspectFrame`, `InspectFrame_Show`) (MEDIUM); `Blizzard_Settings_Shared/Blizzard_Settings.lua` and `Blizzard_ImplementationReadme.lua` (`RegisterCanvasLayoutCategory`) (MEDIUM, not run on Forever)
- ROADMAP.md backlog 999.2 to 999.4 (author notes, including the tooltip pre-call placement idea)
