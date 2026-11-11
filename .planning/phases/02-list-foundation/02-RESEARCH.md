# Phase 2: List Foundation - Research

**Researched:** 2026-11-11
**Domain:** WoW Forever (interface 16001, game type `camelot`) addon UI: Blizzard ScrollBox / DataProvider, XML virtual templates, Blizzard templates and atlases, taint rules
**Confidence:** HIGH for API shapes (read from the local `forever` branch source); MEDIUM for anything that depends on client-side data (atlases, addon XML in `C_XMLUtil`)

All Blizzard references are relative to `C:\Users\jonat\Repositories\wow-ui-source\Interface\AddOns\` (branch `forever`, read-only). Tags: `[CITED: path:line]` = read in that source file this session; `[ASSUMED]` = not verifiable from source.

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions
D-01..D-30 in `.planning/phases/02-list-foundation/02-CONTEXT.md` are locked. Summary the planner must honour:
- **D-01/D-02** Own `WowScrollBoxList` + `MinimalScrollBar` (via `W.Create`), `CreateScrollBoxListLinearView()`, **flat** `CreateDataProvider()` holding what `Collect()` already produces; collapse stays our `view.collapsed`; `ScrollUtil.InitScrollBoxListWithScrollBar` + `ScrollUtil.AddManagedScrollBarVisibilityBehavior` (box right -22 with bar, -6 without, bar 2 px right of box); updates use `ScrollBoxConstants.RetainScrollPosition`.
- **D-03** Extents via `SetElementExtentCalculator`: 36 header, 40 row.
- **D-04** New `UI/Templates.xml` (TOC before `UI/Table.lua`) with two scriptless, non-inheriting virtual Buttons `TerribleGroupFinderListHeaderTemplate` (36) and `TerribleGroupFinderListRowTemplate` (40); art built in Lua once; in game the header factory uses `LFGBrowseSearchEntryGroupingTemplate` when `C_XMLUtil.GetTemplateInfo` finds it. Rows NEVER inherit `LFGBrowseSearchEntryTemplate` / `LFGBrowseNestedSearchEntryTemplate`.
- **D-05** Where the ScrollBox API is missing, keep `W.List` extended with per-kind pools (header 36 / row 40) sharing the same make/fill functions; the 4 px gold thumb stays only there.
- **D-06** CLAUDE.md Architecture list gains `UI/Templates.xml`; verify install/package ship the .xml.
- **D-07/D-08** Header: label + gray count, Expand/Collapse icon swap, click toggles `view.collapsed[key]`, no sound, no tooltip, no row highlight/selected art at all.
- **D-09..D-12** Selection stored as `inst.selectedID` (listing `id`); cleared on `LFG_LIST_SEARCH_RESULTS_RECEIVED`, `LFG_LIST_SEARCH_FAILED`, search start (`LFGBrowse_DoSearch` hook), selected ID gone/delisted after a read, preview refresh; delisted / own rows not selectable and silent; toggle select/deselect plays `IG_MAINMENU_OPTION_CHECKBOX_ON`; `OnDoubleClick` removed; right-click nothing; Send Message for any selection, Group Invite for a selected solo listing when `ns.CanInvite()`.
- **D-13..D-19** No second inset (`back` blocks mouse, draws nothing; preview stand-in gets Forever's `groupfinder-background` + `common-insideframe` + BarTop/BarMiddle lines); search box in the stone band right of `RefreshButton` (fallback TOPRIGHT, ~48 px for the gear); column headers (`ColumnDisplayButtonShortTemplate`, `auctionhouse-ui-sortarrow`) in the 20 px strip above `BarTop`; list from just below `BarTop` to just above `BarMiddle`; bottom bar holds Needs my role (left) and status (right); columns Name 150, Lvl 30, Roles 92, Activity flexible, Listed 44; width stays 620.
- **D-20..D-24** Row art (mid2 trio; own listing highlightbar trio), fonts (`GameFontNormal` class-coloured name, `GameFontDisable` level, `GameFontHighlightSmall` activity gray/bright-blue), greyed rows = all text `{0.3,0.3,0.3}` + desaturated icons (role icons alpha 0.5), leader icon on group rows, "(you)" suffix stays.
- **D-25..D-27** Searching = list emptied + `LoadingSpinnerTemplate` + `SEARCHING` label; no results / failed = `GameFontDisable` text 240 wide at art TOP -40 (`LFG_LIST_NO_RESULTS_FOUND` / `LFG_LIST_SEARCH_FAILED`); our own "No listings match your search." when our box filters everything; source table gains `failed()`.
- **D-28/D-29** Sounds: row select/deselect, hide/show = CHECKBOX_ON; `W.Check` ON when checked / OFF when unchecked; `W.Check` becomes 26x26 with the template's `.Text` (keep `c.Label` alias).
- **D-30** Smoke harness extended (stubs listed in the task); must end with 0 failed.

### Claude's Discretion
- Exact pixel offsets inside the stone band and bottom bar, within the anchors above.
- Whether rows build their art in an `OnLoad`-like init-once function or in the factory initializer behind a `frame.tgfBuilt` flag.
- How `W.List` is extended for kinds (D-05), or whether the fallback reuses one frame per kind.
- Whether `T.ClearSelection` is a module function or per-instance.
- Sort arrow texcoords may be swapped if the atlas proves upside down (in-game check).

### Deferred Ideas (OUT OF SCOPE)
- Default order = stock order and a 3-state header click (G35).
- Right-click menu (G25).
- Compact role-count display for big groups (G18).
- Preview stand-in using stock dropdown / tab / refresh templates (G38).
- Phase 3 items (UIP-07/08/09/13/14/15/16) and Phase 4 (Messages tab / panel, presets, contact lock) are not in this phase.
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| UIP-02 | Section headers look/hover like the stock grouping header | Section "Header frames"; `Browse.xml:277-315` is scriptless, parentKeys `ResultBG/CategoryLabel/ExpandIcon/CollapseIcon/Highlight` |
| UIP-03 | Selection by result ID, toggle, not delisted/own, cleared, sound, no double-click | "Selection" pattern; stock `Browse.lua:141-153,187,288-296,521-532` |
| UIP-04 | Layout: no second inset, search box in band, column headers above BarTop, bottom bar controls | "Layout geometry"; `Browse.xml:426-596` anchors; ColumnDisplayButtonShort facts; managed-bar visibility callback for header alignment |
| UIP-05 | Blizzard ScrollBox + MinimalScrollBar, separate header/row frames and heights | "ScrollBox API (verified)" |
| UIP-06 | Stock row look: art, fonts, colours, greyed rows, leader icon | Atlas table, `Browse.lua:444-475` colour logic, `LFGBROWSE_DELISTED_FONT_COLOR = {0.3,0.3,0.3}` |
| UIP-10 | Spinner while searching, stock no-results/failed texts, own filtered text | `LoadingSpinnerMixin` (OnShow plays Anim), `Browse.lua:184-195`, field timing of `searching` |
| UIP-12 | Stock sounds for row select, hide, checkboxes | `SOUNDKIT` values, `Listing.lua:648-654` |
</phase_requirements>

## Summary

The ScrollBox stack is entirely in `Blizzard_SharedXML` (loaded for camelot, `[Family]` resolves to the Mainline folder per CLAUDE.md) and its API is small and stable: build a view with `CreateScrollBoxListLinearView()`, give it a **pure** `SetElementFactory(function(factory, elementData) ... factory(templateName, initializer) end)` and a `SetElementExtentCalculator(function(dataIndex, elementData) return number end)`, bind it with `ScrollUtil.InitScrollBoxListWithScrollBar(box, bar, view)`, then `box:SetDataProvider(dp, ScrollBoxConstants.RetainScrollPosition)`. Every data provider assignment synchronously releases all frames and re-acquires them (frames are never recycled on reassignment) and runs the initializers after layout; visible frames can be refreshed without that via `box:ReinitializeFrames()` or `box:ForEachFrame(fn)`.

The one real risk is the frame factory: it needs `C_XMLUtil.GetTemplateInfo(name)` to return info for the template name, otherwise it treats the string as a native frame type. Two native "Button" kinds would share one pool key, which is why D-04 mandates two distinct named templates. That addon XML templates are visible to `C_XMLUtil.GetTemplateInfo` cannot be proven from the source (the registry is C++); Blizzard's own FrameUtil/ScrollUtil call it on arbitrary template names. Gate the ScrollBox path on `C_XMLUtil.GetTemplateInfo(ROW_TEMPLATE) ~= nil` at build time so a miss lands on the `W.List` fallback instead of erroring, and verify in game (first UAT item).

Taint is manageable: everything is our own frames/pools; the only inherited Blizzard templates are scriptless. `LFGBrowseFrame.searching` / `.searchFailed` are plain fields set in `LFGBrowse_DoSearch` (after `C_LFGList.Search`) and the two search events, so reading them in the existing `hooksecurefunc("LFGBrowse_DoSearch")` post-hook is correct.

**Primary recommendation:** Build the ScrollBox path once in `T.Attach` behind a capability check (`CreateScrollBoxListLinearView`, `ScrollUtil`, `C_XMLUtil.GetTemplateInfo(rowTemplate)`), make `Fill(frame, item)` the single source of row/header look for both ScrollBox and `W.List`, and refresh with `SetDataProvider(dp, RetainScrollPosition)` for data changes and `ReinitializeFrames()` for selection/hover-only changes.

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| Search, listing reads, restricted calls | Blizzard finder (`LFGBrowseFrame`, `C_LFGList`) | `ns.Listings.Read` | Restricted (`Search`) stays Blizzard's |
| Result list rendering, sort, collapse, selection | `UI/Table.lua` (our frames in our ScrollBox) | `UI/Widgets.lua` helpers | We own all state (`view`, `inst.selectedID`) |
| Scroll / virtualization | Blizzard `WowScrollBoxList` instance created by us | `W.List` fallback | Template is Blizzard's, instance and view are ours |
| Hiding Blizzard's list, widening the window, events | `UI/InPlace.lua` | - | Only `Hide()`, `HookScript`, `hooksecurefunc`, parenting |
| Preview layers (art, BarTop/BarMiddle) | `UI/MainFrame.lua` | - | Mirrors the finder layout for development only |
| Sounds / colours / strings | Client globals read in `Widgets.lua` | - | Guard for nil outside the client |

## Standard Stack

### Core (all Blizzard, already loaded on camelot; no installs)
| Item | Source | Purpose |
|------|--------|---------|
| `CreateScrollBoxListLinearView(top,bottom,left,right,spacing)` | `Blizzard_SharedXML/Shared/Scroll/ScrollBoxLinearView.lua:246` | Vertical list view, all args default 0 |
| `CreateDataProvider(tbl)` | `Blizzard_SharedXML/DataProvider.lua:277` | Flat provider; `tbl` optional (`InsertTable`) |
| `WowScrollBoxList` (Frame template) | `Shared/Scroll/ScrollTemplates.xml:4` | Scroll box; `clipChildren=true`, has `ScrollTarget` child |
| `MinimalScrollBar` (EventFrame template) | `Shared/Scroll/MinimalScrollBar.xml` | 8x560 default, anchor both sides to stretch |
| `ScrollUtil.InitScrollBoxListWithScrollBar`, `.AddManagedScrollBarVisibilityBehavior` | `Shared/Scroll/ScrollUtil.lua:137,350` | Wire box/bar, auto-hide bar |
| `CreateAnchor(point, relativeTo, relativePoint, x, y)` | `Blizzard_SharedXMLBase/AnchorUtil.lua:58` | Anchor tables for the managed behaviour |
| `ScrollBoxConstants.RetainScrollPosition = true` | `Shared/Scroll/ScrollBox.lua:17` | |
| `ColumnDisplayButtonShortTemplate`, `UICheckButtonTemplate`, `SearchBoxTemplate`, `LoadingSpinnerTemplate`, `LFGBrowseSearchEntryGroupingTemplate` | see Templates table | Blizzard look |

### Package Legitimacy Audit
No external packages are installed by this phase (Blizzard templates only; the smoke harness' `fengari` already lives in the session scratchpad and is dev-only, not shipped). Audit: not applicable. Packages removed: none. Packages flagged: none.

## ScrollBox API (verified against source)

### View, factory, extents
```lua
-- Source: ScrollBoxLinearView.lua:246; ScrollBoxListView.lua (SetElementFactory ~l.560, factory l.19-33)
local view = CreateScrollBoxListLinearView()          -- (top,bottom,left,right,spacing), all default 0
view:SetElementFactory(function(factory, elementData)
	-- MUST be pure: it is also called with a dummy factory to read template/initializer
	-- (GetFactoryDataFromElementData) for template-info caching and ReinitializeFrames.
	if elementData.header then
		factory(HEADER_TEMPLATE, InitHeader)           -- (frameTemplateOrFrameType, initializer)
	else
		factory(ROW_TEMPLATE, InitRow)
	end
end)
view:SetElementExtentCalculator(function(dataIndex, elementData)  -- ScrollBoxLinearView.lua:154-161
	return elementData.header and 36 or 40            -- must return a number for EVERY item
end)
view:SetElementResetter(function(frame, elementData) end)  -- optional; called in Release before the pool resets
```
- Initializer signature: `initializer(frame, elementData)`. It is **not** called during the factory step; it runs after all frames are laid out (`InvokeInitializers`, via `secureexecuterange`), so `frame:GetWidth()` is valid inside it. There is no `new` argument. [CITED: ScrollBoxListView.lua:19-33, 408-425]
- Element data is whatever table you insert; `frame:GetElementData()` returns it unchanged for a linear view (`TranslateElementDataToUnderlyingData` is identity), so the listing/header table **is** the element data and rows need no extra mapping. Element data must be a **table** (frame recycling code checks `type(...) == "table"`). [CITED: ScrollBoxListView.lua:99-109, 700-715]
- **Built-once pattern.** Blizzard's own documented idiom is a flag in the initializer (comment above `SetElementInitializer`): `if not frame.created then frame.created = true; <one-time build> end; <regular init>`. Use `frame.tgfBuilt`. Alternative with a real `new` boolean: `ScrollUtil.AddAcquiredFrameCallback(box, function(owner, frame, elementData, new) ... end, owner)` (fires before the initializer; `ScrollUtil.lua:35-46`). Recommendation: the flag in the initializer (one code path, same function can serve the `W.List` fallback). Writing fields on **our** pooled frame is fine.
- **Resetting.** Pool default reset is `Pool_HideAndClearAnchors` (hide + ClearAllPoints) when no `SetFrameFactoryResetter` is set; `AcquireInternal` calls `frame:Show()`. So every initializer must set the complete visual state (selected texture, colours, desaturation, alpha, button texts) because a frame returns from the pool with the last row's state. Use `SetElementResetter` only for hover cleanup (`if GameTooltip:GetOwner() == frame then GameTooltip:Hide() end`). [CITED: Pools.lua:519-522, 659-662; ScrollBoxListView.lua:Release]
- **Pool key collisions.** `FrameFactoryMixin:Create` asks the template-info cache; if info exists the pool key is `template.."nil"`, otherwise the string is treated as a native frame type and the key is `"".."Button"`. Two factories that both pass `"Button"` therefore share ONE pool (header frames would be handed out as rows). Hence two named XML templates. [CITED: FrameFactory.lua:12-40; Pools.lua:300-305]
- The factory is called with a name for which `C_XMLUtil.GetTemplateInfo` returns nil -> `CreateFrame(<that name as type>)` error. Gate on `C_XMLUtil.GetTemplateInfo` before choosing the ScrollBox path (see Open Questions 1).
- Extent calculator + templates: even with a calculator the view still queries `GetTemplateInfo` for each distinct template during `RecalculateExtent` (`RebuildTemplateInfoCache`), but only the calculator's number is used for layout. [CITED: ScrollBoxLinearView.lua:224-257]

### Wiring and data
```lua
-- Source: Blizzard_LFGVanilla_Browse.lua:55-100 (stock), ScrollUtil.lua:137-148, 350-358
local box = W.Create("Frame", back, "WowScrollBoxList")
local bar = W.Create("EventFrame", back, "MinimalScrollBar")   -- explicit parent AND EventFrame type
bar:SetPoint("TOPLEFT", box, "TOPRIGHT", 2, -4)                -- stock Browse.xml:573-578
bar:SetPoint("BOTTOMLEFT", box, "BOTTOMRIGHT", 0, 2)
ScrollUtil.InitScrollBoxListWithScrollBar(box, bar, view)      -- after SetElementFactory
local withBar = {
	CreateAnchor("TOPLEFT", back, "TOPLEFT", 0, -22),          -- full form: (point, relativeFrame, relativePoint, x, y)
	CreateAnchor("BOTTOMRIGHT", back, "BOTTOMRIGHT", -22, 4),
}
local withoutBar = { withBar[1], CreateAnchor("BOTTOMRIGHT", back, "BOTTOMRIGHT", -6, 4) }
local behaviour = ScrollUtil.AddManagedScrollBarVisibilityBehavior(box, bar, withBar, withoutBar)
-- behaviour fires (owner, visible) when the bar toggles:
behaviour:RegisterCallback(ManagedScrollBarVisibilityBehaviorMixin.Event.OnVisibilityChanged, function(owner, visible)
	RelayoutColumnHeader(visible)                                -- keep the header strip aligned with the rows
end, owner)

local dp = CreateDataProvider()
dp:InsertTable(items)                                           -- items = what Collect() produced
box:SetDataProvider(dp, ScrollBoxConstants.RetainScrollPosition)
```
- The stock file's `CreateAnchor("TOPLEFT", myScrollBox.AnchorOffsetLeft, myScrollBox.AnchorOffsetTop)` passes numbers where `relativeTo` belongs (stock quirk). Do **not** copy it; use the full form with a real relative frame. Both anchor sets must each contain TOPLEFT and BOTTOMRIGHT because the behaviour does `ClearAllPoints()` then applies the set. [CITED: AnchorUtil.lua:3-52; ScrollUtil.lua:336-348]
- `AddManagedScrollBarVisibilityBehavior` returns the behaviour object (`return behavior`), shows/hides the bar on `box:HasScrollableExtent()` after every layout and size change. [CITED: ScrollUtil.lua:300-358]
- `ScrollBoxListMixin:SetDataProvider(dp, retain)` -> `view:SetDataProvider(dp)` (retain is handled in the box: `if not retain then ScrollToBegin`). The change signal runs `FullUpdate(UpdateImmediately)`: extents recalculated, scroll offset corrected against the old offset, **all frames released and re-acquired**, initializers run. Synchronous; no frame-by-frame diffing on reassignment. [CITED: ScrollBox.lua:703-722, 131-165; ScrollBoxListView.lua:667-715]
- **Never** call `SetDataProvider` (or anything that triggers it, e.g. `T.RefreshAll`) from inside an initializer/factory: `ScrollBoxListViewMixin:Acquire was reentrant` error. Fill functions must be side-effect free on the provider. Click handlers calling `RefreshAll` are fine.
- Empty list: `box:RemoveDataProvider()` (used by stock for searching) or set an empty provider. `SetDataProvider(nil)` errors.
- **Refreshing visible frames without a rebuild:**
  - `box:ReinitializeFrames()` re-runs every visible frame's initializer from the factory (ScrollBox.lua:614). Use for selection, hide state, hover-independent changes.
  - `box:ForEachFrame(function(frame, elementData) ... end)` (ScrollBox.lua:594) for custom per-frame work; `box:FindFrame(elementData)` (ScrollBox.lua:344) for one row.
  - Use `SetDataProvider(..., RetainScrollPosition)` when the item list changed (sort, collapse, new results, hide moving a row to the section end).
- Mouse wheel step = the first element's extent (`GetPanExtent`); nothing to configure.
- `ScrollBoxListLinearViewMixin` anchors each element TOPLEFT/TOPRIGHT of the scroll target, so elements stretch to the box width automatically. Row layout must be anchor-based (it already is: `Layout(owner, ...)` anchors to LEFT/RIGHT). [CITED: ScrollBoxViewUtil.lua:34-50]
- Scroll position on provider reassign: `FullUpdateInternal` keeps the offset; with `RetainScrollPosition` it is not reset to begin.

## Templates (what exists on the camelot client and whether it has scripts)

| Template | Defined in | Type | Scripts / taint note | Notes for use |
|----------|-----------|------|----------------------|---------------|
| `WowScrollBoxList` | `Blizzard_SharedXML/Shared/Scroll/ScrollTemplates.xml:4` (loaded via `Blizzard_SharedXML.toc:116`) | Frame | Mixin `ScrollBoxListMixin` + base OnLoad/OnSizeChanged/OnMouseWheel; shared SharedXML, safe to instantiate | `W.Create("Frame", parent, "WowScrollBoxList")`; Blizzard's own `Menu.lua:1793` does the same |
| `MinimalScrollBar` | `Shared/Scroll/MinimalScrollBar.xml` | **EventFrame** | Blizzard scroll scripts only | Needs explicit parent AND `"EventFrame"` type: `CreateFrame("EventFrame", nil, parent, "MinimalScrollBar")` (`Menu.lua:1795`). With `"Frame"` type the EventFrame mixin parts may be missing [ASSUMED: type mismatch behaviour] |
| `LFGBrowseSearchEntryGroupingTemplate` | `Blizzard_GroupFinder_VanillaStyle/Mainline/Blizzard_LFGVanilla_Browse.xml:277-315` | Button, 312x36 | **No Scripts block, no mixin** | parentKeys: `ResultBG` (BACKGROUND), `CategoryLabel` (GameFontNormal, `Size 200x18`, LEFT 12,-4), `ExpandIcon` (hidden), `CollapseIcon`, `Highlight` (HIGHLIGHT layer, ADD). Exists only after the LoD finder loads: check `C_XMLUtil.GetTemplateInfo` per factory call is cheap (cached) |
| `LFGBrowseSearchEntryTemplate` / `...NestedSearchEntryTemplate` | same file `:211-275` | Button | **Scripts** OnLoad/OnEvent/OnClick/OnEnter/OnLeave run `LFGBrowseFrame:ValidateSelection()` and `selectionBehavior:ToggleSelect` | Never inherit |
| `ColumnDisplayButtonShortTemplate` | `Blizzard_SharedXML/Mainline/SharedUIPanelTemplates.xml:1180-1219` | Button, 10x19 | **No scripts**. Textures `Left/Middle/Right` (`WhoFrame-ColumnTabs`), `ButtonText parentKey="Text"` anchored LEFT 8,0, `NormalFont GameFontHighlightSmall`, highlight texture | Set width per column; it has **no** sort arrow: create our own OVERLAY texture `SetAtlas("auctionhouse-ui-sortarrow", true)` anchored LEFT of `.Text` RIGHT +3,0 (AH does exactly this, `Blizzard_AuctionHouseTableBuilder.xml:204-211`). Text is left-aligned only; re-anchor `.Text` for centred / right columns |
| `LoadingSpinnerTemplate` | `Blizzard_SharedXML/SecureUIPanelTemplates.xml:229-266` | Frame 48x48 | Mixin `LoadingSpinnerMixin`: `OnShow` -> `self.Anim:Play()`, `OnHide` -> `Anim:Stop()` (`SecureUIPanelTemplates.lua:123-131`); touches only its own children | No explicit animation start: **`Show()` starts it** and `Hide()` stops it. It has no `Label`; the stock label is a FontString declared in the Browse XML on the spinner (`Browse.xml:582-590`), so create ours: `spinner:CreateFontString(nil,"ARTWORK","GameFontNormalLarge")`, `SetPoint("BOTTOM", spinner, "TOP")`, text `SEARCHING`. Created shown by default: `Hide()` right after creation |
| `SearchBoxTemplate` | `Shared/InputBox/InputBoxTemplates.xml:209-250` | EditBox | `SearchBoxTemplate_OnLoad/OnTextChanged/...` operate on self (`searchIcon`, `Instructions`, `clearButton`) | `Instructions:SetText(...)` works as today. Our `W.EditBox` already replaces OnEscape/OnEnter via SetScript (harmless); keep `HookScript("OnTextChanged")` |
| `UICheckButtonTemplate` | `Shared/Button/CheckButtonTemplates.xml:50-61` | CheckButton 32x32 | Only FontString OnLoad `UICheckButtonFontString_SetParentKeyAlias` (sets `parent.text`) | FontString `parentKey="Text"`, `GameFontNormalSmall`, anchored LEFT of the button's RIGHT at x=-2, y=0. `SetSize(26,26)` per D-29. Alias: `c.Label = c.Text` (Table.lua:759 anchors `search` to `self.fits.Label`; the search box moves out of the band so that anchor goes away) |
| `UIPanelButtonTemplate` | existing use | - | - | unchanged |

Taint relevance summary: the only inherited Blizzard templates with any script are `LoadingSpinnerMixin` (self-only), `ScrollBoxListMixin`/`ScrollBar` (generic Blizzard scroll code), and `SearchBox`/`UICheckButton` (self-only). All created by our code, parented to our frames or to `LFGBrowseFrame`; no Blizzard frame field is written. [CITED: files above]

### Our own XML (`UI/Templates.xml`) minimal form
```xml
<Ui xmlns="http://www.blizzard.com/wow/ui/">
	<Button name="TerribleGroupFinderListHeaderTemplate" virtual="true">
		<Size x="312" y="36"/>
	</Button>
	<Button name="TerribleGroupFinderListRowTemplate" virtual="true">
		<Size x="312" y="40"/>
	</Button>
</Ui>
```
- TOC line: `UI\Templates.xml` after `UI\Widgets.lua` and **before** `UI\Table.lua` (templates need to exist before `Table.lua` runs; Table.lua only uses them at `Attach` time, but keep the order). [ASSUMED: ordering needed only at CreateFrame time; harmless to keep before]
- `<Size>` is read into `XMLTemplateInfo.width/height` (`XMLUtilDocumentation.lua`); the extent calculator overrides it.
- Frame type `Button` is returned as `info.type`; the pool creates `CreateFrame("Button", nil, scrollTarget, templateName)`.
- Do **not** put `file="..."` attributes anywhere in `Templates.xml`: both `scripts/install.ps1:48` and `scripts/package.ps1:29` scan `.xml` files in the load list with the regex `\bfile\s*=\s*"([^"]+)"` and treat every match as a file to ship (a texture path would abort the deploy with "the file set includes ... which does not exist"). Atlas attributes are fine, but the plan is to keep art in Lua anyway. Also note `install.ps1` resolves such references from the repo root while `package.ps1` resolves them relative to the xml's folder (existing inconsistency; irrelevant while the XML has no `file=`).
- Verified: both scripts derive the file set from non-`#` TOC lines, so `UI\Templates.xml` is shipped by install and package without script changes; `.pkgmeta` ignores nothing relevant (no `*.xml`).
- Whether `C_XMLUtil.GetTemplateInfo` returns addon-defined virtual templates is a client-side fact: [ASSUMED] yes (it is the engine's XML template registry; ScrollBox usage with addon XML templates is the intended 10.0+ pattern). Verify first in game (UAT-1) and keep the `W.List` fallback if it returns nil.
- XML-free contingency (only if UAT-1 fails): ScrollBox accepts native frame types, so `factory("Button", ...)` for one kind and `factory("CheckButton", ...)` for the other give distinct pool keys (`"Button"` vs `"CheckButton"`) with no XML. Not locked by CONTEXT; mention only as a fallback to the fallback.

## Atlases (usage located in source; existence in the client data is client-side, not verifiable)

| Atlas | Used in source | Role here |
|-------|----------------|-----------|
| `common-button-list-mid2` / `-hover` / `-selected` | `Browse.xml:244,250,267` (nested row, 72 tall) | Section row BG / hover (ADD) / selected (ADD, OVERLAY) |
| `groupfinder-highlightbar` / `-yellow` / `-blue` | `Browse.xml:214,222` + `Classic/Browse.xml:183,191`; `-blue` also `Blizzard_GroupFinder/Mainline/LFGList.xml:852`, `-yellow` `LFGList.lua:3367` | Own-listing row BG / selected / hover; already used in our code (`W.RowHighlight`) |
| `common-button-list-collapseExpand` | `Browse.xml:281,307` | Header BG + highlight |
| `common-button-list-plus` / `-minus` | `Browse.xml:295,300`; also `SharedXML/ListTemplates.lua:13` | Header icons (plus = collapsed) |
| `groupfinder-icon-leader` | `Browse.xml:150` (PartyIcon, `useAtlasSize`, TOPLEFT 8,-14); markup size `14x9` in `Blizzard_GroupFinder/Mainline/LFGList.lua:4502` | Group-row leader icon: do not force 16x16, use the atlas size (or 14x9) |
| `auctionhouse-ui-sortarrow` | AH header `Blizzard_AuctionHouseTableBuilder.xml:207` with ascending `SetTexCoord(0,1,1,0)` / descending `(0,1,0,1)` (`.lua:913-918`) | Column header arrow; AH uses `PrimarySorted` = (0,1,1,0) |
| `groupfinder-ScrollLine`, `common-insideframe`, `groupfinder-background`, `groupfinder-Stat-StoneBG` | `Browse.xml:437-489`, `WhoList.xml:109-117` | Preview stand-in layers and existing `W.Line` |

Fallbacks stay mandatory: `W.Atlas(tex, atlas, r, g, b, a)` already returns false and sets a colour when `C_Texture.GetAtlasInfo` returns nil. `SetAtlas` with `useAtlasSize` = second argument `true`.

Stock row behaviour worth copying exactly (`Browse.lua:444-475`): delisted or not matching the activity filter -> name, level and activity all `LFGBROWSE_DELISTED_FONT_COLOR = {r=0.3,g=0.3,b=0.3}` (`Browse.lua:6`); level default `GRAY_FONT_COLOR`; activity `GRAY_FONT_COLOR` default, `BRIGHTBLUE_FONT_COLOR` when it matches the active listing, `LIGHTGREEN_FONT_COLOR` for your own; `ClassIcon:SetDesaturated(isDelisted)`. Note: the stock Highlight on nested rows is a BACKGROUND-layer texture shown from `OnEnter` (`Browse.xml:250`, `Browse.lua:536-540`), not a HIGHLIGHT-layer texture. D-20 chooses a HIGHLIGHT-layer ADD texture (automatic hover show/hide, no script needed); this is a deliberate simplification, equivalent visually.

## Globals and strings

| Item | Status |
|------|--------|
| `GRAY_FONT_COLOR`, `BRIGHTBLUE_FONT_COLOR`, `LIGHTGRAY_FONT_COLOR`, `LIGHTGREEN_FONT_COLOR`, `HIGHLIGHT_FONT_COLOR`, `RED_FONT_COLOR` | Used by the finder itself (`Browse.lua:7-9,444-475,924-934`) and by SharedXML (`BindingUtil.lua:228`, `FormattingUtil.lua:215`). Their definitions are engine-side (not in this source tree), so fields are `.r/.g/.b` and `:WrapTextInColorCode`. Guard with a local fallback table (`GRAY_FONT_COLOR or {r=.5,g=.5,b=.5}`) for non-client runs [CITED usage; definition not locally verifiable] |
| `SEARCHING`, `LFG_LIST_NO_RESULTS_FOUND`, `LFG_LIST_SEARCH_FAILED`, `LFG_LIST_CATEGORY_SOLO_PLAYERS`, `LFG_LIST_CATEGORY_GROUPS` | Global strings (not in the Lua/XML source); referenced at `Browse.xml:458,583` and `Browse.lua:195`. Always `X or "fallback"` |
| `SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON = 856`, `..._OFF = 857` | `Blizzard_SharedXML/Mainline/SoundKitConstants.lua:48-49`. Stock row click plays ON for select and deselect (`Browse.lua:521-532`); Listing checkbox plays ON when checked, OFF when unchecked (`Listing.lua:648-654`). Wrap: `if PlaySound and SOUNDKIT then PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON) end` |
| `C_LFGList.GetActiveEntryInfo()` | `MayReturnNothing`, `SecretInChatMessagingLockdown = true` (`LFGListInfoDocumentation.lua:139-150`) -> returns nil or a secret under lockdown; guard `issecretvalue(info)`. Its `activityIDs` field is `NeverSecret` (`:938`), so once the table itself is readable the IDs are usable. Stock uses `activeEntryInfo.activityIDs` + `tContains(searchResultInfo.activityIDs, id)` (`Browse.lua:405-412`) |
| `LFGBrowseFrame.RefreshButton` | `Browse.xml:517-557`, parentKey, 32x32, `LEFT` of ActivityDropdown +9; guard nil before anchoring the search box to it (D-14 fallback) |

## Architecture Patterns

### Data flow
```
events (RESULTS_RECEIVED / FAILED / UPDATED / ACTIVE_ENTRY_UPDATE / GROUP_ROSTER_UPDATE)
   -> InPlace: T.ClearSelection() for RECEIVED/FAILED; ReadSoon() timer for all
   -> ns.Listings.Read() (game) / ns.PreviewListings (preview)
   -> Instance:Refresh()
        |- searching? (LFGBrowseFrame.searching read-only) -> RemoveDataProvider + spinner
        |- Collect(): own listing, header, rows  (sort, collapse, demote, filter)
        |- state text: failed / none / filtered-by-search
        |- box:SetDataProvider(CreateDataProvider(items), RetainScrollPosition)
        '- status text, button enable state (by selectedID lookup)
click row  -> toggle inst.selectedID -> sound -> box:ReinitializeFrames() + button enable
click header -> view.collapsed[key] flip -> T.RefreshAll()
fallback (no ScrollBox API / template): same Collect() -> W.List:SetItems(items) with per-kind pools
```

### Recommended structure
```
UI/
  Templates.xml   # two virtual Buttons (no scripts, no file=)
  Widgets.lua     # W.List(kinds), W.Check(26, .Text, sounds), W.Sound(), colours helpers
  Table.lua       # Build/Fill for header + row; ScrollBox wiring; selection; states
  InPlace.lua     # source.failed, refresh anchor, ClearSelection routing
  MainFrame.lua   # preview layers (art, BarTop/BarMiddle), refresh anchor + ClearSelection
```

### Pattern: one Fill, two hosts
`Instance:FillRow(frame, item)` / `FillHeader(frame, item)` stay the only places that set look. The ScrollBox initializer is `function(frame, item) if not frame.tgfBuilt then inst:BuildRow(frame) frame.tgfBuilt = true end inst:FillRow(frame, item) end`; `W.List` calls the same make (once per pool frame) and fill. Header and row kinds are separate "makers" keyed by `item.header`.

### Pattern: selection by ID (no stale refs)
```lua
local function IsSelected(self, item)
	return self.selectedID ~= nil and item.id == self.selectedID   -- NIL GUARD: headers and the preview's own listing have id == nil
end
function Instance:Select(item)
	if item.header or item.mine or item.delisted then return end   -- silent
	self.selectedID = (self.selectedID == item.id) and nil or item.id
	PlayCheckbox(true)
	self:RefreshButtons(); self.list:Reinitialize()                 -- box:ReinitializeFrames()
end
```
After every `Collect()`: if `selectedID` is not found among non-delisted items, clear it (D-10 "gone or delisted").

### Anti-Patterns to Avoid
- `item.id == self.selectedID` without the nil guard: every header and the preview's own row (both `id == nil`) would render selected when nothing is selected.
- Calling `T.RefreshAll()` / `SetDataProvider` inside an initializer or `Fill` (reentrancy error).
- Passing the native type `"Button"` for both kinds (shared pool).
- Letting the factory callback create frames or have side effects (it is also invoked as a dummy for template lookups).
- Relying on pooled-frame state: every `Fill` must set every visual property (colour, alpha, desaturation, `SetShown` of selected art, button text/enabled).
- Using `SetDesaturated` only for "on": it persists across `SetAtlas`; always set `true`/`false` explicitly. On a texture that currently holds `SetColorTexture` it has no visible effect (fallback path), which is fine.

## Don't Hand-Roll

| Problem | Don't build | Use instead | Why |
|---------|-------------|-------------|-----|
| Scrolling / virtualization / bar | Row-step pool + gold thumb as the primary path | `WowScrollBoxList` + `MinimalScrollBar` + managed visibility | Drag, wheel, pan extent, bar hiding, scroll retention are done |
| Frame pooling in the ScrollBox path | Own pools | The view's frame factory | Release/Acquire, ordering, frame levels handled |
| Sort arrow art | Text "^"/"v" (primary) | `auctionhouse-ui-sortarrow` + texcoord flip | Stock look; keep text only as fallback |
| Spinner | Custom animation | `LoadingSpinnerTemplate` (`Show()` plays it) | Stock |
| Search box | EditBox + manual placeholder | `SearchBoxTemplate` | Already used |
| Checkbox label | Own `FontString` | Template `.Text` | D-29 |
| Header art | Own textures when the stock template is loaded | `LFGBrowseSearchEntryGroupingTemplate` (scriptless) | Exact stock look; copy in Lua only as fallback |

## Common Pitfalls

### Pitfall 1: Pool key collision between header and row
**What goes wrong:** Headers appear where rows should be (or vice versa) after a refresh.
**Why:** `factory("Button")` for both kinds shares the key `"Button"`. **Avoid:** distinct named templates (D-04). **Warning sign:** header frames carry row fields (`.name`) after scrolling.

### Pitfall 2: Template info missing -> factory error
**What goes wrong:** `CreateFrame("TerribleGroupFinderListRowTemplate", ...)` "invalid frame type" thrown inside `FullUpdate`.
**Avoid:** at build time `local ok = C_XMLUtil and C_XMLUtil.GetTemplateInfo and C_XMLUtil.GetTemplateInfo(ROW) and C_XMLUtil.GetTemplateInfo(HEADER)`; otherwise use `W.List`. For the Blizzard header template, test it at factory time and fall back to our header template (pure: `GetTemplateInfo` has no side effects).

### Pitfall 3: Reentrancy
Calling `SetDataProvider` (via `RefreshAll`) while an initializer runs throws. Hide (X) `OnClick` -> `RefreshAll` is fine (outside acquisition).

### Pitfall 4: MinimalScrollBar created wrong
Needs an explicit parent and the `"EventFrame"` type (Menu.lua:1795). Anchor both TOPLEFT and BOTTOMLEFT to the box, or it stays at 560 px tall. `W.Create` swallows template errors by falling back to a plain frame: check `box.SetDataProvider` and `bar.Init` exist before entering the ScrollBox path.

### Pitfall 5: Anchors that depend on Blizzard frames that might be nil
`LFGBrowseFrame.RefreshButton`, `.BackgroundArt`, `.Inset` can be nil on a changed build. Every anchor to them needs the D-14-style fallback (`f.BackgroundArt or f`). `back` anchored to `area`, never to optional parts.

### Pitfall 6: Header strip alignment when the bar toggles
Rows live inside the ScrollBox, whose right edge moves 16 px when the bar appears; the column header strip is outside it. Re-run the header `Layout(...)` from the `OnVisibilityChanged` callback with `rightOffset` = `-(ACTIONS_W + GAP)` plus 16 when the bar is visible (same inset the rows get). The ScrollBox's hidden state at first layout: bar visibility is evaluated after the first `OnLayout`, so also call the relayout once after `SetDataProvider`.

### Pitfall 7: Stale `searching` timing
`LFGBrowseFrame.searching = true` is set after `C_LFGList.Search(...)` returns, inside `LFGBrowse_DoSearch`, then `UpdateResults()` runs (`Browse.lua:331-352`). Our `hooksecurefunc("LFGBrowse_DoSearch")` post-hook sees `searching == true` -> `Refresh()` shows the spinner. If `DoSearch` was a no-op (already searching, or `categoryID == 0`) the hook still fires with the old values; clearing the selection there is harmless. `LFG_LIST_SEARCH_RESULTS_RECEIVED` / `FAILED` set `searching=false` in Blizzard's own OnEvent; our events frame registers later, and the 0.2 s `ReadSoon` timer reads after both. Stock also clears selection on every frame `OnShow` (`OnShow` -> `UpdateResultList` -> `UpdateResults` -> `ClearSelections`, `Browse.lua:159-166,187`); consider doing the same in `f:HookScript("OnShow")` for parity (not in D-10; optional, low risk).

### Pitfall 8: Greyed row state leaking through the pool
Colour/desaturation/alpha set for a demoted row must be explicitly reset by the next `Fill` of a non-demoted row (including class-coloured name via `SetTextColor` vs inline `|cff` codes: with inline codes the grey is overridden by the code, so when greyed strip the class colour code and use `SetTextColor(0.3,0.3,0.3)`; when not greyed set the class colour (or white) and let the string carry no `|cff` codes, or keep codes and set white). Pick one mechanism and apply it for every row.

### Pitfall 9: Role icon desaturation target
`W.RoleIcon` returns a Frame with `.tex`; desaturate `f.tex` and set `f:SetAlpha(0.5)`; `W.ClassIcon` is a texture (`SetDesaturated` directly). The leader icon replaces the class icon on group rows: the same texture object `SetAtlas("groupfinder-icon-leader", true)` vs `SetClass`; reset the size when switching (atlas-size vs 16x16).

### Pitfall 10: Taint (CLAUDE.md)
Never inherit the two entry templates; never write fields on Blizzard frames (our `tgfBuilt`, `listing`, etc. go only on frames we create; `LFGBrowseFrame.searching/.searchFailed/.RefreshButton/.BackgroundArt` are read-only); only `Hide()` + `hooksecurefunc` on Blizzard parts (existing `StayHidden`). Note `StayHidden` on `NoResultsFound` (a FontString region) hooks `Show`/`SetShown`, which regions have; Blizzard's `UpdateResults` also calls `SetText` on it (harmless while hidden). Open Q8 (other re-show routes) remains an in-game check.

## Runtime State Inventory
Not applicable (no rename/refactor/migration). One persisted-data note: nothing new is saved this phase (`view` and `inst.selectedID` are session state); `TerribleGroupFinderDB` unchanged.

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| node | smoke harness | yes | v24.14.0 | - |
| fengari (npm, scratchpad `smoke/node_modules`) | smoke harness | yes | installed in scratchpad | - |
| stylua | CLAUDE.md "run after each task" | yes | 2.3.1 | - |
| Forever client (`_forever_`) | in-game UAT | assumed (user's machine) | - | preview via `/tgf preview` |

Baseline: `node run.js "C:/Users/jonat/Repositories/TerribleGroupFinder"` currently prints `SUMMARY: 0 failed`.

## Validation Architecture

(`workflow.nyquist_validation` is `false` in `.planning/config.json`; included because the task asks for it.)

### Test Framework
| Property | Value |
|----------|-------|
| Framework | Custom fengari (Lua 5.3 in node) smoke harness, outside the repo (session scratchpad) |
| Location | `C:\Users\jonat\AppData\Local\Temp\claude\3a677a53f55271b6\8039163f-18e8-4930-88a2-d8efcca63b25\scratchpad\smoke\` (`run.js`, `harness.lua`, `tail.lua`, `splice.js`) |
| Run | `node run.js "C:/Users/jonat/Repositories/TerribleGroupFinder"` (add `--gs` for the GS-on branch) |
| Exit | `os.exit(fail == 0 and 0 or 1)`, last line `SUMMARY: N failed` |
| Edit flow | edit `tail.lua`, then `node splice.js` re-splices it into `harness.lua` (everything from `local fail = 0`); stub changes go in the top part of `harness.lua`. The harness must not be modified by the research task; the plan's test task owns it (D-30) |

### How the harness loads the TOC (matters for the XML entry)
`run.js` reads every non-`#` TOC line into `FILELIST`; `harness.lua:144-156` runs only entries matching `%.lua$`, so `UI\Templates.xml` is **already skipped** with no change (it is simply not loaded; templates "do not exist" as far as the stub is concerned, which `C_XMLUtil.GetTemplateInfo` stubs must then answer for). Chunks are called with `("TerribleGroupFinder", ns)`.

### Stub behaviour that matters (current `newFrame`)
- Unknown getter-like names return a chainable no-op for `^Set|Get|Is|Enable|...`; other missing members (`Text`, `Instructions`, `Left`, `ScrollTarget`) are `nil`. So `.Text` is nil on the stub check button (exercises the fallback label), and `box.SetDataProvider` is nil unless the stub adds it (natural detection for the fallback path).
- `SetShown` is NOT implemented (falls into the generic `^Set` no-op), so `IsShown()` does not follow `SetShown`. The ScrollBox-path tests need `M("SetShown", ...)` added to `newFrame`, plus recorders for `SetTextColor`, `SetDesaturated`, `SetAlpha`, `SetVertexColor`.
- `CreateFrame` ignores the template (stores `__template`), so template presence must be simulated through `C_XMLUtil` + the stubs below.
- `HookScript` keeps only the first hook; `hooksecurefunc` is a no-op (so `StayHidden` and the `LFGBrowse_DoSearch` hook do nothing: stub it to record and, for the search-start test, call the recorded post-hooks manually).
- `G.PlaySound = function() end` -> replace with a recorder (`log.sounds[#log.sounds+1] = id`); `SOUNDKIT` is absent today (code must guard; tests set it).
- Atlases: `C_Texture.GetAtlasInfo` returns nil -> all `W.Atlas` calls take the colour fallback; a flag returning `{}` exercises the atlas branches (`SetAtlas` stub returns true).
- Existing `table` probe (tail.lua:110-131) walks `inst.list.rows`, `inst.header.gs`, `row.cells`: it will break once rows live in a ScrollBox; update it to enumerate frames through the stub box (`box:ForEachFrame`) or `inst.list` accessor.

### Stubs to add for the three paths
1. **ScrollBox path** (default after adding stubs):
   - `CreateScrollBoxListLinearView()` -> table with `SetElementFactory(fn)`, `SetElementExtentCalculator(fn)`, `SetElementResetter(fn)` storing the functions.
   - `CreateDataProvider(tbl)` -> `{ collection = {}, InsertTable, Insert, GetSize }`.
   - `CreateAnchor(...)` -> table; `ScrollUtil = { InitScrollBoxListWithScrollBar = function(box, bar, view) box.__view = view end, AddManagedScrollBarVisibilityBehavior = function() return { RegisterCallback = function() end } end }`; `ScrollBoxConstants = { RetainScrollPosition = true, DiscardScrollPosition = false }`; `ManagedScrollBarVisibilityBehaviorMixin = { Event = { OnVisibilityChanged = "OnVisibilityChanged" } }`.
   - In `G.CreateFrame`: when `tmpl == "WowScrollBoxList"` add methods `SetDataProvider(dp, retain)` (record `retain`; release previous frames; for each item call `view.elementFactory(fakeFactory, item)` where `fakeFactory(template, init)` pulls/creates a frame from a per-template pool via `CreateFrame("Button", nil, box, template)`, sets `GetElementData`, then calls `init(frame, item)`), `RemoveDataProvider`, `ForEachFrame`, `ReinitializeFrames`, `FindFrame`, `GetDataProviderSize`, `GetDataProvider`. Per-template pools make the "headers never get row frames" assertion meaningful (assert `frame.__template` per item kind).
   - `C_XMLUtil = { GetTemplateInfo = function(n) return known[n] end }` with `known` = `{ TerribleGroupFinderListHeaderTemplate = {type="Button",width=312,height=36}, TerribleGroupFinderListRowTemplate = {...,height=40}, LFGBrowseSearchEntryGroupingTemplate = {...} }` (the last one toggled by a flag to test both header branches).
2. **`W.List` fallback path:** a flag (e.g. `--fallback`) that sets `CreateScrollBoxListLinearView = nil` (and/or `C_XMLUtil.GetTemplateInfo` -> nil). Assertions: rows still show, header items use the header maker, per-kind pool sizes (header 36 / row 40), no ScrollBox frames created.
3. **In-game attach path:** before the TOC loads, define stub globals `LFGParentFrame` (with `GetWidth`, `WhoListingTab`, `BrowsingTab`), `LFGBrowseFrame` (with `BackgroundArt`, `RefreshButton`, `ScrollBox`, `ScrollBar`, `SearchingSpinner`, `NoResultsFound`, `SendMessageButton`, `GroupInviteButton`, `searching=false`, `searchFailed=false`), `LFGListingFrame`, `LFGWhoListFrame`, `LFGBrowse_DoSearch` (function), `LFGVanilla_ToggleFrame`; `C_LFGList = { GetSearchResultInfo = fn, GetPremadeGroupFinderStyle = fn, GetFilteredSearchResults = function() return 0, {} end, GetActiveEntryInfo = fn, HasActiveEntryInfo = fn }` so `ns.Listings.HasAPI()` is true; make `C_AddOns.IsAddOnLoaded` a flag-driven function (`InPlace.lua:36` captures it at file load, so it must exist when the chunk runs) returning true for `Blizzard_GroupFinder_VanillaStyle`. `ADDON_LOADED` is fired by the harness already (`harness.lua:158-164`) -> `IP.Init` -> `Attach`. To avoid stubbing the whole listing read, set `ns.state.preview = true` after init (`ns.UsingPreview()` true) so `source.listings()` returns the sample data while attach, hooks, `searching()`/`failed()` and widening still run. Search state: toggle `LFGBrowseFrame.searching` / `.searchFailed` and call `inst:Refresh()`.

### Phase Requirements -> Test Map
| Req | Behaviour | Type | Automated check (harness assertion) |
|-----|-----------|------|--------------------------------------|
| UIP-05 | list built on ScrollBox; fallback works; header/row use separate templates, extents 36/40 | smoke | frames created with `__template` HEADER/ROW; `elementExtentCalculator(1, headerItem) == 36`, row `== 40`; with `--fallback` no ScrollBox, pools per kind |
| UIP-05 | refresh keeps scroll position | smoke | `SetDataProvider` called with `retain == true` on Refresh |
| UIP-02 | header frames have no row highlight/selected art; header click toggles collapse and icon | smoke | header frame has no `selected`/row-highlight fields; click -> `view.collapsed` flips, items shrink; ExpandIcon/CollapseIcon shown states |
| UIP-03 | selection by ID survives re-sort and hide; clears on RESULTS/FAILED/search start/ID gone/delisted | smoke | click row -> `inst.selectedID == id`; change `view.sort`, refresh -> still selected; call `T.ClearSelection()` -> nil; hook post-fire; remove listing -> cleared |
| UIP-03 | delisted and own rows not selectable, silent; toggle off; no double-click | smoke | click delisted/own -> `selectedID` unchanged and `#log.sounds` unchanged; second click on selected -> nil; `row.__scripts.OnDoubleClick == nil` |
| UIP-03 | nil-id guard | smoke | with nothing selected, no header/own-listing frame has selected art shown |
| UIP-12 | sounds | smoke | select and deselect each record 856; hide/show records 856; `W.Check` toggle on -> 856, off -> 857; header and column header clicks record nothing |
| UIP-04 | Roles width 92, GS off; header and rows share Layout | smoke | `LEFT[3].w == 92` via a recorded `SetWidth` on the roles cell and header cell; no `W.Inset` frame created by `T.Attach` |
| UIP-04 | search box anchored to refresh button, fallback TOPRIGHT | smoke | record `SetPoint` args on the search box with and without `RefreshButton` |
| UIP-06 | greyed rows: all text `{0.3,0.3,0.3}`, class/leader icons desaturated, role alpha 0.5; restored on reuse | smoke | demoted listing -> recorder shows `SetTextColor(0.3,0.3,0.3)` and `SetDesaturated(true)`; then re-`Fill` with a normal listing -> `SetDesaturated(false)`, alpha 1 |
| UIP-06 | group rows use leader icon atlas, solo rows class icon | smoke | atlas flag on; record `SetAtlas` names |
| UIP-06 | activity colour bright-blue only when matching active listing | smoke | `GetActiveEntryInfo` stub returns `{activityIDs={...}}`; also secret-valued return gives gray, no error |
| UIP-10 | searching: list emptied, spinner shown, label; failed/no-results/filtered texts | smoke | set `LFGBrowseFrame.searching=true` -> provider removed/empty, spinner `IsShown()`; `searchFailed=true` -> text `LFG_LIST_SEARCH_FAILED`; empty -> `LFG_LIST_NO_RESULTS_FOUND`; set `view.search` to no match with results present -> "No listings match your search." |
| D-29 | checkbox: `.Text` used when present; `.Label` alias keeps working | smoke | stub `.Text` present: `c.Label == c.Text` and label text set; absent: own label |
| Regression | `SUMMARY: 0 failed` for GS off and `--gs`; `stylua .` clean | smoke | exit code 0 |

### Sampling Rate
- Per task commit: run the harness (`node run.js ...`, ~1 s) and `stylua .` (CLAUDE.md).
- Per wave merge: harness in default, `--gs`, and fallback mode, plus the attach-path run.
- Phase gate: all runs 0 failed, then deploy (`./scripts/install.bat`) and the in-game UAT below.

### Wave 0 Gaps
- [ ] Add the stubs above to `harness.lua` and the new assertions to `tail.lua` (outside the repo; owned by the plan's test task, D-30).
- [ ] Update the old `table` probe that walks `inst.list.rows` / `inst.header.gs` for the new structure.
- [ ] Add `UI\Templates.xml` to the TOC and CLAUDE.md Architecture list (D-06).

### In-game UAT (cannot be proven from source)
1. **UAT-1 (first):** `C_XMLUtil.GetTemplateInfo("TerribleGroupFinderListRowTemplate")` is non-nil in Forever (`/dump C_XMLUtil.GetTemplateInfo("TerribleGroupFinderListRowTemplate")`); otherwise the list silently uses the `W.List` fallback.
2. Scroll wheel and dragging the `MinimalScrollBar`; bar hides when the list fits; scroll position survives re-sort, hide, refresh.
3. Header hover only brightens the header (the author-reported bug); +/- swap; no tooltip.
4. Row hover/selected art at 40 px (Q5: if `common-button-list-mid2*` stretches badly, switch all rows to the highlightbar trio); selected survives re-sort, clears on new search; delisted/own rows inert; click sound.
5. Column header strip above BarTop, sort arrow direction (Q7; swap texcoords if upside down), alignment with rows when the bar appears/disappears.
6. Search box fits between refresh and gear (Q2); BarTop not crossed (Q3); width 620 vs 580 (Q1).
7. Spinner animates while searching; no-results / failed / filtered texts; Forever never re-shows its own hidden spinner/NoResultsFound (Q8).
8. No `ADDON_ACTION_BLOCKED` / taint messages when clicking rows, searching, switching tabs, opening Listing (`/console taintLog 1` if needed).
9. Checkbox sounds ON/OFF; hide/show sound; Messages tab Auto-send checkbox still lays out with the 26x26 template check.

## Security Domain

`security_enforcement` is not set (treated as enabled); this is a client-side UI addon with no network or credentials.

| ASVS Category | Applies | Control |
|---------------|---------|---------|
| V2/V3/V4 auth, session, access | no | - |
| V5 Input validation | yes (limited) | Search box text is only used with `string.find(..., 1, true)` (plain), comments via `pcall`; keep plain matching, guard `issecretvalue()` on every API-derived string before string ops |
| V6 Cryptography | no | - |

| Pattern | STRIDE | Mitigation |
|---------|--------|------------|
| Tainted code invoking restricted finder calls | Elevation | Never call `Search/CreateListing/UpdateListing`; only read fields; no field writes on Blizzard frames; no inheritance of the entry templates |
| Secret values (chat-lockdown) used as keys / compared | Information disclosure / DoS (Lua error) | `issecretvalue` guards (`GetActiveEntryInfo`, names from `C_LFGList.*`); `Listings.Read` already skips secret listings |
| Addon message / whisper during lockdown | - | Unchanged this phase (`C_ChatInfo.InChatMessagingLockdown()` guard stays in Messages) |

## State of the Art

| Old approach | Current approach | Impact |
|--------------|------------------|--------|
| `FauxScrollFrame` / HybridScrollFrame (still in tree, "deprecated; retained for legacy", `Blizzard_SharedXML.toc:239-241`) | `WowScrollBoxList` + data provider + `MinimalScrollBar` (10.0+ pattern) | Use the new stack |
| Template-name-only element initializer | `SetElementFactory(function(factory, data) ... end)` + `SetElementExtentCalculator` | Needed for two kinds with different heights |

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | `C_XMLUtil.GetTemplateInfo` resolves virtual templates declared in addon XML | ScrollBox API / Templates | ScrollBox path unusable, falls to `W.List` (planned guard); contingency native `Button`/`CheckButton` pool keys |
| A2 | `CreateFrame("Frame", ..., "MinimalScrollBar")` (wrong type) misbehaves; `"EventFrame"` is required | Templates | Low: we use `"EventFrame"` as Blizzard does |
| A3 | TOC order only matters in that XML must be loaded before `CreateFrame` uses it | Our own XML | None if kept before `Table.lua` |
| A4 | Colour globals have `.r/.g/.b` (definitions are engine-side) | Globals | Low; local fallbacks guard |
| A5 | Atlas names exist in the Forever client data | Atlases | Cosmetic; colour fallbacks (Q5/Q7) |
| A6 | A HIGHLIGHT-layer ADD hover texture on our own Button behaves like the stock script-driven one | Atlases | Cosmetic |

## Open Questions (RESOLVED)

1. **Addon XML visible to `C_XMLUtil`?** Known: Blizzard always resolves template names through it; nothing in source forbids addon templates. Unclear: not testable locally. Recommendation: capability gate + UAT-1 first; fallback already planned (D-05).
   RESOLVED: plan 02-01 gates the ScrollBox path on `C_XMLUtil.GetTemplateInfo` for both templates and falls back to the per-kind `W.List`; in-game check UAT-1 confirms which path runs.
2. **`LFGBrowseSearchEntryGroupingTemplate` inside our pool in a `[Secure]`-flagged addon world.** The template lives in a `## Secure: 1` addon, but instantiating its scriptless virtual from addon code is the same as inheriting it in XML; no script runs. Recommendation: keep `tgfBuilt`-flag one-time script (`SetScript("OnClick")`) on our own frame only.
   RESOLVED: plan 02-01 builds header frames once behind `tgfBuilt` and sets the OnClick on our own pooled frame only; nothing is written to Blizzard's frames.
3. **Selection clear on tab re-show (stock does it).** Recommendation: add `OnShow` clear in `Attach` for parity unless the author wants selection to persist across tabs.
   RESOLVED (adopted, stock parity, orchestrator decision in the AFK run): the Browse frame's existing `OnShow` hook in `UI/InPlace.lua` `Attach` calls `ns.Table.ClearSelection()` (plan 02-02 Task 3); the preview stand-in clears it when its Browse tab is selected. Recorded as an in-game check in the 02-02 SUMMARY.

## Sources

### Primary (HIGH confidence, local `forever` branch)
- `Blizzard_SharedXML/Shared/Scroll/{ScrollBoxListView,ScrollBoxLinearView,ScrollBox,ScrollUtil,ScrollBoxViewUtil,ScrollTemplates.xml,MinimalScrollBar.xml}`, `Blizzard_SharedXML/DataProvider.lua`, `Blizzard_SharedXMLBase/{FrameFactory,TemplateInfoCache,Pools,AnchorUtil}.lua`
- `Blizzard_GroupFinder_VanillaStyle/Blizzard_LFGVanilla_Browse.lua` (55-130, 141-200, 288-296, 331-352, 405-475, 505-540), `Mainline/Blizzard_LFGVanilla_Browse.xml` (139-315, 426-596), `Blizzard_LFGVanilla_Listing.lua:648-654`
- `Blizzard_SharedXML/Mainline/SharedUIPanelTemplates.xml:1180-1219`, `SecureUIPanelTemplates.xml/.lua` (LoadingSpinner), `Shared/Button/CheckButtonTemplates.xml:50-61`, `Shared/InputBox/InputBoxTemplates.xml:209-250` and `.lua:175-200`, `Mainline/SoundKitConstants.lua:48-49`
- `Blizzard_AuctionHouseUI/Shared/Blizzard_AuctionHouseTableBuilder.{xml,lua}` (sort arrow), `Blizzard_Menu/Menu.lua:1793-1795` (ScrollBox/ScrollBar creation in code)
- `Blizzard_APIDocumentationGenerated/{LFGListInfoDocumentation,XMLUtilDocumentation}.lua`
- Project: `UI/Table.lua`, `UI/Widgets.lua`, `UI/InPlace.lua`, `UI/MainFrame.lua`, `Core.lua`, `TerribleGroupFinder.toc`, `scripts/install.ps1`, `scripts/package.ps1`, `.pkgmeta`, smoke harness files (read; baseline run 0 failed)

### Secondary / Tertiary
- None. No web search used (source is local and authoritative). Atlas existence and addon-XML template visibility are not verifiable from source (see Assumptions).

## Metadata

**Confidence breakdown:**
- Standard stack / ScrollBox API: HIGH (read end to end)
- Architecture: HIGH (follows CONTEXT decisions, Blizzard patterns)
- Templates and taint: HIGH for scripts/fields; MEDIUM for addon-XML template info (A1)
- Atlases / colours: MEDIUM (usage cited, data client-side)
- Harness plan: HIGH (read harness; baseline run passes)

**Research date:** 2026-11-11
**Valid until:** 2026-12-11 (client builds can change the `forever` branch; re-check ScrollBox files if the branch is updated)
