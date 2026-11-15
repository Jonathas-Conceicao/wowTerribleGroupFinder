# Feature Landscape: v0.2 (item level spots, settings window, Dynamic refresh, region flags, icon tooltips)

**Domain:** WoW Forever addon improving the stock Vanilla-style group finder in place
**Researched:** 2026-11-14
**Overall confidence:** MEDIUM-HIGH. Code behaviour is read from Blizzard's `forever` branch (HIGH). Exact English wording of the global strings is NOT in the UI source (GlobalStrings is not shipped in wow-ui-source), so quoted wording is from memory (LOW) and must be read at runtime from the globals, never hard-coded.

Reference tree: `C:\Users\jonat\Repositories\wow-ui-source`, branch `forever` (abbreviated `UI/` below = `Interface/AddOns/`).

---

## Key discoveries that change the plan

1. **Forever's character sheet already knows item level.** `UI/Blizzard_UIPanels_Game/Camelot/PaperDollFrame.lua:123` defines `PAPERDOLL_STATINFO["ITEMLEVEL"]` (updateFunc -> `PaperDollFrame_SetItemLevel`, lines 1378-1404). It is NOT listed in `PAPERDOLL_STATCATEGORIES` (`Camelot/PaperDollFrameConstants.lua:35-45`: General = `HEALTH`, `POWER`, `MOVESPEED`). Forever's stats pane is a ScrollBox (`CharacterStatsPaneScrollBoxMixin:UpdateStats`, `Camelot/CharacterFrame.lua:1109-1170`) built from that table. Adding `{ stat = "ITEMLEVEL" }` after `MOVESPEED` in the first (player, General) category yields a native, correctly formatted row with Forever's own label, value and tooltip, for free. A retail-style big "Item Level" banner (`CharacterStatsPane.ItemLevelFrame`, `CharacterFrame.xml:492-520`, driven by `PaperDollFrame_UpdateStatsInternal`, `PaperDollFrame.lua:2416`) also exists but only runs on the legacy non-ScrollBox path. Verify in game which path is live; the author's "line under Movement Speed" matches the ScrollBox path.
2. **Retail Blizzard Inspect has no item level.** `grep -i itemlevel|ilvl` over `UI/Blizzard_InspectUI` (Camelot and Mainline) returns nothing. Retail shows ilvl on inspect only through addons. So "raw text top-right of Inspect" has no Blizzard precedent to copy: a pure differentiator, free layout choice. Inspect has `InspectLevelText` (top centre, `GameFontNormalMed2Outline`) under `InspectPaperDollFrame.LevelTextWrapper` (`Camelot/InspectPaperDollFrame.xml:57-70`).
3. **Retail unit tooltips have no item level either.** The player-tooltip line is already a differentiator (prototyped in `ItemLevel.lua`).
4. **Stock finder row icons have NO tooltips of their own.** Row hover only shows the row tooltip (`LFGBrowseSearchEntryTooltip`, `Blizzard_LFGVanilla_Browse.lua:534-545, 578+`). The icon tooltip feature is therefore new behaviour, not parity. Blizzard does have reusable strings (below).
5. **Settings API is the retail Settings panel** (`UI/Blizzard_Settings_Shared/Blizzard_ImplementationReadme.lua`; `Settings.RegisterAddOnCategory`, `Settings.CategorySet.AddOns`; Forever ships it, `Blizzard_Settings_Shared/Camelot/`). Vertical-layout category + checkboxes + a button initializer is the native look.

---

## Table Stakes

Missing = the feature feels broken or off-brand.

| Feature | Why Expected | Complexity | Notes / Dependencies |
|---------|--------------|------------|----------------------|
| Item tooltip line "Item Level N" directly under the item name | Retail players read ilvl there; this is the "retail look" the author asked for | Med | Use `TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Item, ...)` (`UI/Blizzard_SharedXMLGame/Tooltip/TooltipDataHandler.lua`); `Enum.TooltipDataLineType.ItemLevel = 31` exists in `Blizzard_APIDocumentationGenerated/TooltipInfoSharedDocumentation.lua:65`. Retail: line 2 (after name, before "Binds when..."), gold (`NORMAL_FONT_COLOR`) text from `ITEM_LEVEL` ("Item Level %d"). **Must check whether Forever's tooltip already has an ItemLevel line (type 31) and skip if so** to avoid a duplicate. Only gear (weapon/armor, and bag-less items with a real ilvl); skip items with `GetDetailedItemLevelInfo` = nil/0 or non-equippable. Applies to GameTooltip, ItemRefTooltip, comparison tooltips (post-call on `TooltipDataType.Item` covers all tooltips). |
| Player-tooltip ilvl line (friendly players) | Prototyped, in milestone scope | Low (exists) | `ItemLevel.lua` (quiet inspect, 1.5 s apart, session-only). Needs a toggle and removal of GS code. Keep numbers uncoloured or plain white/gold (see anti-features) |
| Character sheet line "Item Level" in General, under Movement Speed | Retail's character sheet leads with item level; author wants it in General | Low (if the stat-category insert works) | Insert `{ stat = "ITEMLEVEL" }` into `PAPERDOLL_STATCATEGORIES[1].stats` after `MOVESPEED`. Value = `floor(max(C_PaperDollInfo.GetMinItemLevel() or 0, avgItemLevelEquipped))` (`PaperDollFrame.lua:1384-1392`); label `STAT_AVERAGE_ITEM_LEVEL` via `STAT_FORMAT`; tooltip title "Item Level <avg>  (<equipped> equipped)" via `PAPERDOLLFRAME_TOOLTIP_FORMAT`, `STAT_AVERAGE_ITEM_LEVEL_EQUIPPED`, body `STAT_AVERAGE_ITEM_LEVEL_TOOLTIP`; a PvP line (`STAT_AVERAGE_PVP_ITEM_LEVEL`) is appended only when different. Refresh event: `PLAYER_AVG_ITEM_LEVEL_UPDATE` is already handled by PaperDollFrame (`PaperDollFrame.lua:338, 476`). Risk: writing a Blizzard global table (taint). It is not the finder, but note the toggle must take effect on next `UpdateStats` (re-run `PaperDollFrame_UpdateStats()` after changing; removal must splice our entry out). Fallback if taint/ScrollBox bites: hook `CharacterStatsPaneScrollBoxMixin.UpdateStats` post and add data. Pet unit must not show it (`PaperDollFrame_SetItemLevel` hides for non-player) |
| Inspect window item level text, top right | Author request; players inspect to judge gear | Low-Med | Parent a FontString/frame to `InspectFrame` (or `InspectPaperDollFrame`); data from `C_PaperDollInfo.GetInspectItemLevel(unit)` after `INSPECT_READY` (secret-arg rule: `AllowedWhenUntainted`, `PaperDollInfoDocumentation.lua:122`; guard with `issecretvalue`). Reuse the existing `ItemLevel.lua` cache so Inspect and tooltip agree. Hide when value unknown/zero rather than "0". Plain text "Item Level: N" with `ITEM_LEVEL`-style wording. Must refresh on `UnitChanged` / each inspect (`InspectFrameMixin:UnitChanged`, `Blizzard_InspectUI.lua:124`) |
| Settings window with per-spot toggles | Author request; standard for any addon with extras | Med | Native Blizzard Settings: `Settings.RegisterVerticalLayoutCategory("TerribleGroupFinder")`, `Settings.RegisterAddOnSetting(category, var, key, DB, Settings.VarType.Boolean, label, default)`, `Settings.CreateCheckbox(category, setting, tooltip)`, `Settings.RegisterAddOnCategory`, `Settings.OpenToCategory(category:GetID())`. Registered in `EventUtil.ContinueOnAddOnLoaded`. Rows: Item level on player tooltips / item tooltips / character sheet / Inspect; Dynamic refresh; Swipe animations; Region flags. Group with section headers (`CreateSettingsListSectionHeaderInitializer`, `SettingControls.lua:133`): "Item level", "Group finder". Defaults all ON. Each toggle must apply live (or on next show) without /reload. Depends on a `DB` shape (see Dependencies) |
| Settings: button that opens the finder on the Messages tab | Author request | Low | `Settings` button initializer (`SettingControls.lua:1042` `SettingButtonControlTemplate`; helper `CreateSettingsButtonInitializer`). Handler: close Settings, show `LFGParentFrame` and select the Messages tab (existing code in `UI/InPlace.lua`). Taint: `ShowUIPanel` while Settings open is fine; do not call from a secure path |
| Region flag on rows: ONE US flag for both US shards, plus flag on your own listing | Author request; stop users thinking W/E is two countries | Low-Med | `Region.lua` FLAGS table: set both `US1`/`US2` to flag "us"; keep West/East only in the tooltip text (`US West`/`US East`). Own listing: the stock own row has no shard; derive from your own `partyGUID`/player GUID shard (`Region.lua` already parses `Party-<shard>-...`; for self use `UnitGUID("player")` "Player-<shard>-..."; confirm in game). Toggle via setting |
| Icon tooltips in finder rows | Author request; icons are cryptic (murloc, Discord, flags, role icons) | Med | Add a mouse-enabled hit frame per icon (or reuse the cell with `OnEnter` on a child) in `UI/Table.lua` (icons at `Table.lua:936-1185`; role slots `951`; Discord `1176`; new player `1172`). Tooltips must set `GameTooltip` owner `ANCHOR_RIGHT`, and must suppress/replace the row tooltip while over an icon (the row tooltip is re-shown for the row under the mouse on result updates, per CLAUDE.md: guard that path) |
| Dynamic refresh finished: slower swipes, rows slide up when one leaves | Author request | Med-High | `T.SwipeOut` / `T.SwipeIn` in `UI/InPlace.lua` exist. Slide-up = animate row y-offsets of following rows (`C_Timer`/`AnimationGroup` on pooled ScrollBox frames; ScrollBox re-layouts on data change, so animate a per-row visual offset, not the ScrollBox frames). Needs reduced-motion respect (see anti-features) |
| Swipes demoable in preview | Author request, testing | Low-Med | Preview stand-in (`UI/MainFrame.lua`, `Preview.lua`) needs a fake "refresh" that drops/adds sample listings through the same `T.SwipeOut/In` path as the live merge. Keep one code path |

---

## Blizzard strings and atlases to reuse (with file evidence)

Source files in wow-ui-source do not define these globals (GlobalStrings is client data); the *use* is shown. Always call `_G.NAME` at runtime and fall back to a literal only if nil. English values are LOW confidence recollections.

| Need | Global | Where used (proof it exists on Forever) | Recalled English (LOW) |
|------|--------|----------------------------------------|------------------------|
| Item tooltip ilvl line | `ITEM_LEVEL` | `UI/Blizzard_FrameXML/EventToastManager.lua:646` (`ITEM_LEVEL:format(ilvl)`), `Blizzard_LootJournalItems.lua:279` | "Item Level %d" |
| Character sheet label | `STAT_AVERAGE_ITEM_LEVEL` | `Camelot/PaperDollFrame.lua:1392`, `Camelot/CharacterFrame.xml:494` | "Item Level" |
| Sheet tooltip | `PAPERDOLLFRAME_TOOLTIP_FORMAT`, `STAT_AVERAGE_ITEM_LEVEL_EQUIPPED`, `STAT_AVERAGE_ITEM_LEVEL_TOOLTIP`, `STAT_AVERAGE_PVP_ITEM_LEVEL` | `Camelot/PaperDollFrame.lua:1393-1401` | title "Item Level 123 (118 equipped)" style |
| Category name | `STAT_CATEGORY_GENERAL` | `Camelot/PaperDollFrameConstants.lua:37` | "General" |
| New player friendly icon tooltip | `LFG_LIST_NEW_PLAYER_FRIENDLY_TOOLTIP` | `Blizzard_GroupFinder_VanillaStyle/Classic/Blizzard_LFGVanilla_Listing.xml:474`, `Mainline/...Listing.xml:493` | explains the listing welcomes new players |
| New player friendly short label | `LFG_LIST_NEW_PLAYER_FRIENDLY_HEADER` | `Mainline/Blizzard_LFGVanilla_Browse.xml:379` (green `GameFontGreen` text beside the icon in the tooltip) | "New Player Friendly" |
| Voice | `VOICE_CHAT_MODE_FORMAT`, `LFGVoiceChat.VoiceModeLabels[voiceMode]` | `Blizzard_LFGVanilla_Browse.lua:703-706` | "Voice Chat: <mode>" |
| Leader, members, friends | `LFG_LIST_TOOLTIP_LEADER` etc. | row tooltip code, `Blizzard_LFGVanilla_Browse.lua:578-840` | check the file when building |
| Role names | `TANK`, `HEALER`, `DAMAGER` (and `LFG_LIST_TOOLTIP_MEMBERS`) | `Browse.lua:696-698` | |
| Icons | `newplayerchat-chaticon-newcomer`, `UI-ChatIcon-Discord`, `groupfinder-icon-leader`, `Interface\GroupFrame\UI-Group-LeaderIcon` | `Mainline/Blizzard_LFGVanilla_Browse.xml:150, 162, 180, 374, 384` | |

For icons with no Blizzard string (flags, friend/BNet/recent-ally marks, the TGF Auto-refresh icon), write short plain labels in our style (gold title + note line, per CLAUDE.md tooltip convention). Prefer existing globals where they exist (`FRIEND`, `BATTLENET_FRIEND`... verify names against the files before use) so wording matches the game's language.

---

## Differentiators

Valued, not expected.

| Feature | Value Proposition | Complexity | Notes |
|---------|-------------------|------------|-------|
| Item level on friendly player tooltips (quiet inspect) | Judge a stranger's gear at a glance; no retail equivalent | Low (prototype) | Throttled inspects already designed; keep "enemies never looked up" rule |
| Item level on Inspect window | Retail has none | Low-Med | Free layout; keep unobtrusive |
| Own "equipped vs average" tooltip on the sheet row | Both numbers like retail's tooltip | Free | Comes with `PaperDollFrame_SetItemLevel` |
| Region flag + West/East in tooltip | Cross-region/shard awareness; unique to Forever's mega-realm setup | Low-Med | Two shards, one flag; US East/West only in the tooltip |
| Seamless Dynamic refresh (swipes, slide-up) | The list never "jumps" | High | Core value of milestone; tune by feel in game |
| Settings toggles per extra | Players keep only what they want | Med | Required by author |

---

## Anti-Features

| Anti-Feature | Why Avoid | What to Do Instead |
|--------------|-----------|-------------------|
| Per-slot item levels drawn on character slots / inspect slots | Not requested; adds many frames on secure-adjacent item buttons, taint and perf risk, and invites a settings explosion | Defer; mention in backlog only |
| Colour-coded item level (rarity colours, red/green vs you, gear-score-like tiers) | Brings back a "score" feel the author just dropped; thresholds are arbitrary on Forever's gear curve; the stock sheet already colours its own value via `GetItemLevelColor()` | Plain text; item tooltip in standard gold like retail; inspect/player tooltip in stock white/gold. Leave the sheet's own colouring to Blizzard |
| Showing ilvl for enemies / anyone attackable | Already excluded; wasteful inspects, privacy-ish | Keep friendly-only rule |
| Item level on every tooltip type (bags, vendor, quest rewards separately) | Post-call on Item data type already covers them; custom hooks per frame double-add | One `TooltipDataProcessor` post-call, dedupe on existing type-31 line |
| Disabling the finder changes in settings | Decided: "disable the addon instead" | Settings only toggles extras |
| Our own gear score / score-based sort | Dropped in v0.2 | Item level only; GS code removed |
| Averaging "ilvl of the group" or sorting the finder by ilvl | Out of the author's list; the finder gives no ilvl for others without inspecting each | Not in v0.2 |
| Persisting inspected ilvl between sessions | Stale data misleading; previous design chose session-only | Keep session-only (no saved data) |
| Custom-skinned settings window | Violates "native to Forever" | Blizzard Settings vertical layout category |
| Looping/constant animations; animations that cannot be turned off | Motion sensitivity; also author wants a switch | Swipe toggle; also honour the game's reduced-motion setting if Forever exposes one (check `Settings` accessibility CVar; MEDIUM-LOW) |
| Calling `C_LFGList.Search` from a timer for refresh | Restricted; hardware event only (CLAUDE.md) | Keep the existing click/key-press origin |
| Tooltips on every cell | Noise | Tooltip only on icons that are not self-explanatory (list in Icon tooltip scope) |

---

## Icon tooltip scope (what each says)

| Icon | Source of wording | Tooltip |
|------|-------------------|---------|
| New player friendly (murloc) | `LFG_LIST_NEW_PLAYER_FRIENDLY_HEADER` as title, `LFG_LIST_NEW_PLAYER_FRIENDLY_TOOLTIP` as body | Same as stock Listing checkbox, so no new text |
| Discord | `VOICE_CHAT_MODE_FORMAT` + `LFGVoiceChat.VoiceModeLabels[Discord]` | "Voice chat: Discord" |
| Leader (group icon) | existing tooltip leader wording (`Blizzard_LFGVanilla_Browse.lua` row tooltip code) | Group leader |
| Role icons (solo player micro icons / group slot icons) | `TANK`/`HEALER`/`DAMAGER` globals | Role names, one per icon; for groups, Open/filled state |
| Friend / BNet friend / recent ally | existing marks wording in `UI/Widgets.lua` (`W.Icon` set, lines 112-139) | One-line meaning |
| Region flag | `Region.lua` labels | "US East", "US West", "Oceania" |
| TGF Auto-refresh icon (already has "TGF Auto-refresh is ON") | existing | Keep, rename to Dynamic refresh |

---

## Feature Dependencies

```
DB defaults + migration (remove DB.gs, GS flags)  ->  Settings window (needs stable DB keys)
Gear-score removal (GearScore.lua, GS column/sort) ->  clean ItemLevel.lua cache is the only inspect user
ItemLevel.lua (cache, inspect queue) -> player tooltip ilvl, Inspect text (share data; Inspect should read the cache first)
Settings toggles -> each spot's hook must read DB at call time (or install/uninstall hooks live)
Region.lua flag map (US1+US2 -> "us") -> row flag, own-row flag, tooltip text
Own-row flag -> own GUID shard parse (Player-<shard>-) verified in game
T.SwipeOut/T.SwipeIn (InPlace.lua) -> slide-up animation -> preview swipe demo (shared code path)
Icon tooltips (Table.lua) -> row tooltip re-show guard (results update path)
Messages tab opener (InPlace.lua) -> Settings button
Item tooltip post-call -> "no existing ItemLevel line" check (game verification)
Character sheet: PAPERDOLL_STATCATEGORIES insert -> PaperDollFrame_UpdateStats() refresh on toggle
```

---

## MVP Recommendation (v0.2 ordering)

1. Gear score removal + DB shape for settings (unblocks everything, shrinks code).
2. Settings window skeleton with the checkboxes wired to live toggles (every later feature registers its toggle as it lands).
3. Item level spots: character sheet (cheapest, native), item tooltip, Inspect, then player tooltip finishing.
4. Region flags (small) and icon tooltips (UI/Table.lua only).
5. Dynamic refresh tuning, slide-up, preview demo (highest risk, most in-game tuning).
6. Release Review.

Defer: per-slot ilvl, colour tiers, ilvl-based finder sort, reduced-motion integration unless Forever exposes a CVar.

## Research flags

- **Needs in-game verification (cannot be settled from source):** (a) Forever's item tooltip may already show an Item Level line; (b) which stats-pane path (ScrollBox vs legacy banner) is live and whether the `PAPERDOLL_STATCATEGORIES` insert taints; (c) own-row shard from your GUID; (d) exact English strings (read from globals).
- Standard patterns, low risk: Settings registration, Inspect text, flag change.
- Highest uncertainty/complexity: slide-up animation on pooled ScrollBox rows.

## Sources

- Blizzard UI source, branch `forever` (HIGH): `Interface/AddOns/Blizzard_UIPanels_Game/Camelot/PaperDollFrame.lua`, `PaperDollFrameConstants.lua`, `CharacterFrame.lua`, `CharacterFrame.xml`; `Blizzard_InspectUI/Camelot/*` and `Mainline/*`; `Blizzard_GroupFinder_VanillaStyle/Blizzard_LFGVanilla_Browse.lua`, `Mainline/Blizzard_LFGVanilla_Browse.xml`, `Mainline/Blizzard_LFGVanilla_Listing.xml`; `Blizzard_Settings_Shared/Blizzard_ImplementationReadme.lua`, `Blizzard_SettingControls.lua`; `Blizzard_APIDocumentationGenerated/PaperDollInfoDocumentation.lua`, `TooltipInfoSharedDocumentation.lua`; `Blizzard_SharedXMLGame/Tooltip/TooltipDataHandler.lua`.
- [warcraft.wiki.gg API GetAverageItemLevel](https://warcraft.wiki.gg/wiki/API_GetAverageItemLevel) (MEDIUM): returns avg, equipped, PvP; player only; 16/17 slot divisor; lists Forever as supported.
- [warcraft.wiki.gg Item level](https://warcraft.wiki.gg/wiki/Item_level) (MEDIUM): equipped-average formula background.
- Retail tooltip look ("Item Level N" gold under the name) and the exact English global values: recalled, LOW; confirm in game.
