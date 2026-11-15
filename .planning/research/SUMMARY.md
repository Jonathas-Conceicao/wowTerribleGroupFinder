# Project Research Summary

**Project:** TerribleGroupFinder, milestone v0.2 "ILvL Info and Improved Refresh"
**Domain:** WoW Forever addon (interface 16001, game type `camelot`) that improves Forever's own group finder in place
**Researched:** 2026-11-14
**Confidence:** MEDIUM-HIGH. Blizzard source was read in the `forever` branch, but runtime behaviour has not been run in game.

Detail lives in STACK.md, FEATURES.md, ARCHITECTURE.md and PITFALLS.md.

## Executive Summary

v0.2 adds no new technology. Every feature uses Blizzard frames and APIs that Forever already ships:
- the retail Settings panel (vertical layout category)
- `TooltipDataProcessor`
- the Camelot character sheet's ScrollBox stats pane
- the load-on-demand Inspect UI
- animation groups

The one structural change is subtractive. Gear score is deleted (code, column, sort, tooltip lines, inspects, saved data) and replaced by the game's own item level figures in four optional spots: friendly player tooltip, item tooltip, character sheet and Inspect window. On top of that sit:
- a native settings window
- a finished Dynamic refresh (slower swipes, rows sliding up, demoable in the preview)
- region flags with one US flag
- a tooltip on every row icon

The recommended approach has two cross-cutting pieces plus small edits:
- **Settings registry.** `ns.Settings` uses flat saved-variable keys. `Get(key)` is read when each hook fires and never cached, so every toggle is live without `/reload`.
- **Motion module.** `ns.Motion` is extracted from the 1910-line `UI/Table.lua`. It owns swipe-out, swipe-in and a slide-up. The slide-up records each row's position before the update and animates from the old offset afterwards. The live refresh and the preview's simulated refresh share this one path.
- **Item level split.** `ItemLevel.lua` keeps the data and `ItemLevelUI.lua` holds four independent, pcall-guarded installers.

The build order is:
1. gear score removal and the settings foundation
2. item level spots
3. region flags
4. Motion and Dynamic refresh with the preview
5. row icon tooltips
6. the settings window
7. Release Review

The main risks are:
- taint on the character sheet
- Inspect state shared between our quiet inspects and the player's own Inspect window
- pooled ScrollBox rows (animations and tooltip hit frames recycled mid-play)
- duplicate or misplaced item tooltip lines

Several answers cannot be settled from source and need one consolidated in-game pass. Schedule that pass early in the phases that depend on it, not at the end.

## Key Findings

### Recommended Stack

No libraries. Ace and LibStub are rejected as against the "native to Forever" rule.

**Core technologies:**
- **Item tooltip:** `TooltipDataProcessor.AddLinePostCall(ItemName, fn)` puts "Item Level N" directly under the name.
  - It covers GameTooltip, ItemRefTooltip and the compare tooltips.
  - Scan `tooltipData.lines` for the stock `ItemLevel` line (type 31) and skip if present.
  - Show it for weapons and armor only, with the level from `C_Item.GetDetailedItemLevelInfo` and the text from `ITEM_LEVEL`.
  - Guard the link with `issecretvalue`.
  - Do not use a whole-tooltip post-call (the line lands at the bottom) or `OnTooltipSetItem` (it does not exist here).
- **Character sheet:** `PAPERDOLL_STATINFO["ITEMLEVEL"]` already exists on Forever, with Blizzard's own label, value and tooltip. It is just not listed in any category. The pane is `CharacterStatsPaneScrollBox`, rebuilt from `PAPERDOLL_STATCATEGORIES` on every update. See "Reconciled Disagreements" for how to add the row.
- **Inspect window:**
  - A FontString parented to `InspectPaperDollFrame`, created inside `EventUtil.ContinueOnAddOnLoaded("Blizzard_InspectUI", ...)`. This is needed because the UI is load-on-demand and `Core.lua` unregisters `ADDON_LOADED` after our own load.
  - It is anchored `BOTTOMRIGHT` to `InspectFrame.Inset` `TOPRIGHT`.
  - It is refreshed from `hooksecurefunc` on `UpdateButtons` and `SetLevel`.
  - The data comes from `C_PaperDollInfo.GetInspectItemLevel(unit)`.
- **Settings window:**
  - Use `Settings.RegisterVerticalLayoutCategory`, `RegisterAddOnSetting` (writes our saved table directly), `CreateCheckbox`, `CreateSettingsButtonInitializer` (pass `addSearchTags` explicitly) and `RegisterAddOnCategory`.
  - Open it with `Settings.OpenToCategory(category:GetID())` for `/tgf settings`.
  - Prefix variable names with `TGF_`.
  - Swipe animations is a child of Dynamic refresh via `SetParentInitializer`.
- **Animations:** `CreateAnimationGroup` with `Translation` and `Alpha`. Offsets are render-time, so they are safe inside a ScrollBox. Use `SetToFinalAlpha(true)` on fade-outs. Never move anchors of pooled rows, and never use `UIFrameFade` or `OnUpdate` tweens.

### Expected Features

**Must have (all in the author's scope):**
- Gear score removed completely. The saved `gs` data is migrated away, and the notes stay in `research/GEARSCORE.md`.
- Item level on four spots:
  - friendly player tooltips (a prototype exists)
  - item tooltips (gold, under the name)
  - the character sheet General category, under Movement Speed
  - the Inspect window, top right
- Settings window with:
  - toggles for the four item level spots, Dynamic refresh, swipe animations and region flags
  - a button that opens the finder on the Messages tab
  - finder changes themselves not optional
- Dynamic refresh finished: slower swipes, rows slide up when one leaves, and the swipes are playable in the preview through the real code path.
- Region flags:
  - ONE US flag for US1 and US2, with no E/W letter on rows
  - East/West only in the tooltip
  - an Oceania flag
  - the flag also on your own listing, taken from the leader
  - a toggle
- A tooltip on every row icon: flag, role icons, new-player, Discord, leader, friend/BNet/recent ally marks, and the Auto-refresh icon.

**Should have (differentiators):**
- Item level on Inspect and on other players' tooltips (retail has neither).
- The sheet row's native "equipped vs average" tooltip, for free.
- The flag plus West/East in the tooltip.
- Swipes plus slide-up so the list never jumps.

**Defer or reject:**
- per-slot item levels
- colour-coded or score-like item level
- item level for enemies
- sorting or averaging the finder by item level
- persisting inspected values between sessions (session-only stays)
- a custom-skinned settings window
- looping animations
- any timer-driven `C_LFGList.Search`

### Architecture Approach

- **Saved variables.** Use flat top-level keys: `ilvlPlayerTooltip`, `ilvlItemTooltip`, `ilvlCharacterSheet`, `ilvlInspect`, `dynamicRefresh`, `swipeAnimations`, `regionFlags`. `Core.lua` fills defaults only one level deep, so nested tables would leave existing users with nil.
- **Hooks.**
  - Install them unconditionally at init, because `hooksecurefunc` cannot be undone.
  - Gate each one inside its body with `Settings.Get`.
  - Only the sheet line, the Inspect text and region flags need an `onChange` redraw.
- **Refresh toggles.** Dynamic refresh off means stock behaviour (spinner, blank list). Swipes off means the list updates and rows jump. The two are independent.

**Major components:**
1. `Settings.lua` (`ns.Settings`): registry, flat keys, `Get/Set`, `onChange`, defaults safe before `ADDON_LOADED`.
2. `UI/SettingsPanel.lua`: registers the Blizzard Settings category from the registry. The Messages button calls a new public `IP.OpenMessages()`.
3. `ItemLevel.lua` (trimmed) holds the data: read, cache, quiet inspect queue and an `OnLearned` observer. `ItemLevelUI.lua` (new) holds the four spots as independent installers.
4. `UI/Motion.lua` (`ns.Motion`): swipe out/in, slide-up, and `Motion.Show(previousKeys, selectedKey)` shared by the live path and the preview. It also holds a click guard while busy.
5. `Region.lua` and `UI/Table.lua`:
   - `Region.lua`: one US flag, a `ForListing(l)` own-listing rule and a toggle gate.
   - `UI/Table.lua`: gear score removed, row icon hit frames added, and it calls Motion.
6. `Preview.lua` and `GearScore.lua`:
   - `Preview.lua`: gear score parsing removed, plus reserve listings and `Churn()` to simulate refreshes.
   - `GearScore.lua`: deleted.

### Critical Pitfalls

1. **Sheet row taint and pooling.**
   - The pane is a pooled ScrollBox rebuilt from a global table. Hand-anchored frames vanish, and writes to Blizzard tables taint the read path.
   - Add a data entry, never a frame, and reuse Blizzard's `ITEMLEVEL` stat.
2. **Quiet inspect vs the player's Inspect window.**
   - `InspectFrame:IsShown()` is false between the click and `INSPECT_READY`, so our `Busy()` guard is one step late. Our `ClearInspectPlayer()` can then wipe their data.
   - Guard on `InspectFrame.unit ~= nil`, and add a `hooksecurefunc` on `NotifyInspect`/`InspectUnit` that treats about 2 s as busy.
   - Accept values only when the `INSPECT_READY` GUID equals the GUID we asked for and `UnitGUID(unit)` still matches at read time.
   - Never call `ClearInspectPlayer()` if another inspect started after ours.
3. **Item tooltip line misplaced, duplicated or wrong.**
   - Use only the ItemName line post-call, skip when a type-31 line exists, and show equippable gear above level 1 only.
   - Prefer `overrideItemLevel` on comparison data, and keep a single add path.
   - Do not copy the unit filter `tooltip ~= GameTooltip` to items, or compare tooltips lose the line.
4. **Gear score removal and saved data.**
   - v0.1 users have `TerribleGroupFinderDB.gs`. Bump `schema` to 2 and run `Migrate(db)` before every module `Init`. It clears `gs` and maps any tester `autoRefresh` to the new key.
   - Remove `GearScore.lua`, its TOC line and every `ns.GS`/`GEAR_SCORE` reference (Core, Widgets, Table, Preview) in one change.
   - Mutate the DB in place and never rebind `TerribleGroupFinderDB`, because the Settings API holds a reference to it. Migrate before `RegisterAddOnSetting`.
5. **Pooled rows: animations and icon hit frames.**
   - Reset (stop the group, alpha 1, offsets) in the ScrollBox element resetter as well as in `FillRow`.
   - Record `GetTop()` by listing key before the update, and slide from the old offset after it.
   - Keep total swipe delay near 0.4 s, and cancel it on a new search.
   - Icon tooltips need real child hit frames, created once per row, with `SetPropagateMouseMotion/Clicks(true)`. The tooltip-owner check must include hit-frame children.
   - Icons that need tooltips become textures instead of inline markup. The Discord icon is the existing pattern.
6. **Region table trust.**
   - `learned` shard IDs currently override `KNOWN` and persist forever. Let `learned` only fill gaps.
   - An unknown shard shows no flag, and every reader goes through the existing secret-value guard.
   - Flag textures must be git-tracked to ship.

## Reconciled Disagreements

**Character sheet row: hook vs global write**

- **Option A (STACK.md, the recommended default):**
  - Use `hooksecurefunc(CharacterStatsPaneScrollBox, "UpdateStats", ...)`, which runs after Blizzard's code.
  - Insert `{ isHeader = false, name = "ITEMLEVEL", unit = "player", statIndex = ... }` after the `MOVESPEED` element in `self.elementData`. Do this in `elementData`, not only the provider, because `HideElements()` rebuilds the provider from `elementData`.
  - Then call `SetDataProvider(CreateDataProvider(data), RetainScrollPosition)`.
  - **Taint trade-off:**
    - It writes no Blizzard-owned config table, so Blizzard's update loop and every row `Init` read clean data, and Blizzard builds the row itself.
    - The cost is that our insecure code makes the `SetDataProvider` call, so the ScrollBox's row initialisation inside that one call runs in our context.
    - It also re-sets the provider on every update.
  - Toggling off is clean: one `UpdateStats()` call rebuilds without our row, with no reload.
  - It affects the player pane only, because the pet pane has its own mixin copy.
- **Option B (PITFALLS.md and ARCHITECTURE.md):**
  - Once at load, insert `{ stat = "ITEMLEVEL", showFunc = ... }` after `MOVESPEED` in the player General category of `PAPERDOLL_STATCATEGORIES`.
  - It is one line, uses the stock pipeline, and gives a live toggle through `showFunc`.
  - **Taint trade-off:**
    - The written slots, and the slots shifted after them, are tainted for the whole session.
    - Blizzard's secure `UpdateStats` and the row `Init` then read tainted entries on every update, including in combat. On a modern client, tainted code touching secret values errors.
    - It cannot be removed without a reload. It can only be hidden through `showFunc`.
  - PITFALLS' claim that no post-hook route exists is contradicted by STACK's verified reading of `UpdateStats` and `CreateDataProvider`.
- **Recommendation:**
  - Implement Option A by default. Keep Option B as the documented fallback, used only if the in-game check shows taint errors or a misbehaving row.
  - Either way, the row stays behind its own toggle.
  - Record it in PROJECT.md as a deliberate, narrow exception to the "never write fields on Blizzard frames" rule. A writes `elementData` on the pane and calls its `SetDataProvider`. B writes a Blizzard global table.
  - Guard with `if CharacterStatsPaneScrollBox then`, which gives one code path and no flavour fork.

**Other conflicts, resolved**
- **Item tooltip hook.**
  - ARCHITECTURE suggests a pre-call that inserts a line into `tooltipData`. STACK and PITFALLS use `AddLinePostCall(ItemName)` with `tooltip:AddLine`.
  - Use the line post-call. Mutating Blizzard's tooltip data risks taint and double insertion on `TOOLTIP_DATA_UPDATE` rebuilds.
- **Settings layout.**
  - ARCHITECTURE suggests a canvas layout. STACK, FEATURES and PITFALLS agree on the vertical layout.
  - Use vertical. It gives checkboxes, a header, a button and tooltips for free, with the native look.
  - The preview needs a minimal fallback so toggles still work from the DB there. Do not build a second custom window as the main path.
- **Messages button vs the Settings panel.**
  - ARCHITECTURE says to call `HideUIPanel(SettingsPanel)` first. PITFALLS warns that closing it from our click runs the panel's commit/revert logic.
  - Default: don't close it. Open the finder beside it and call `ShowMessages()` last, because the stock tabs' `OnShow` hook would otherwise hide it.
  - Do this out of combat only, with a printed message otherwise.
  - Check overlap in game, and print a hint instead of closing if the windows clash.
- **Region.**
  - The author's decision supersedes the per-shard letter idea: one US flag, with East/West in the tooltip only.
  - The US1 = West / US2 = East label is now tooltip-only, but still confirm it in game before it ships.
  - Own listing: `Region.ForListing(l)` uses your own shard when you lead or are solo, and the leader's server when someone else leads. Set a shard on the preview's own entry.
- **Icon tooltips.**
  - ARCHITECTURE leaned toward row-level lines for markup icons. The author decided every row icon gets its own tooltip, so PITFALLS 9 applies in full: real hit frames, propagated mouse, an owner check, created once per row.
  - Reuse stock wording where it exists (`LFG_LIST_NEW_PLAYER_FRIENDLY_*`, voice mode, `TANK`/`HEALER`/`DAMAGER`).
  - Read globals at runtime with plain fallbacks, and never hard-code recalled English.
- **Swipe timing.**
  - ARCHITECTURE suggests 0.45 s out and in. PITFALLS caps total delay near 0.4 s, because the deferred read widens the window in which a second search is ignored.
  - Start at about 0.3 to 0.4 s of swipe plus about 0.3 s of slide, as named constants in `Motion`. Tune by feel, and let a new search cancel the pending swipe state.
- **Gone rows.**
  - CLAUDE.md says rows missing from a quiet refresh stay as greyed "gone" rows for up to 15 minutes. `Listings.lua` actually drops them, and the swipe-out removes them.
  - The code is what ships and it matches backlog 999.4. Fix CLAUDE.md at the Release Review, unless the author says otherwise.
- **Item tooltip scope.**
  - Item tooltips are in scope by the author's decision. They are the highest-uncertainty item level spot (data shape, type-31 duplicates), so they go last in that phase.

## Implications for Roadmap

### Phase 1: Foundation (gear score removal, schema migration, settings registry)
**Rationale:** Removal shrinks `Table.lua` and `Preview.lua` before they are touched again. The registry and flat keys are needed by every later toggle. It has no dependencies and is quick to verify in the smoke harness.
**Delivers:**
- `GearScore.lua` and `ns.GEAR_SCORE` gone, with the column, sort, tooltip lines and Preview parsing removed (`ACTIVITY_X` becomes a constant)
- the schema 2 migration (`gs` cleared, old `autoRefresh` mapped)
- `Settings.lua` with defaults for all seven keys and the new init order

**Avoids:** Pitfalls 7 and 14. A grep for `ns.GS`, `GEAR_SCORE`, `GS(`, `row.gs` and `myGS` must come back clean. The TOC is edited in the same change, and the DB is mutated in place.

### Phase 2: Item level spots
**Rationale:** This is the headline feature and depends only on the registry. It is independent of the table work, so it can run alongside Phases 3 and 4.
**Delivers:**
- `ItemLevel.lua` trimmed, with `OnLearned`
- `ItemLevelUI.lua` with, in order:
  - the player tooltip (moved, gated, no quiet inspect when off)
  - the Inspect text (with the pending-inspect guard and `ContinueOnAddOnLoaded`)
  - the character sheet row (Option A)
  - the item tooltip (ItemName line post-call, deduped against type 31)

**Avoids:** Pitfalls 1 to 6 and 13. Item tooltips go last because they may need in-game iteration. Run the sheet taint and type-31 checks before building the settings toggles for them.

### Phase 3: Region flags
**Rationale:** It is small and touches `FillRow` and `ExtrasTooltip` lightly. Landing it before icon tooltips avoids conflicts.
**Delivers:**
- one US flag with no E/W letter on rows, and East/West in the tooltip
- the `ForListing` own-row rule
- a toggle that calls `Table.RefreshAll()`
- a shard on the preview's own entry
- `learned` no longer overriding `KNOWN`

**Avoids:** Pitfall 10.

### Phase 4: Motion extraction and Dynamic refresh (with preview)
**Rationale:** This is the highest-complexity phase. It needs the final `Motion.Show` signature before the preview can use it, so the preview comes last inside the phase.
**Delivers:**
- `UI/Motion.lua`, slower swipes, and the position-recording slide-up
- resetter-based cleanup and a click guard while busy
- `OnSearch` gated by `dynamicRefresh` and `swipeAnimations` (off restores stock behaviour)
- `Preview.Churn` with reserve listings, the preview refresh, and the `IP.OnSearch` preview branch
- `/tgf reset` restoring the preview data

**Avoids:** Pitfalls 8 and 12. There is no timer-driven `C_LFGList.Search`, a new search cancels swipe state, and the scrolled-list and collapsed-section cases are handled.

### Phase 5: Row icon tooltips
**Rationale:** It is table-only and depends on the flag icon from Phase 3 and the author's decision that every icon gets its own tooltip.
**Delivers:**
- per-row hit frames, created once, with mouse propagation
- tooltips for the flag, role icons, new-player, Discord, leader, friend/BNet/recent ally marks and the Auto-refresh icon (renamed Dynamic refresh)
- owner-aware recycle cleanup

**Avoids:** Pitfall 9.

### Phase 6: Settings window and Messages button
**Rationale:** Build it after the features exist so every toggle and the button can be exercised end to end. The Phase 1 registry makes the order flexible.
**Delivers:**
- the Blizzard Settings category with:
  - four item level checkboxes
  - Dynamic refresh with Swipe animations as its child
  - Region flags
  - the "Open Messages" button
- `/tgf settings` and a public `IP.OpenMessages()`
- the preview fallback

**Avoids:** Pitfall 11. That means unique `TGF_` names, reading the DB live, a combat guard on open, and not closing the Settings panel.

### Phase 7: Release Review
This phase is mandatory per PROJECT.md. It covers:
- code cleanup
- the CLAUDE.md rewrite: gear score gone, Settings, Motion and ItemLevelUI documented, the sheet exception noted, and the gone-row wording and Region header comment fixed
- README screenshots
- the TOC load list: add `Settings.lua`, `ItemLevelUI.lua`, `UI/Motion.lua` and `UI/SettingsPanel.lua`, and remove `GearScore.lua`
- version, changelog draft and author review

No in-milestone bug mentions go outside `.planning/`.

### Phase Ordering Rationale
- Subtraction before addition keeps later diffs small. The registry comes before the features, so each feature lands with its toggle.
- Item level spots and the table work are independent. Only Phases 3 and 5 share `FillRow`, which is why they are ordered that way.
- Motion comes before the settings window, so the "swipe animations" and "Dynamic refresh" toggles control real behaviour.
- Taint-sensitive and data-shape-sensitive work (sheet row, item tooltip, Inspect guard) is front-loaded within Phase 2 and paired with early in-game checks.

### Research Flags
Phases likely needing deeper research or an in-game pass during planning:
- **Phase 2:**
  - sheet row taint
  - type-31 duplicates
  - the Inspect anchor
  - `InspectFrame.unit` timing
  - Run one live check batch before finalising.
- **Phase 4:**
  - whether `SetDataProvider` acquires frames synchronously
  - slide correctness when the list is scrolled or sections are collapsed
  - tuning by feel
- **Phase 6:**
  - `Settings.OpenToCategory` restrictions (`HasRestrictions = true`)
  - two-window overlap

Phases with standard patterns (skip research-phase):
- **Phase 1:** the removal list is enumerated in ARCHITECTURE.md, and the migration is straightforward.
- **Phase 3:** it is a small change in our own code. Only the own-listing shard needs a live check.
- **Phase 5:** the pattern is documented in PITFALLS 9 and in the existing Discord icon.

## Confidence Assessment

| Area | Confidence | Notes |
|------|------------|-------|
| Stack | HIGH | Calls, signatures and load order were read in the `forever` branch with line references. The Camelot vs Mainline file choice for the Inspect Lua is inferred (MEDIUM). Item tooltip data field names rest on Blizzard Lua usage, not the generated docs. |
| Features | MEDIUM-HIGH | Behaviour comes from source. English global string values are recollection (LOW), so read the globals at runtime. Whether Forever's data already carries an item level line cannot be known from source. |
| Architecture | HIGH for own code, MEDIUM for Blizzard hook points | Integration points were read directly from the repo. The Blizzard paths have not been run in game. |
| Pitfalls | MEDIUM-HIGH | Structure is source-backed. Taint spread through `securecallfunction` initializers and `HasRestrictions` semantics are reasoning only (LOW-MEDIUM). |

**Overall confidence:** MEDIUM-HIGH. The design is well supported. The remaining risk sits in the runtime behaviours listed below.

### Gaps to Address

**In-game checks (one consolidated list, to run early in Phases 2, 3, 4 and 6):**
1. **Sheet row taint.**
   - With Option A: open the sheet, equip gear, scroll, switch Stats / Equipment / Titles / Pet, and test in and out of combat.
   - Watch for `ADDON_ACTION_BLOCKED`/`FORBIDDEN` and secret-value errors (`/console taintLog 2`).
   - If A misbehaves, try Option B and repeat.
   - Confirm the row shows for the player only, not the pet pane, and survives `/reload` with the sheet open.
2. **Label text.** `STAT_AVERAGE_ITEM_LEVEL` and `ITEM_LEVEL` read "Item Level" on Forever's locale.
3. **Item tooltip data.**
   - Does Forever's data already carry an `ItemLevel` (type 31) line for any gear? Check with `/dump C_TooltipInfo.GetInventoryItem("player", 16).lines` types.
   - Does `ItemName` precede the other lines for all item data types?
   - Test inventory, bags, merchant, chat link and compare tooltips.
   - Confirm there is no duplicate after a 3 s hover (data-update rebuild) and that not-yet-loaded item data is handled.
   - Confirm heirlooms and non-gear show nothing wrong.
4. **Inspect.**
   - Real window size, and the best anchor for the top-right text (collision with `InspectLevelText` on long class strings).
   - The first inspect after login shows the text.
   - `InspectFrame.unit` is set before `INSPECT_READY`.
   - Hover-inspect then clicking Inspect does not blank the window.
   - Closing during a quiet inspect is safe.
   - The value never belongs to another player.
5. **Settings.**
   - Our category appears under AddOns, and `OpenToCategory` lands on it from a click (finder closed, and after `/reload`). `HasRestrictions` must not block it.
   - Check the Messages button with the Settings panel open for window overlap.
   - Every toggle works without `/reload` and survives `/reload`.
   - Defaults are correct on a fresh DB and on a v0.1 DB that has `gs`.
6. **ScrollBox updates.**
   - `SetDataProvider`/`SetItems` acquires frames synchronously (`GetTop()` after the update is the new position).
   - The slide delta is right when the list is scrolled or sections are collapsed.
   - No stuck invisible rows after scrolling or a second refresh mid-swipe.
   - No wrong-row animation after pooled reuse.
7. **Region.**
   - Own shard from `UnitGUID("player")` (`Player-<shard>-...`), and the leader's server when you are a member.
   - Whether `partyGUID` is present for solo listings.
   - Confirm US1 = West / US2 = East with an independent signal before the tooltip wording ships.
   - An unknown shard shows nothing.
   - Flag textures are present in the packaged zip (`git ls-files Media/Textures`).
8. **Icon tooltips.**
   - Test each icon, greyed rows, and recycled rows (the tooltip hides when the row is released).
   - Right-click menu and click-select still work over icons.
   - The row tooltip re-show on result updates does not override an icon tooltip.
9. **Reduced motion (optional).** Does Forever expose an accessibility cvar worth honouring? (MEDIUM-LOW).

**Other gaps:**
- The preview stand-in needs a minimal toggle path, since there is no Blizzard Settings panel there. Keep it small, not a second window.
- Decide at planning whether Auto-send and Auto-invite also appear in the settings window. Recommendation: leave them on the Messages tab, since the new button links there.
- ARCHITECTURE's smoke-harness list should become the test plan for Phases 1 and 4. It covers settings defaults, `Churn` uniqueness, the click guard, and stubs for `GetTop` and animation recorders.

## Sources

### Primary (HIGH confidence)
- Blizzard UI source, branch `forever` (`wow-ui-source`):
  - `Blizzard_UIPanels_Game/Camelot/{PaperDollFrame,PaperDollFrameConstants,CharacterFrame}.lua/.xml`
  - `Blizzard_InspectUI/` (Camelot and Mainline)
  - `Blizzard_SharedXMLGame/Tooltip/{TooltipDataHandler,TooltipDataRules,TooltipUtil}.lua`
  - `Blizzard_Settings_Shared/*`, including `Blizzard_ImplementationReadme.lua`
  - `Blizzard_SharedXML/Shared/Scroll/{ScrollBox,ScrollBoxListView}.lua`
  - `Blizzard_GroupFinder_VanillaStyle/*`
  - `Blizzard_APIDocumentationGenerated/{PaperDollInfo,Item,TooltipInfoShared,SettingsUtil,SimpleAnim*,SimpleScriptRegionAPI,Unit}Documentation.lua`
- Own code: `Core.lua`, `ItemLevel.lua`, `Region.lua`, `Listings.lua`, `Preview.lua`, `UI/Table.lua`, `UI/InPlace.lua`, `UI/MainFrame.lua`, `UI/Widgets.lua`, `scripts/*.ps1`, `.pkgmeta`

### Secondary (MEDIUM confidence)
- warcraft.wiki.gg `API_GetAverageItemLevel` and the Item level page (player-only, equipped-average formula, lists Forever as supported)
- ROADMAP.md backlog 999.2 to 999.4 (author notes)

### Tertiary (LOW confidence, needs validation)
- Exact English values of Blizzard global strings (recalled, read at runtime)
- Taint spread through `securecallfunction` initializers
- `C_SettingsUtil.OpenSettingsPanel` `HasRestrictions` semantics
- Retail's exact tooltip look

---
*Research completed: 2026-11-14*
*Ready for roadmap: yes*
