# Phase 2: List Foundation - Context

**Gathered:** 2026-11-11
**Status:** Ready for planning
**Mode:** `--auto` (author AFK; every grey area resolved with the recommended option, logged below
and in `02-DISCUSSION-LOG.md`)

<domain>
## Phase Boundary

The Browse list is rebuilt like the stock one, in place on `LFGBrowseFrame` (and in the preview
stand-in, which mirrors its layout):

1. **Scrolling (UIP-05)** — our own `WowScrollBoxList` + `MinimalScrollBar`, separate header and
   row frames with their own heights. Done first: it unblocks headers and the row look.
2. **Section headers (UIP-02)** — the finder's grouping header look (`common-button-list-collapseExpand`
   background, same atlas as ADD highlight, `common-button-list-plus`/`-minus`), fixing the
   author-reported bug where hovering a header shows the row highlight.
3. **Selection (UIP-03)** — by result ID, toggle off, not on delisted / own rows, cleared on new
   results, click sound, no double-click whisper.
4. **Layout (UIP-04)** — no second inset / border; search box in the stone band; column headers
   in the strip above `BarTop`; Needs my role + status in the bottom bar; the freed GS width goes
   to Roles / Activity.
5. **Row look (UIP-06)** — stock background / hover / selected art, stock fonts and colours,
   greyed rows in stock grey with desaturated icons, leader icon on group rows.
6. **Search states (UIP-10)** — stock spinner while searching, stock no-results / search-failed
   texts, our own text when our search box filters everything out.
7. **Sounds (UIP-12)** — row select, hide and checkboxes play the stock sounds.

Not in this phase (Phase 3): micro role icons and voice icon/wording (UIP-07), own-listing delist
button and "Your listing" in green (UIP-08), tooltip order (UIP-09), comment in light grey /
playstyle (UIP-13), hide button art (UIP-14), server remaining-slot counts (UIP-15), tooltip
refresh on update (UIP-16). Phase 4: Messages tab / panel, presets, contact lock.

</domain>

<decisions>
## Implementation Decisions

### Scrolling (UIP-05) — first plan, everything else builds on it
- **D-01:** Our own `WowScrollBoxList` + `MinimalScrollBar` (created with `W.Create` so a missing
  template falls back), set up with `CreateScrollBoxListLinearView()` and a **flat**
  `CreateDataProvider()` holding the items `Collect()` already produces (own listing, header,
  rows, header, rows). Collapse stays our own `view.collapsed` logic in `Collect()` (no
  TreeDataProvider) — it already works and keeps sorting simple.
- **D-02:** `ScrollUtil.InitScrollBoxListWithScrollBar(box, bar, view)` and
  `ScrollUtil.AddManagedScrollBarVisibilityBehavior(box, bar, withBar, withoutBar)` so the bar
  hides when the list fits (stock: box right edge -22 with bar, -6 without, bar 2 px right of
  the box). Data updates use `box:SetDataProvider(dp, ScrollBoxConstants.RetainScrollPosition)`
  so a refresh/re-sort keeps the scroll position.
- **D-03:** Element extents via `view:SetElementExtentCalculator`: **36** for headers (stock
  grouping height), **40** for rows (two text lines at our fonts; stock nested rows are 72,
  too tall for a table — UI-PARITY G13).
- **D-04:** Separate frame kinds with separate pools. A new XML file `UI/Templates.xml` (added
  to the TOC before `UI/Table.lua`) declares two plain virtual Buttons with no Blizzard
  inheritance and no scripts: `TerribleGroupFinderListHeaderTemplate` (36 tall) and
  `TerribleGroupFinderListRowTemplate` (40 tall). Their art is built in Lua on first acquire
  (factory "new frame" path / an init-once flag), with `W.Atlas` fallbacks so the preview renders
  anywhere. In game the header factory uses Blizzard's own `LFGBrowseSearchEntryGroupingTemplate`
  when `C_XMLUtil.GetTemplateInfo` finds it (it has no scripts — safe to inherit per UI-PARITY D9);
  otherwise our header template, whose Lua-built layers copy it exactly (BG at (3,-8)/(-3,0),
  label `GameFontNormal` LEFT 12,-4, plus/minus at RIGHT -12,-5, HIGHLIGHT same atlas ADD at
  (3,-7)/(-3,-1)). Rows NEVER inherit `LFGBrowseSearchEntryTemplate` /
  `LFGBrowseNestedSearchEntryTemplate` (their scripts touch Blizzard's selection — taint).
- **D-05:** Fallback where the ScrollBox API itself is missing (`CreateScrollBoxListLinearView`
  or `ScrollUtil` nil): keep `W.List`, extended to take a per-item kind and keep one pool per
  kind (header 36 / row 40), so both paths share the same header/row make + fill functions.
  The 4 px gold thumb stays only in that fallback.
- **D-06:** CLAUDE.md's Architecture list gains `UI/Templates.xml`; install/package scripts
  already derive the file set from the TOC (verify they ship the .xml).

### Section headers (UIP-02)
- **D-07:** Header frame shows the section label (`LFG_LIST_CATEGORY_SOLO_PLAYERS` /
  `LFG_LIST_CATEGORY_GROUPS`) plus our count in `GRAY_FONT_COLOR`; `ExpandIcon` shown when
  collapsed, `CollapseIcon` when expanded (as `Browse.lua:84-93`). Click toggles
  `view.collapsed[key]`; no sound (stock header has none). No tooltip on headers.
- **D-08:** Header frames carry no row highlight / selected texture at all — hovering a header
  only brightens its own atlas (the bug fix).

### Selection (UIP-03, part of UIP-12)
- **D-09:** Selection is stored as `inst.selectedID` (the listing's `id` = resultID), never a
  table reference. The selected listing is looked up by ID on each refresh; selection survives
  a re-sort, a hide, and a re-read where the ID is still present and not delisted.
- **D-10:** Cleared: on `LFG_LIST_SEARCH_RESULTS_RECEIVED` and `LFG_LIST_SEARCH_FAILED`, when a
  search starts (the existing `LFGBrowse_DoSearch` hook), when the selected ID is gone or
  delisted after a read, and in the preview on its refresh button. `InPlace.lua` passes the
  event to a `Table` method (e.g. `T.ClearSelection()`) — the generic `ReadSoon` stays for the
  other events.
- **D-11:** Click on a delisted row or your own listing does nothing (no sound). Click on any
  other row toggles: select, or clear if it was selected; both play
  `PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON)` (stock plays ON for both). The
  `OnDoubleClick` whisper is removed. Right-click does nothing this phase.
- **D-12:** Send Message enabled for any selection; Group Invite for a selected solo listing when
  `ns.CanInvite()`; since delisted / own rows cannot be selected, neither button acts on them.

### Layout (UIP-04)
- **D-13:** No second inset: `W.Inset` is no longer used by the table; `back` (the mouse blocker
  over Blizzard's hidden list) keeps `EnableMouse(true)` but draws no textures. Forever's own
  `Inset` (`groupfinder-background` + `common-insideframe`) is the only frame. The preview
  stand-in gets the same layers (`groupfinder-background` art + `common-insideframe` border,
  plus `groupfinder-ScrollLine` BarTop at art top -20 and BarMiddle at frame bottom +61) so it
  keeps mirroring the game (W.Inset may stay for the dropdown popup / fallback window only).
- **D-14:** Search box (`SearchBoxTemplate`, ~150 wide, instructions "Name, activity or note")
  sits in the stone band, vertically centred on the dropdown row, left edge just right of the
  refresh button (`LFGBrowseFrame.RefreshButton` in game, the stand-in's refresh in preview —
  `Table.Attach` gets it through the source/options table), and must end before the options gear
  (TOPRIGHT -12,-32). If the refresh anchor is missing, anchor TOPRIGHT of the host leaving
  ~48 px for the gear.
- **D-15:** Column headers sit in the 20 px strip from the art top down to `BarTop`, built from
  `ColumnDisplayButtonShortTemplate` (19 px, `GameFontHighlightSmall`) with the
  `auctionhouse-ui-sortarrow` atlas as the sort arrow (ascending texcoord 0,1,1,0; descending
  0,1,0,1). Fallback where the template / atlas is missing: the current flat buttons with
  "^"/"v" text. Header click sorts as today (same column flips, FIRST_DESC); no sound.
- **D-16:** The list (ScrollBox) runs from just below `BarTop` to just above `BarMiddle`
  (stock ScrollBox: TOPLEFT (7,-112) from the frame ≈ BarTop+10, BOTTOMRIGHT 40 above the frame
  bottom; ours must stop above BarMiddle (frame bottom +61) because the bottom bar holds our
  controls).
- **D-17:** Bottom bar (between Send Message, ending x≈132, and Group Invite, starting
  x≈width-130): **Needs my role** checkbox at the left (just right of Send Message), the
  "N solo players, M groups" status right-aligned just left of Group Invite (Who tab totals use
  `GameFontNormalSmall`-sized text at the bottom; keep `GameFontHighlightSmall`).
- **D-18:** Columns with GS off: Name 150, Lvl 30, **Roles 92** (was 76), Activity flexible,
  Listed 44, then the row buttons. Header and rows share one layout function (existing
  `Layout`), so they stay aligned; the header strip accounts for the scroll bar width the same
  way rows do.
- **D-19:** Width stays 620 (`UI/InPlace.lua` WIDE, `UI/MainFrame.lua` WIDE); Q1 (580-620)
  is for the in-game check.

### Row look (UIP-06)
- **D-20:** Section rows: `common-button-list-mid2` BACKGROUND at (3,-2)/(-3,0),
  `common-button-list-mid2-hover` ADD in the HIGHLIGHT layer at (3,-3)/(-3,-1),
  `common-button-list-mid2-selected` ADD in OVERLAY at (3,-3)/(-3,-1), shown when selected.
  Your own listing row: `groupfinder-highlightbar` BG / `-yellow` selected / `-blue` hover with
  the same insets (as `LFGBrowseSearchEntryTemplate`; own rows can't be selected, so only BG +
  hover matter). The per-row scroll line is dropped. Fallback colours where atlases are missing.
- **D-21:** Fonts: name `GameFontNormal` in class colour (table density, not stock's Large);
  level `GameFontDisable` (grey); activity in `GameFontHighlightSmall` coloured
  `GRAY_FONT_COLOR` by default and `BRIGHTBLUE_FONT_COLOR` when one of its activities matches
  your active listing's activities (`C_LFGList.GetActiveEntryInfo().activityIDs` in game,
  `ns.state.myListing` in preview; secret-guarded). The "+N" suffix stays (decided: keep ours,
  it fits the column). Comment line keeps its current font (light grey is Phase 3, UIP-13).
- **D-22:** Greyed rows (`demoted`: hidden / delisted / no slot with Needs my role): all row text
  in `{0.3,0.3,0.3}` (stock delisted grey) instead of cell alpha 0.4; class / leader / role
  icons `SetDesaturated(true)` with role icons at alpha 0.5 (stock); restored on reuse. Class-
  coloured names are drawn in the grey too while greyed. Buttons (Whisper / X) keep their own
  enabled state.
- **D-23:** Group rows show `groupfinder-icon-leader` instead of the class icon (solo rows keep
  the class icon), so groups are told apart at a glance; fallback: the class icon.
- **D-24:** The "(you)" suffix on the own row stays this phase ("Your listing" in green is
  UIP-08, Phase 3).

### Search states (UIP-10)
- **D-25:** While `LFGBrowseFrame.searching` (read-only), the list is emptied and our own
  `LoadingSpinnerTemplate` frame shows, centred on the art, with `SEARCHING` in
  `GameFontNormalLarge` just above it (stock anchors). Fallback where the template is missing:
  the label alone.
- **D-26:** After a search with no results, or a failed one (`LFGBrowseFrame.searchFailed`,
  read-only), our `GameFontDisable` text, 240 wide, at art TOP -40 shows
  `LFG_LIST_NO_RESULTS_FOUND` or `LFG_LIST_SEARCH_FAILED`. The source table gains
  `failed()`; the preview returns false for both.
- **D-27:** When results exist but our search box filters out every section row, the same text
  spot shows our own line: "No listings match your search." (shown even if your own listing row
  remains). The old "Nothing listed here..." line goes; in the preview with nothing in the
  chosen activities it shows `LFG_LIST_NO_RESULTS_FOUND`.

### Sounds (UIP-12)
- **D-28:** Row select / deselect: `IG_MAINMENU_OPTION_CHECKBOX_ON` (D-11). Hide (X) and show
  (+): `IG_MAINMENU_OPTION_CHECKBOX_ON` (stock row-button convention, as delist / refresh).
  Checkboxes (`W.Check`, used by Needs my role and the Messages tab): ON when checked, OFF when
  unchecked (`Listing.lua:648-654`). Section headers and column headers: no sound (stock none).
- **D-29:** `W.Check` moves to the template's own look: 26x26, uses the template's `.Text`
  (`GameFontNormalSmall`, gold) when present; fallback to our own label. Callers that read
  `c.Label` keep working (alias `c.Label = c.Text` or update callers). This also touches the
  Messages tab's Auto-send checkbox; that is intended (shared helper), Phase 4 refines it.

### Testing
- **D-30:** The fengari smoke harness (session scratchpad `smoke/`) is extended with stubs for
  `CreateScrollBoxListLinearView`, `CreateDataProvider`, `ScrollUtil`,
  `ScrollBoxConstants`, `C_XMLUtil.GetTemplateInfo`, `SOUNDKIT` / `PlaySound` and a stubbed
  `LFGBrowseFrame` / `LFGParentFrame` (with `BackgroundArt`, `RefreshButton`, `searching`,
  `searchFailed`), so it exercises both the preview path and the in-game attach path, plus the
  `W.List` fallback path (ScrollBox API nil). XML files in the TOC are skipped by the harness
  loader. Assertions: headers use the header kind (no row highlight), selection by ID survives
  re-sort and clears on results/search start, delisted/own rows not selectable, double-click
  gone, spinner shown while searching, no-results/failed/filtered texts, sounds played, Roles
  width 92. It must end with 0 failed.

### Claude's Discretion
- Exact pixel offsets inside the stone band and bottom bar, within the anchors above.
- Whether rows build their art in an `OnLoad`-like init-once function or in the factory
  initializer behind a `frame.tgfBuilt` flag.
- How `W.List` is extended for kinds (D-05), or whether the fallback reuses one frame per kind.
- Whether `T.ClearSelection` is a module function or per-instance.
- Sort arrow texcoords may be swapped if the atlas proves upside down (in-game check).

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Phase scope and rules
- `.planning/ROADMAP.md` — Phase 2 goal and success criteria
- `.planning/REQUIREMENTS.md` — UIP-02, UIP-03, UIP-04, UIP-05, UIP-06, UIP-10, UIP-12
- `CLAUDE.md` — taint rules, in place only, Forever only, stylua, no sed on .md / .planning
- `.planning/research/UI-PARITY.md` — gap table G5, G6-G14, G15, G27-G30, G34 and sections D1,
  D3, D4, D5, D8, D9 (taint notes); open questions Q1, Q2, Q3, Q5, Q7, Q8 for the in-game check

### Blizzard source (read-only, `C:\Users\jonat\Repositories\wow-ui-source`, branch `forever`)
- `Interface/AddOns/Blizzard_GroupFinder_VanillaStyle/Mainline/Blizzard_LFGVanilla_Browse.xml`
  — `:139-315` row / nested row / grouping templates; `:426-620` LFGBrowseFrame geometry
  (BackgroundArt, Bg stone, BarTop, BarMiddle, NoResultsFound, Inset, dropdowns, RefreshButton,
  ScrollBox / ScrollBar anchors, SearchingSpinner, OptionsButton, bottom buttons)
- `Interface/AddOns/Blizzard_GroupFinder_VanillaStyle/Blizzard_LFGVanilla_Browse.lua` — `:55-130`
  ScrollBox setup, element factory, managed scroll bar, selection behaviour; `:160-200`
  UpdateResults (spinner / no results); `:280-300` ValidateSelection; `:505-535` row click
- `Interface/AddOns/Blizzard_SharedXML/Shared/Scroll/ScrollBoxListView.lua` — factory by
  template or frame type; extent calculator requirement
- `Interface/AddOns/Blizzard_SharedXML/Mainline/SharedUIPanelTemplates.xml:1180-1219` —
  `ColumnDisplayButtonShortTemplate`
- `Interface/AddOns/Blizzard_GroupFinder_VanillaStyle/Blizzard_LFGVanilla_Listing.lua:648-654`
  — checkbox ON/OFF sounds
- `Interface/AddOns/Blizzard_GroupFinder_VanillaStyle/Mainline/WhoList.xml` — bottom totals text

### Our code
- `UI/Table.lua` — the whole table (rows, header, band, list, bottom buttons, selection)
- `UI/Widgets.lua` — `W.List`, `W.Check`, `W.Inset`, `W.RowHighlight`, `W.Atlas`, `W.Create`
- `UI/InPlace.lua` — attach, REPLACED parts, events, `LFGBrowse_DoSearch` hook, `source`
- `UI/MainFrame.lua` — preview stand-in Browse layout (stone, art, dropdowns, refresh)
- `TerribleGroupFinder.toc`, `scripts/install.ps1`, `scripts/package.ps1` — file set

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `Instance:Collect()` already builds the flat item list (own listing, header item, rows) with
  sort, collapse and demotion — it becomes the data provider's content unchanged.
- `Layout(owner, cells, rightAnchor, rightOffset)` aligns header cells and row cells; reuse it
  for the column header strip.
- `W.Create(frameType, parent, template)` already falls back when a template is missing;
  `W.Atlas` / `W.HasAtlas` give atlas-or-colour fallbacks.
- `StayHidden` in InPlace.lua keeps Blizzard's `ScrollBox`, `ScrollBar`, `NoResultsFound`,
  `SearchingSpinner`, bottom buttons hidden (already in `REPLACED`).

### Established Patterns
- One `view` table shared by every table instance (search, fitsRoles, sort, collapsed).
- `source` table passed to `T.Attach` (listings / preview / searching) — extend with `failed`
  and the refresh-button anchor.
- Listings have `id` (resultID in game; a counter in preview); the preview's own listing has no
  id and is `mine`.

### Integration Points
- `UI/InPlace.lua` `Attach()` → `ns.Table.Attach(f, f.BackgroundArt or f, source)`; events frame
  (`ReadSoon`); `LFGBrowse_DoSearch` hook.
- `UI/MainFrame.lua` `BuildBrowse` → `ns.Table.Attach(panel, art, {...})`; refresh button calls
  `ns.Table.RelistOneHidden` (should also clear selection).

</code_context>

<specifics>
## Specific Ideas

- Author-reported bug: hovering a section header shows the row highlight. The fix is the
  separate header frame with the finder's grouping look (D-04, D-08).
- The ScrollBox move (UIP-05) is planned first; headers and row look depend on it.

</specifics>

<deferred>
## Deferred Ideas

- Default order = stock order and a 3-state header click (G35) — future requirement list.
- Right-click menu (G25) — future.
- Compact role-count display for big groups (G18) — future.
- Preview stand-in using stock dropdown / tab / refresh templates (G38) — future.

</deferred>

---

*Phase: 02-list-foundation*
*Context gathered: 2026-11-11*
