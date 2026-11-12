# Phase 2: List Foundation - Pattern Map

**Mapped:** 2026-11-11
**Files analyzed:** 8 (1 new, 7 modified)
**Analogs found:** 8 / 8 (one only partial: the ScrollBox wiring has no in-repo analog; Blizzard source is the analog)

All paths are relative to `C:\Users\jonat\Repositories\TerribleGroupFinder` unless stated. Blizzard references are
relative to `C:\Users\jonat\Repositories\wow-ui-source\Interface\AddOns\` (branch `forever`, read-only).

## File Classification

| New/Modified File | Role | Data Flow | Closest Analog | Match Quality |
|-------------------|------|-----------|----------------|---------------|
| `UI/Templates.xml` (new) | config (virtual XML templates) | none (declarative) | `C:\Users\jonat\Repositories\TerribleBuffTracker\CDMTab.xml` | role-match (XML shape and TOC wiring only) |
| `UI/Table.lua` | component (table: rows, headers, selection, states) | request-response + event-driven (refresh) | itself (`Instance:MakeRow/FillRow/Collect/Refresh`, `T.Attach`) + Blizzard `Blizzard_LFGVanilla_Browse.lua:55-130` for ScrollBox | exact (self) / partial (ScrollBox) |
| `UI/Widgets.lua` | utility (widget helpers) | transform | itself (`W.List`, `W.Check`, `W.Atlas`, `W.Create`) | exact (self) |
| `UI/InPlace.lua` | provider/attach (hooks, events) | event-driven | itself (`source`, `Attach`, `EVENTS`, `LFGBrowse_DoSearch` hook) | exact (self) |
| `UI/MainFrame.lua` | component (preview stand-in layout) | request-response | itself (`BuildBrowse`) + Blizzard `Mainline/Blizzard_LFGVanilla_Browse.xml:426-620` | exact (self) |
| `TerribleGroupFinder.toc` | config | none | itself (load list) | exact |
| `CLAUDE.md` (Architecture list) | docs | none | itself (the `UI/*.lua` bullets) | exact |
| smoke harness (scratchpad, outside repo) | test | batch | existing `smoke/harness.lua` + `tail.lua` (per RESEARCH.md; not in repo) | exact |

## Pattern Assignments

### `UI/Templates.xml` (config, declarative)

**Analog:** `C:\Users\jonat\Repositories\TerribleBuffTracker\CDMTab.xml` (only XML in the sister addon; no ScrollBox there, so it
is a shape reference only) and its TOC line `CDMTab.xml` (TBT toc line 22: the XML is listed like a Lua file).

**XML header + shape** (CDMTab.xml lines 1-2, 17-21): root `<Ui xmlns="http://www.blizzard.com/wow/ui/" ...>`, then
named virtual-style frames with `<Size x= y=/>`. Ours is simpler (RESEARCH.md "Our own XML"):
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
Rules for the planner:
- No `inherits`, no `<Scripts>`, no `parentArray` (taint rule the sister addon also documents in its comments), and **no `file="..."`
  attribute anywhere**: `scripts/install.ps1:48` and `scripts/package.ps1:29` regex-scan `.xml` files in the load list for
  `file="..."` and treat each as a file to ship.
- Tabs for indentation (matches `.xml` in TBT and stylua-free repo style).
- Art is built in Lua (see Table.lua assignment), not in XML.

**TOC placement** (`TerribleGroupFinder.toc` lines 15-23): add `UI\Templates.xml` between `UI\Widgets.lua` and `UI\Table.lua`.

---

### `UI/Table.lua` (component, request-response + event-driven)

**Analog:** itself. Keep the module shape; replace the row host (`W.List` + `MakeRow`) with the ScrollBox path while `MakeRow`/`FillRow`
become build-once + fill-always.

**Header comment / module preamble to keep** (lines 15-23):
```lua
local _, ns = ...
local W = ns.W
local wipe = W.wipe

local lower, find, format = string.lower, string.find, string.format
local max, min = math.max, math.min

local T = { instances = {} }
ns.Table = T
```

**Constants to change** (lines 25-61): `ROW_HEIGHT = 32` goes (rows 40, headers 36 per D-03); `LEFT[3]` Roles `w = 76` becomes `92`
(D-18) and `ACTIVITY_X` (268 / 318) shifts by +16 accordingly; with GS on, `LEFT[4].x` (268) moves to 284 and `ACTIVITY_X` to 334.
```lua
local LEFT = {
	{ key = "name", label = "Name", x = 4, w = 150 },
	{ key = "level", label = "Lvl", x = 156, w = 30, justify = "CENTER" },
	{ key = "role", label = "Roles", x = 190, w = 76 },   -- -> w = 92
}
local ACTIVITY_X = ns.GEAR_SCORE and 318 or 268            -- -> +16 each
```

**Shared `view` and `Collect()` (keep unchanged; they become the data provider's content)** (lines 69-75, 665-701):
```lua
local view = { search = "", fitsRoles = false, sort = "role", desc = false, collapsed = {} }
...
function Instance:Collect()
	local items = self.items
	wipe(items)
	...
	items[1] = mine                       -- own listing
	...
	items[#items + 1] = header            -- self.headers[key], with header.count
	items[#items + 1] = l
	return #sections.solo, #sections.groups
end
```
Item kinds are distinguished by `item.header` (headers are `{ header = true, key = "solo"|"groups" }`, `self.headers` at lines 738) -
exactly what the ScrollBox factory and extent calculator switch on. Element data must be tables: both kinds already are.

**Layout function reused by rows AND column-header strip** (lines 469-484) - do not duplicate, call it from the new header strip with the bar-visibility
offset (RESEARCH Pitfall 6):
```lua
local function Layout(owner, cells, rightAnchor, rightOffset)
	for _, col in ipairs(LEFT) do
		local cell = cells[col.key]
		cell:ClearAllPoints()
		cell:SetPoint("LEFT", owner, "LEFT", col.x, 0)
		cell:SetWidth(col.w)
	end
	cells.listed:ClearAllPoints()
	cells.listed:SetPoint("RIGHT", rightAnchor, rightAnchor == owner and "RIGHT" or "LEFT", rightOffset, 0)
	cells.listed:SetWidth(LISTED_W)
	cells.activity:ClearAllPoints()
	cells.activity:SetPoint("LEFT", owner, "LEFT", ACTIVITY_X, 0)
	cells.activity:SetPoint("RIGHT", cells.listed, "LEFT", -GAP, 0)
end
```

**Row build (one-time) pattern to split into `BuildRow` / `FillRow`** (`Instance:MakeRow`, lines 486-581). Today a single frame serves
both row and divider (`row.divider`, `row.dividerLabel`, `row.fold`, `row.selected`, `row.line`). Phase 2 splits it:
- `BuildRow(frame)` (run behind `frame.tgfBuilt`): cells loop (lines 513-550), `row.hide` / `row.message` buttons (552-559),
  `Layout(row, cells, row.message, -GAP)` (560), `OnEnter = ShowTooltip` / `OnLeave` (575-578). Drop `W.RowHighlight`, `row.selected` BACKGROUND yellow
  bar, `row.line`, `row.divider*`, `row.fold`, and `OnDoubleClick` (570-574). Add the D-20 trio instead:
  `common-button-list-mid2` BACKGROUND (3,-2)/(-3,0), `...-hover` ADD in HIGHLIGHT (3,-3)/(-3,-1), `...-selected` ADD in OVERLAY; own listing swaps to
  `groupfinder-highlightbar` / `-blue`. Every atlas through `W.Atlas(tex, atlas, r, g, b, a)` so a missing atlas falls back to a colour.
- `BuildHeader(frame)` (header kind): `ResultBG` `common-button-list-collapseExpand` (3,-8)/(-3,0), `CategoryLabel` `GameFontNormal` LEFT 12,-4,
  `ExpandIcon`/`CollapseIcon` (`common-button-list-plus`/`-minus`) at RIGHT -12,-5, `Highlight` HIGHLIGHT ADD same atlas (3,-7)/(-3,-1). No selected art, no row highlight (D-08).
  When `C_XMLUtil.GetTemplateInfo("LFGBrowseSearchEntryGroupingTemplate")` exists, the factory passes that name instead and the initializer reads its parentKeys
  (`ResultBG`, `CategoryLabel`, `ExpandIcon`, `CollapseIcon`, `Highlight`) rather than building; keep the same field names on both paths so one `FillHeader` works.

**Existing click wiring to rework** (lines 562-569): the single `OnClick` branches on `r.item.header`. Split:
```lua
-- header
frame:SetScript("OnClick", function(f)
	view.collapsed[f.item.key] = not view.collapsed[f.item.key] or nil   -- same toggle as today, no sound (D-07)
	T.RefreshAll()
end)
-- row (D-09, D-11): select by id, silent on delisted / own
frame:SetScript("OnClick", function(f)
	local l = f.listing
	if not l or l.mine or l.delisted then return end
	inst.selectedID = (inst.selectedID == l.id) and nil or l.id
	W.PlayCheckbox(true)                       -- new helper in Widgets.lua, SOUNDKIT guarded
	inst:RefreshButtons(); inst.list:Reinitialize()
end)
```
Nil guard (RESEARCH anti-pattern): headers and the preview's own listing have `id == nil`, so always `self.selectedID ~= nil and item.id == self.selectedID`.

**Fill pattern to keep and tighten** (`Instance:FillRow`, lines 599-662): it already sets every visual property each call (required by the pool).
Changes: replace `row.selected:SetShown(self.selected == l)` (653) with the by-ID guard; replace the `cell:SetAlpha(l.demoted and 0.4 or 1)` loop (658-661) with
the D-22 grey: `SetTextColor(0.3,0.3,0.3)` on every row text, drop the class colour code in `W.Colored(...)` while greyed, `SetDesaturated(true)` on class/leader icon and role
`slot.tex` (alpha 0.5 on the slot frame), and explicit `false`/1 resets for non-demoted rows (Pitfall 8, 9). The ScrollBox initializer is:
```lua
function(frame, item)
	if not frame.tgfBuilt then
		frame.tgfBuilt = true
		if item.header then inst:BuildHeader(frame) else inst:BuildRow(frame) end
	end
	if item.header then inst:FillHeader(frame, item) else inst:FillRow(frame, item) end
end
```
Never call `T.RefreshAll()` / `SetDataProvider` from inside this (reentrancy error).

**Group icon swap (D-23)** - current line 617: `row.icon:SetClass(who.class)`. For groups use `W.Atlas(row.icon, "groupfinder-icon-leader", ...)` with
`SetSize` reset to 16x16 (or atlas size) when switching back to `SetClass` (Pitfall 9).

**Refresh flow to replace** (`Instance:Refresh`, lines 703-728). Keep the order: visibility guard on `self.band:IsVisible()`, `Collect()`, check/sort labels, status text, button
enable. Replace `self.list:SetItems(self.items, empty)` (716) and the `empty` text logic (714-715) with: searching -> `RemoveDataProvider` + spinner; failed / none / filtered
texts (D-26, D-27); else `box:SetDataProvider(dp, ScrollBoxConstants.RetainScrollPosition)`. Replace lines 722-727 (`self.selected` table ref) with the by-ID lookup:
```lua
local sel = self.selectedID and FindByID(self.items, self.selectedID)
if self.selectedID and (not sel or sel.delisted) then self.selectedID, sel = nil, nil end   -- D-10
self.send:SetEnabled(sel ~= nil)                                                           -- D-12
self.invite:SetEnabled(sel ~= nil and sel.solo and ns.CanInvite())
```
`self:Message(self.selected)` / `self:Invite(self.selected)` in the bottom buttons (lines 844-850) must resolve the listing from `selectedID` the same way.

**Attach layout to rework** (`T.Attach`, lines 733-860):
- `band` (741-746) frame stays as the anchor for `OnShow` (lines 855-857, `band:SetScript("OnShow", ...)` drives `Refresh`).
- Search box (758-766): move out of the checkbox row; anchor to `source.refreshAnchor` (`LFGBrowseFrame.RefreshButton` in game) with the TOPRIGHT fallback (D-14):
```lua
local search = W.EditBox(band, 150, "SearchBoxTemplate")
if search.Instructions then search.Instructions:SetText("Name, activity or note") end
search:HookScript("OnTextChanged", function(b) view.search = lower(b:GetText() or ""); T.RefreshAll() end)
```
  Keep the `HookScript("OnTextChanged")` and `Instructions` lines verbatim. Line 759 `self.fits.Label` anchor is deleted.
- `back` (780-786): keep `EnableMouse(true)` mouse blocker; **delete** `local inset = W.Inset(back)` / `inset:SetAllPoints()` (785-786) (D-13).
- Column header strip (788-833): rebuild with `ColumnDisplayButtonShortTemplate` via `W.Create("Button", header, "ColumnDisplayButtonShortTemplate")` with fallback to the
  existing flat button. Keep the click handler (804-811) verbatim, same-column flip and `FIRST_DESC`:
```lua
b:SetScript("OnClick", function()
	if view.sort == key then view.desc = not view.desc
	else view.sort, view.desc = key, FIRST_DESC[key] == true end
	T.RefreshAll()
end)
```
  and keep the tooltips on `header.role` / `header.gs` (819-832). Drop `W.Line(header)` underline (792-794); the strip sits between art top and `BarTop`.
- `self.list` (835-841): ScrollBox + MinimalScrollBar block (see "ScrollBox wiring" below); `T.Attach` source options gain `refreshAnchor` and `failed()`.
- Bottom bar (843-853): `self.send` at `BOTTOMLEFT 21,16`, `self.invite` at `BOTTOMRIGHT -21,16` stay; `self.status` becomes right-aligned just left of Group Invite; `self.fits`
  is re-anchored to the right of `self.send` (D-17).

**Selection clearing API** - add `function T.ClearSelection()` (loop `T.instances`, set `selectedID = nil`, then `T.RefreshAll()`), modelled on `T.RefreshAll` (lines 862-866):
```lua
function T.RefreshAll()
	for _, inst in ipairs(T.instances) do
		inst:Refresh()
	end
end
```
`T.RelistOneHidden` (869-878) is called from the preview refresh button; MainFrame also calls `T.ClearSelection()` there.

**Hide/show sound (D-28)** - `Hide(l)` (379-387) gains `W.PlayCheckbox(true)` before `T.RefreshAll()`.

#### ScrollBox wiring (no in-repo analog; copy from Blizzard source)

**Source analog:** `Blizzard_GroupFinder_VanillaStyle/Blizzard_LFGVanilla_Browse.lua:55-130` and `Blizzard_SharedXML/Shared/Scroll/ScrollUtil.lua:137-148, 336-358`.
Shape to copy (verified in RESEARCH.md):
```lua
local view = CreateScrollBoxListLinearView()
view:SetElementFactory(function(factory, item)            -- pure: also called with a dummy factory
	if item.header then factory(HEADER_TEMPLATE_OR_BLIZZARD, init) else factory(ROW_TEMPLATE, init) end
end)
view:SetElementExtentCalculator(function(_, item) return item.header and 36 or 40 end)
view:SetElementResetter(function(frame) if GameTooltip:GetOwner() == frame then GameTooltip:Hide() end end)
local box = W.Create("Frame", back, "WowScrollBoxList")
local bar = W.Create("EventFrame", back, "MinimalScrollBar")   -- explicit parent AND EventFrame type
bar:SetPoint("TOPLEFT", box, "TOPRIGHT", 2, -4)
bar:SetPoint("BOTTOMLEFT", box, "BOTTOMRIGHT", 0, 2)
ScrollUtil.InitScrollBoxListWithScrollBar(box, bar, view)
local withBar    = { CreateAnchor("TOPLEFT", back, "TOPLEFT", 0, 0), CreateAnchor("BOTTOMRIGHT", back, "BOTTOMRIGHT", -22, 0) }
local withoutBar = { withBar[1], CreateAnchor("BOTTOMRIGHT", back, "BOTTOMRIGHT", -6, 0) }
local behaviour = ScrollUtil.AddManagedScrollBarVisibilityBehavior(box, bar, withBar, withoutBar)
behaviour:RegisterCallback(ManagedScrollBarVisibilityBehaviorMixin.Event.OnVisibilityChanged, function(_, visible)
	-- re-run Layout(header, header, header, -(ACTIONS_W + GAP) - (visible and 16 or 0))
end, inst)
```
Do NOT copy the stock `CreateAnchor("TOPLEFT", myScrollBox.AnchorOffsetLeft, ...)` quirk (numbers where `relativeTo` belongs). Gate this whole path on
`CreateScrollBoxListLinearView and ScrollUtil and C_XMLUtil and C_XMLUtil.GetTemplateInfo and C_XMLUtil.GetTemplateInfo(ROW_TEMPLATE) and C_XMLUtil.GetTemplateInfo(HEADER_TEMPLATE)`
and `box.SetDataProvider`/`bar.Init` existing (W.Create swallows template errors, see Widgets analog below); otherwise use the extended `W.List`.

**Existing `W.Create` fallback contract the gate relies on** (`UI/Widgets.lua:15-24`, shown below under Shared Patterns).

---

### `UI/Widgets.lua` (utility)

**Analog:** itself.

**`W.List` to extend for kinds (D-05)** (lines 444-515). Current signature `W.List(parent, rowHeight, makeRow, fillRow)` with one pool `list.rows`, fixed row
height, gold 4 px thumb. New shape (Claude's discretion): `W.List(parent, kinds, kindOf, fillItem)` where `kinds = { header = {height=36, make=fn}, row = {height=40, make=fn} }`,
one pool per kind, items laid out top-down by accumulated height (rows no longer share a stride so `Visible()` and the offset are in items, scrolled one item per wheel
step). Keep: the wheel handler (508-511), `OnSizeChanged`/`OnShow` -> `Refresh` (512-513), the `empty` text FontString (457-458), the thumb/track (449-456, 494-505).
```lua
-- existing core to keep
function list:SetItems(items, emptyText)
	self.items = items
	self.empty:SetText(#items == 0 and (emptyText or "") or "")
	self:Refresh()
end
```
Add `list:Reinitialize()` (refill visible frames without relayout) so `Instance` calls one API in both hosts; on the ScrollBox path it maps to `box:ReinitializeFrames()`.

**`W.Check` to rework (D-29)** (lines 265-285) - current:
```lua
function W.Check(parent, label, onClick)
	local c = Create("CheckButton", parent, "UICheckButtonTemplate")
	c:SetSize(24, 24)
	...
	if c.Text then c.Text:SetText("") end
	c.Label = W.Text(c, "GameFontHighlightSmall", 11)
	c.Label:SetPoint("LEFT", c, "RIGHT", 2, 1)
	c.Label:SetText(label or "")
	if onClick then c:SetScript("OnClick", onClick) end
	return c
end
```
New: `c:SetSize(26, 26)`; if `c.Text` exists, `c.Text:SetText(label)` and `c.Label = c.Text`; else keep the own-label path (fallback unchanged). Wrap the OnClick so the
sound plays first: `W.PlayCheckbox(b:GetChecked())` then the caller's `onClick`. Callers (all pass `onClick` via `W.Check(parent, label, fn)`): `Table.lua:748`, `Messages.lua:162`,
`UI/Listing.lua:123, 218, 240, 329`. `.Label` is only read at `Table.lua:759` (being deleted), so the alias is for safety. Note `UI/Listing.lua` is the stand-in's copy and also gains the sound: that
is intended (shared helper).

**New helper `W.PlayCheckbox(on)`** (sound, guarded; RESEARCH "Globals"):
```lua
function W.PlayCheckbox(on)
	if PlaySound and SOUNDKIT then
		PlaySound(on and SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON or SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_OFF)
	end
end
```
(select/deselect of rows and hide/show always call `W.PlayCheckbox(true)` per D-11/D-28.)

**`W.Atlas` / `W.HasAtlas` / `W.Text` (reuse unchanged)** (lines 156-182) - every new texture goes through `W.Atlas(tex, atlas, r, g, b, a)`; every new font string through `W.Text(parent, font, size, justify)`.

**`W.Inset` (lines 184-210)** stays for `Popup()` (line 366) and the stand-in's `Fallback()` (`MainFrame.lua:57`); Table no longer calls it. **`W.RowHighlight` (529-536)**: leave if still used elsewhere (`Table.lua:489` only; Listing.lua - verify with `Grep` before removal) else delete.

**Colour helpers** (new, local fallbacks per RESEARCH "Globals"): `GRAY_FONT_COLOR or {r=.5,g=.5,b=.5}`, `BRIGHTBLUE_FONT_COLOR`, delisted `{r=0.3,g=0.3,b=0.3}`; follow the existing
`W.ClassColor` guard style (lines 46-53):
```lua
function W.ClassColor(class)
	local c = RAID_CLASS_COLORS and RAID_CLASS_COLORS[class]
	if c then return c.r, c.g, c.b end
	c = CLASS_COLORS[class] or WHITE
	return c[1], c[2], c[3]
end
```

---

### `UI/InPlace.lua` (provider/attach, event-driven)

**Analog:** itself.

**`source` table to extend** (lines 60-73):
```lua
local source = {
	listings = function() ... end,
	preview = function() return ns.UsingPreview() end,
	searching = function() return LFGBrowseFrame and LFGBrowseFrame.searching == true end,
}
```
Add `failed = function() return LFGBrowseFrame and LFGBrowseFrame.searchFailed == true end` (read-only field), and the refresh anchor: pass
`refresh = LFGBrowseFrame and LFGBrowseFrame.RefreshButton` through the options table at attach (Pitfall 5: nil-safe). Preview returns false for `failed`/`searching`.

**Attach call** (line 167): `tbl = ns.Table.Attach(f, f.BackgroundArt or f, source)`; keep, with `source.refreshAnchor = f.RefreshButton` set (this is a read, never a write on Blizzard's frame).

**Event routing to change** (lines 28-34, 193-197): `events:SetScript("OnEvent", ReadSoon)` becomes
```lua
events:SetScript("OnEvent", function(_, event)
	if event == "LFG_LIST_SEARCH_RESULTS_RECEIVED" or event == "LFG_LIST_SEARCH_FAILED" then
		ns.Table.ClearSelection()
	end
	ReadSoon()
end)
```

**`LFGBrowse_DoSearch` hook** (lines 186-192) - also clear selection (D-10):
```lua
hooksecurefunc("LFGBrowse_DoSearch", function()
	ns.Table.ClearSelection()          -- clears selectedID and refreshes (so the spinner shows)
end)
```
(replaces `tbl:Refresh()`; `ClearSelection` ends in `RefreshAll`.)

**Taint-safe hiding pattern to keep** (lines 75-83, `StayHidden`; `REPLACED` list 26-27 already holds `ScrollBox`, `ScrollBar`, `NoResultsFound`, `SearchingSpinner`):
```lua
local function StayHidden(part)
	part:Hide()
	hooksecurefunc(part, "Show", part.Hide)
	hooksecurefunc(part, "SetShown", function(self, shown) if shown then self:Hide() end end)
end
```
Do not write fields on `LFGBrowseFrame`. `WIDE = 620` (line 25) stays (D-19).

---

### `UI/MainFrame.lua` (component, preview layout)

**Analog:** itself (`BuildBrowse`, lines 224-308); geometry source `Mainline/Blizzard_LFGVanilla_Browse.xml:426-620`.

**Art layers to extend (D-13)** (lines 235-242). Current `art` is a frame with a single BACKGROUND `groupfinder-background`. Add: `common-insideframe` border layer around it, `groupfinder-ScrollLine` BarTop
at art top -20 and BarMiddle at frame bottom +61, all via `W.Atlas` with a flat fallback colour like the existing line:
```lua
local art = CreateFrame("Frame", nil, panel)
art:SetPoint("TOPLEFT", 4, -80)
art:SetPoint("BOTTOMRIGHT", -4, 3)
local artTex = art:CreateTexture(nil, "BACKGROUND")
artTex:SetAllPoints()
if not W.Atlas(artTex, "groupfinder-background") then
	artTex:SetColorTexture(0.05, 0.05, 0.05, 0.6)
end
```
**Refresh button** (lines 287-297): it becomes the search box anchor, so expose it: pass `refreshAnchor = refresh` in the `Attach` options table, and in its `OnClick` add
`ns.Table.ClearSelection()` next to `ns.Table.RelistOneHidden(ns.state.listings)` (line 288).

**Attach options** (lines 299-306): add `refreshAnchor = refresh`, `failed = function() return false end`, `searching` stays absent/false:
```lua
tbl = ns.Table.Attach(panel, art, {
	listings = function() return ns.PreviewListings(category, activities) end,
	preview = function() return true end,
})
```
`WIDE = 620` (line 15) stays.

---

### `TerribleGroupFinder.toc` (config)

**Analog:** itself (lines 15-23): add one line after `UI\Widgets.lua`.
```
UI\Widgets.lua
UI\Templates.xml
UI\Table.lua
```
`scripts/install.ps1` and `scripts/package.ps1` derive the file set from non-`#` TOC lines (RESEARCH verified); no script edits needed provided `Templates.xml` has no `file=` attribute.

---

### `CLAUDE.md` Architecture list (docs, D-06)

**Analog:** the existing bullets, e.g. `- \`UI/Widgets.lua\` -- \`ns.W\` helpers: ...`. Insert after the `UI/Widgets.lua` bullet and before `UI/Table.lua`:
```
- `UI/Templates.xml` — the two plain virtual Buttons (list header / list row) the table's ScrollBox pools; no scripts, no `file=` paths
```
Also update the `UI/Table.lua` bullet (own ScrollBox list instead of "pooled scroll list"; selection by result ID) and the `UI/Widgets.lua` bullet (pooled scroll list = fallback only). Edit with the Edit tool (no `sed`/redirects on `.md`).

---

### Smoke harness (scratchpad, outside the repo; owned by the plan's test task)

**Analog:** the existing session harness at `...\scratchpad\smoke\` (`run.js`, `harness.lua`, `tail.lua`, `splice.js`) per RESEARCH.md "Validation Architecture":
stubs for `CreateScrollBoxListLinearView`, `CreateDataProvider`, `CreateAnchor`, `ScrollUtil`, `ScrollBoxConstants`, `ManagedScrollBarVisibilityBehaviorMixin`, `C_XMLUtil.GetTemplateInfo`, `SOUNDKIT`, recorded `PlaySound`, stubbed
`LFGBrowseFrame`/`LFGParentFrame`; `UI\Templates.xml` is already skipped by the `%.lua$` filter (`harness.lua:144-156`). Run `node run.js "C:/Users/jonat/Repositories/TerribleGroupFinder"` (plus `--gs`, plus fallback mode); last line must be `SUMMARY: 0 failed`.

## Shared Patterns

### Safe template creation with fallback
**Source:** `UI/Widgets.lua:15-24`
**Apply to:** every Blizzard-template widget the phase adds (WowScrollBoxList, MinimalScrollBar, ColumnDisplayButtonShortTemplate, LoadingSpinnerTemplate, SearchBoxTemplate)
```lua
local function Create(frameType, parent, template)
	if template then
		local ok, f = pcall(CreateFrame, frameType, nil, parent, template)
		if ok and f then
			return f
		end
	end
	return CreateFrame(frameType, nil, parent)
end
W.Create = Create
```
After creation, detect the missing template by probing a member (`box.SetDataProvider`, `bar.Init`, `b.Text`, `spinner.Anim`), the way `W.Button` probes `b:GetNormalTexture()` (Widgets 243) and `W.Check` probes `c.Text` (275).

### Atlas-or-colour fallback
**Source:** `UI/Widgets.lua:156-172`
**Apply to:** all new row/header/column/leader/spinner textures
```lua
function W.Atlas(tex, atlas, r, g, b, a)
	if tex.SetAtlas and HasAtlas(atlas) then
		tex:SetAtlas(atlas)
		tex:SetVertexColor(1, 1, 1, 1)
		return true
	end
	if r then tex:SetColorTexture(r, g, b, a or 1) end
	return false
end
```
Always call `SetDesaturated(true/false)` explicitly (it persists across `SetAtlas`; RESEARCH anti-pattern).

### Taint rules (read-only Blizzard state, own frames only)
**Source:** `UI/InPlace.lua:10-14, 75-83` and CLAUDE.md "Taint"
**Apply to:** Table.lua, InPlace.lua, MainFrame.lua
Only `Hide()`/`hooksecurefunc`/`HookScript`/parenting on Blizzard frames; `LFGBrowseFrame.searching`, `.searchFailed`, `.RefreshButton`, `.BackgroundArt` are read, never written. Our fields (`tgfBuilt`, `listing`, `item`) go only on frames we created. Never inherit `LFGBrowseSearchEntryTemplate` / `LFGBrowseNestedSearchEntryTemplate`; `LFGBrowseSearchEntryGroupingTemplate` is scriptless and safe.

### Secret-value and nil guards on game reads
**Source:** CLAUDE.md "Key Constraints"; pattern in `Listings.lua` (secret values skip the listing)
**Apply to:** `C_LFGList.GetActiveEntryInfo()` read for the activity colour (D-21): `local info = C_LFGList.GetActiveEntryInfo(); if info and not (issecretvalue and issecretvalue(info)) then ... info.activityIDs ... end`; global strings always `X or "fallback"` (as `Table.lua:63-66`: `LFG_LIST_CATEGORY_SOLO_PLAYERS or "Solo players"`).

### Tooltip helper
**Source:** `UI/Widgets.lua:221-237` (`W.Tooltip`) and `Table.lua:286-377` (`ShowTooltip`, uses `row.listing`)
**Apply to:** row button tooltips (hide button, line 579 of Table.lua) and the column headers. Header (section) frames get no tooltip (D-07). Tooltip must be hidden in the ScrollBox element resetter.

### Pool-safe fill
**Source:** `UI/Table.lua:599-662` (`FillRow` sets every property each call)
**Apply to:** `FillRow` and `FillHeader` on both hosts. Pooled frames return with the previous row's colour, alpha, desaturation, button text and shown state; set all of them every time.

### stylua
After each task: `stylua .` from the repo root (CLAUDE.md Workflow); tabs, `.lua` only.

## No Analog Found

| File / Part | Role | Data Flow | Reason |
|-------------|------|-----------|--------|
| ScrollBox + MinimalScrollBar wiring in `UI/Table.lua` | component | virtualized list | Neither this repo nor TerribleBuffTracker uses `WowScrollBoxList`; use Blizzard `Blizzard_LFGVanilla_Browse.lua:55-130` and RESEARCH.md "ScrollBox API (verified)" |
| Loading spinner + states in `UI/Table.lua` | component | event-driven | No spinner in repo; use `LoadingSpinnerTemplate` per RESEARCH.md (`spinner:Hide()` right after creation; `Show()` starts the animation) and stock anchors `Browse.xml:582-590` |
| Sort arrow on column headers | component | transform | Use `auctionhouse-ui-sortarrow` (asc texcoord 0,1,1,0 / desc 0,1,0,1) from `Blizzard_AuctionHouseTableBuilder.xml:204-211`; fallback = existing `" ^"`/`" v"` text (Table.lua:710-713) |

## Metadata

**Analog search scope:** `UI/`, repo root Lua, `scripts/` (via RESEARCH), `C:\Users\jonat\Repositories\TerribleBuffTracker` (XML and ScrollBox grep), Blizzard `forever` branch references from RESEARCH.md
**Files scanned:** UI/Widgets.lua (536 lines), UI/Table.lua (878), UI/InPlace.lua (237), UI/MainFrame.lua (336), toc, TBT CDMTab.xml
**Pattern extraction date:** 2026-11-11
