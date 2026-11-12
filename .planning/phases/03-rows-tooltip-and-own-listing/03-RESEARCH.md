# Phase 3: Rows, Tooltip and Own Listing - Research

**Researched:** 2026-11-11
**Domain:** WoW Forever (interface 16001, game type `camelot`) addon UI: row detail art, GameTooltip building, a stock-style icon button, search-result API reads, taint rules
**Confidence:** HIGH for everything read from the local `forever` branch source; MEDIUM where a global string/atlas/API shape is engine-side (flagged `[ASSUMED]`)

Blizzard references are relative to `C:\Users\jonat\Repositories\wow-ui-source\Interface\AddOns\` (branch `forever`, read-only). Tags: `[CITED: path:line]` = read in that file this session; `[ASSUMED]` = not verifiable from the source tree (engine-side globals, atlas data, undocumented API). `Browse.lua` = `Blizzard_GroupFinder_VanillaStyle/Blizzard_LFGVanilla_Browse.lua`, `Browse.xml` = `Blizzard_GroupFinder_VanillaStyle/Mainline/Blizzard_LFGVanilla_Browse.xml`.

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions
D-01..D-24 in `03-CONTEXT.md` are locked; `03-UI-SPEC.md` is the approved visual contract. Summary the planner must honour:
- **D-01..D-04 (data):** `Listings.lua` keeps raw `l.voiceMode` next to boolean `l.voice`; reads `l.playstyle` (`generalPlaystyle`); reads `GetSearchResultMemberCounts` in a `pcall` into `l.counts` / `l.remaining` (any secret / non-number field -> that table nil; nil-check the function: it is not in the API docs); `GetSearchResultEncounterInfo` is read on tooltip show only, single-activity listings, pcall + secret guard. `Preview.lua` samples gain `voiceMode`, `playstyle`, `remaining` (some groups, so both the server path and the `COMPOSITION` fallback are exercised).
- **D-05..D-08 (roles/voice):** solo = `groupfinder-icon-role-micro-{tank,heal,dps}` T>H>D packed left; groups keep `-large-`; Discord icon only for `voiceMode == Enum.LFGEntryVoiceMode.Discord`, desaturated on greyed rows; tooltip voice line `VOICE_CHAT_MODE_FORMAT` + per-mode label.
- **D-09..D-14 (own row):** Activity cell = `LFG_SELF_LISTING` in `LIGHTGREEN_FONT_COLOR`, no "(you)" suffix; no Whisper and no hide button on it; delist = our own Button inheriting `UIMenuButtonStretchTemplate` 24x22 at RIGHT -8, `groupfinder-icon-redx` atlas size, `UI-Common-MouseHilight` ADD, tooltip `LFG_LIST_UNLIST`; shown only solo or leader (hidden, not disabled); click = `PlaySound(IG_MAINMENU_OPTION_CHECKBOX_ON)` then, only if `C_LFGList.HasActiveEntryInfo()`, `C_LFGList.RemoveListing()` (never `LFGBrowse_DoSearch`, `LFGListingFrame:RemoveListing`, `LFGParentFrameTab1_OnClick`); own row only shown while `HasActiveEntryInfo()` (preview: `ns.state.myListing`); the "Unlist" text path leaves `Instance:Message`.
- **D-15..D-18 (tooltip):** keep `GameTooltip`, `ANCHOR_RIGHT`, never call `LFGBrowseSearchEntryTooltip_UpdateAndShow`; stock order (1 Delisted, 2 New player, 3 Leader line, 4 Members <= 10, 5 Comment, 6 Member count, 7 Voice, 8 Activities grouped, 9 Bosses defeated) then extras (playstyle, spec/area, Friends in group, Listed ago, hidden note); comment on the row in `LIGHTGRAY_FONT_COLOR`.
- **D-19 (refresh):** after every `Refresh`, re-show the tooltip for whichever of our rows is under the mouse (or hide it); same in the `W.List` fallback.
- **D-20/D-21 (hide button):** own Button inheriting `UIMenuButtonStretchTemplate` 24x22 with centred icon `transmog-icon-hidden` (hide) / `socialqueuing-icon-eye` (show), never the red X; `W.Button` "x"/"+" fallback; `ACTIONS_W` grows (HIDE_W 20 -> 24, ACTIONS_W 95).
- **D-22/D-23 (Needs my role):** groups use `l.remaining` with `ns.MyRoles()`, fallback `COMPOSITION`; solo listings keep today's rule; sort uses the same function; greying behaviour unchanged.
- **D-24 (tests):** fengari harness stubs + assertions; all modes end `0 failed`.

### Claude's Discretion
Micro icon size/spacing and delist/hide icon sizes (UI-SPEC fixed 18 px / step 20 / 16 px); `|A:..|a` vs `CreateAtlasMarkup`; splitting `ShowTooltip` into helpers; whether delist and hide share one builder in `UI/Widgets.lua` (UI-SPEC: yes, `W.IconButton`).

### Deferred Ideas (OUT OF SCOPE)
Custom tooltip frame copy of `LFGBrowseSearchEntryTooltip`; compact role counts above 5 players (G18); right-click menu (G25); stock default order (G35); preview stock templates (G38); localization of hard-coded English; Activity width 620 vs 580 (in-game Q1). Messages, key buttons, Auto-send/Auto-invite, contact lock and the Messages tab are Phase 4.
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| UIP-07 | Solo micro role icons; stock voice icon and wording | Role icon section (`Browse.lua:12-21,1479-1499`), Discord icon (`Browse.lua:460-470`, `Browse.xml:162-167`), voice labels (`Blizzard_LFGVanilla_VoiceChat.lua:3-8`), enum values (`LFGConstantsDocumentation.lua:35-45`) |
| UIP-08 | Own row: "Your listing" green + delist button (solo/leader) | Stock own-row logic (`Browse.lua:418-419,450-451`, delist `Browse.xml:114-135`, visibility `Browse.lua:916-918`, mixin `Browse.lua:1293-1302`); `UIMenuButtonStretchMixin` (`SharedUIPanelTemplates.lua:915-968`) |
| UIP-09 | Tooltip in stock order and wording, extras after | Stock tooltip (`Browse.lua:578-875`, `Browse.xml:316-424`); markup helpers (`TextureUtil.lua:279-311`) |
| UIP-13 | Playstyle in tooltip, comment light grey | `generalPlaystyle` field (`LFGListInfoDocumentation.lua:~1010`), `GetGeneralPlaystyleString` availability risk (see Pitfall 3), comment colour (`Browse.lua:921-928`) |
| UIP-14 | Hide button = small stock-style icon button | `UIMenuButtonStretchTemplate` (`SharedUIPanelTemplates.xml:772-858`), atlas usage in source |
| UIP-15 | Needs my role from server remaining counts | `HasRemainingSlotsForLocalPlayerRole` (`Browse.lua:1332-1340`), counts shape (`Browse.lua:698,996,1413`, `Blizzard_GroupFinder/Mainline/LFGList.lua:3946,4110-4125`) |
| UIP-16 | Hovered tooltip refreshes on result update | Stock re-run (`Browse.lua:497-503`), ScrollBox release/resetter order, `W.List` fallback |
</phase_requirements>

## Summary

Everything this phase needs is small, local and Blizzard-pattern work on top of the Phase 2 table: extend `Listings.lua`/`Preview.lua` with four fields, swap the solo role icons for micro atlases, add a Discord texture, rework the own row, replace the hide button with a `UIMenuButtonStretchTemplate` icon button, rebuild `ShowTooltip` in stock order, point `FitsMyRoles` at the server's `*_REMAINING`, and re-show the tooltip after `Refresh`. No external packages, no new XML.

Three findings change the plan versus the CONTEXT/UI-SPEC wording and must be handled explicitly: (1) **the Phase 2 ScrollBox resetter hides the tooltip while `SetDataProvider` runs**, so the post-`Refresh` check must capture the hovered state *before* the list is re-filled (Pitfall 1); (2) **`GetGeneralPlaystyleString` is defined only in `Blizzard_LFGUtil/Mainline/LFGUtil.lua`**, while the camelot TOC loads `Camelot/LFGUtil.lua` (14 lines, no such function), so it may be nil on Forever and needs a fallback via `GROUP_FINDER_GENERAL_PLAYSTYLE1..4` (Pitfall 3); (3) **the stock tooltip leader icon is the texture `Interface\GroupFrame\UI-Group-LeaderIcon` (18x18), not the atlas `groupfinder-icon-leader`** (that atlas is the *row's* PartyIcon) (Pitfall 6). Also: `C_LFGList.GetSearchResultMemberCounts`, `GetSearchResultEncounterInfo` and `RemoveListing` are not in the generated API docs at all, so every read is `pcall` + nil-guarded.

**Primary recommendation:** Land the data layer first (Listings/Preview/Core fields + a `W` colour/atlas-markup helper), then rows (roles, Discord, own row, buttons), then tooltip (stock/extras builders with a pending-blank line builder), then refresh and Needs my role, extending the harness per requirement as in the Validation section.

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| Reading voiceMode / playstyle / member counts | `Listings.lua` (`ns.Listings.Read`) | `Preview.lua` same shape | One listing shape for game and preview; secret guards live here |
| Server remaining-slot decision (Needs my role) | `UI/Table.lua` `FitsMyRoles` | `Core.lua` `ns.MyRoles` | Table owns filter/sort; data comes pre-read on `l.remaining` |
| Row look (micro icons, Discord, own row text/colours) | `UI/Table.lua` `FillRow`/`SetRoles` | `UI/Widgets.lua` helpers | Single fill function serves ScrollBox and `W.List` |
| Icon button builder (delist/hide) | `UI/Widgets.lua` `W.IconButton` | Table wires click handlers | Size, highlight, template probe and fallback in one place |
| Delist action | `UI/Table.lua` (click -> `C_LFGList.RemoveListing()`) | Blizzard event `LFG_LIST_ACTIVE_ENTRY_UPDATE` | Unrestricted call; Blizzard's finder state untouched |
| Tooltip content | `UI/Table.lua` `StockTooltip`/`ExtrasTooltip` | `UI/Widgets.lua` markup/colour helpers | Table owns listing semantics; Widgets owns glyph/colour fallbacks |
| Tooltip refresh on update | `UI/Table.lua` `Instance:Refresh` tail | `list:ForEachFrame` (both hosts) | Event-driven; no timers |
| Own row visibility | `UI/Table.lua` `Collect` | `source` (game: `HasActiveEntryInfo`) | Row disappears without a new search |

## Standard Stack

No installs. Everything is Blizzard API or our own code.

### Core (all verified in source)
| Item | Source | Purpose |
|------|--------|---------|
| `UIMenuButtonStretchTemplate` (Button 40x26, mixin `UIMenuButtonStretchMixin`) | `Blizzard_SharedXML/Mainline/SharedUIPanelTemplates.xml:772-858`, `.lua:915-968` | Delist and hide buttons |
| `CreateAtlasMarkup(atlas, w, h, ox, oy)` -> `|A:%s:%d:%d:%d:%d|a` (note: height then width in the string, `TextureUtil.lua:303-309`) | `Blizzard_SharedXMLBase/TextureUtil.lua:289-311` | Inline tooltip icons |
| `CreateSimpleTextureMarkup(file, w, h)` -> `|T%s:%d:%d:%d:%d|t` | `TextureUtil.lua:279-287` | Stock tooltip leader icon (texture file) |
| `C_LFGList.GetSearchResultMemberCounts(id)` | used `Browse.lua:493,582,1333,1413`; not in API docs | Counts + `*_REMAINING` |
| `C_LFGList.GetSearchResultEncounterInfo(id)` | used `Browse.lua:815`; not in API docs | Completed encounter names (array of strings) |
| `C_LFGList.GetActivityGroupInfo(groupID)` -> `name, orderIndex` | `LFGListInfoDocumentation.lua:167-182` | Activity group header text and order |
| `C_LFGList.RemoveListing()` | used `Browse.lua` n/a; `Blizzard_LFGVanilla_Minimap.lua:65`, `Blizzard_QueueStatusFrame/Camelot/QueueStatusFrameOverrides.lua:44`, `Listing.lua:309,332`; not in API docs | Delist |
| `Enum.LFGEntryVoiceMode` None 0 / Legacy 1 / Discord 2 / Custom 3 | `Blizzard_APIDocumentationGenerated/LFGConstantsDocumentation.lua:35-45` | Voice mode compare/label |
| `Enum.LFGEntryGeneralPlaystyle` None 0 / Learning 1 / FunRelaxed 2 / FunSerious 3 / Expert 4 | `LFGConstantsDocumentation.lua:6-18` | Playstyle |

### Package Legitimacy Audit
No external packages are installed by this phase. Audit not applicable. Packages removed: none. Packages flagged: none.

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| Local activity grouping helper | Stock `LFGUtil_OrganizeActivitiesByActivityGroup` / `LFGUtil_SortActivityGroupIDs` (`Blizzard_LFGVanilla_ParentFrame.lua:196-244`, plain global functions) | Safe to call (they only read `C_LFGList.GetActivityInfoTable` / `GetActivityGroupInfo` and sort local tables; no Blizzard state written), but they need activity IDs, are LoD globals (nil in the preview), and give the preview a different code path. **Recommend: write a ~20-line local helper** (group by `groupID`, order by `orderIndex` then name); do not call them |
| `GetMouseFoci()` (stock) for "under the mouse" | `frame:IsMouseOver()` | `IsMouseOver` is geometric and valid immediately after a re-layout; focus lists lag one frame. Use `IsMouseOver()` (see Pattern 4) |

## Architecture Patterns

### Data flow
```
events (RESULTS_RECEIVED/UPDATED/ACTIVE_ENTRY_UPDATE/...) -> InPlace.ReadSoon (0.2 s)
   -> ns.Listings.Read()   [+ voiceMode, playstyle, counts, remaining, act.groupID]
   -> Instance:Refresh()
        |- capture hovered row  (GameTooltip owned by one of our rows?)      <-- BEFORE the list is touched
        |- Collect(): own row only if HasActiveEntryInfo() / myListing; sort; Demoted(l) uses FitsMyRoles (remaining first)
        |- list:SetItems(items)  -> ScrollBox releases frames (resetter hides tooltip) / W.List refills
        '- RefreshTooltip(): row under mouse + holds a listing -> ShowTooltip(row) else GameTooltip:Hide()
row hover -> ShowTooltip(row) = StockTooltip(l) (blocks 1-9) + ExtrasTooltip(l) (X1-X5), one Show()
delist click -> PlaySound -> if HasActiveEntryInfo then C_LFGList.RemoveListing() -> event -> Refresh drops the own row
```

### Recommended structure (no new files)
```
Listings.lua   # + voiceMode, playstyle, counts, remaining; Act().groupID
Preview.lua    # + voiceMode / playstyle / remaining on samples; Group/Solo `extra` already carries fields
Core.lua       # MyEntry(): drop comment "Your listing"; map mine.voice -> voiceMode; ns.VoiceMode constants
UI/Widgets.lua # + colour table, W.IconButton, W.RoleIcon micro mode, atlas-markup helper
UI/Table.lua   # FillRow/SetRoles/BuildRow/ShowTooltip/FitsMyRoles/Collect/Refresh
```

### Pattern 1: Listing data reads (Listings.lua)
```lua
-- Source: Browse.lua:493,698,1332-1340 (shape), LFGListInfoDocumentation.lua (search result fields)
local function Num(v) return type(v) == "number" and not Secret(v) end
local function ReadCounts(id)
	local fn = C_LFGList.GetSearchResultMemberCounts
	if not fn then return nil end
	local ok, c = pcall(fn, id)
	if not ok or type(c) ~= "table" or Secret(c) then return nil end
	local counts, remaining = { }, { }
	for _, k in ipairs({ "TANK", "HEALER", "DAMAGER" }) do
		local n, r = c[k], c[k .. "_REMAINING"]
		if not (Num(n) and Num(r)) then return nil end   -- D-02: any bad field -> that table nil
		counts[k], remaining[k] = n, r
	end
	return counts, remaining
end
-- in Read():  l.voiceMode = (not Secret(info.voiceMode) and type(info.voiceMode)=="number") and info.voiceMode or nil
--             l.voice = l.voiceMode ~= nil and l.voiceMode ~= 0           -- kept for the search box / old callers
--             l.playstyle = (not Secret(info.generalPlaystyle) and type(info.generalPlaystyle)=="number") and info.generalPlaystyle or nil
--             l.counts, l.remaining = ReadCounts(id)
```
Splitting counts and remaining: D-02 says "that table is nil" for secret/non-number fields; reading them independently (counts can be valid while a `*_REMAINING` is missing) is allowed. If counts and remaining are independent, treat each independently. `Read` already runs under `pcall(Read, id, now)` per listing, so an error never drops the batch.

`Act()` additionally stores `groupID = info.groupFinderActivityGroupID` (`Blizzard_LFGVanilla_ParentFrame.lua:232`) so the tooltip can group activities without another API round trip. Preview activities have no `groupID` -> flat list (D-16 fallback).

### Pattern 2: Icon button builder (`W.IconButton`)
```lua
-- Source: SharedUIPanelTemplates.xml:772-858 (parts TopLeft..MiddleMiddle, ButtonText "Text"), .lua:929-968 (scripts)
function W.IconButton(parent, w, h)
	local b = Create("Button", parent, "UIMenuButtonStretchTemplate")
	local styled = b.MiddleMiddle ~= nil            -- template really applied (W.Create swallows failures)
	if not styled then
		b = W.Button(parent, "", w, h)              -- UIPanelButtonTemplate / flat fallback, text mode
	end
	b:SetSize(w, h)
	b.Icon = b:CreateTexture(nil, "ARTWORK")        -- field name `Icon`: the template nudges it on mouse down/up
	b.Icon:SetPoint("CENTER", 0, 0)
	local hl = b:CreateTexture(nil, "HIGHLIGHT")
	hl:SetTexture("Interface\\Buttons\\UI-Common-MouseHilight"); hl:SetBlendMode("ADD"); hl:SetAllPoints()
	b.styled = styled
	return b
end
```
- The mixin (`OnMouseDown/Up/Show/Enable/Enter/Leave`) only touches its own textures, `self.Icon:AdjustPointsOffset` and (OnEnter/Leave) `GameTooltip` when `self.tooltipText ~= nil`. It never touches finder state: taint-safe to inherit [CITED: SharedUIPanelTemplates.lua:915-968]. Naming the texture `Icon` gives the stock pressed-offset for free; `AdjustPointsOffset` needs the texture to have a point (it has CENTER).
- Do **not** set `b.tooltipText` and also hook OnEnter (double tooltip). Either use `tooltipText` (stock delist way, `Browse.xml:117`) or our `W.Tooltip` hook; recommend `W.Tooltip` for both (needs a dynamic title for hide/show, see Pitfall 8).
- The template has a `Text` ButtonText (`GameFontHighlightSmall`); icon-only buttons leave it empty. The hide button's fallback is the **text** mode ("x"/"+") of `W.Button`, so `b.styled == false` -> `SetText`, `true` -> icon.
- Delist icon: `b.Icon:SetAtlas("groupfinder-icon-redx", true)` (atlas size, stock `Browse.xml:124`); hide/show icon: `SetAtlas(name)` then `SetSize(16, 16)` explicit (UI-SPEC). Re-set size after every `SetAtlas` on reused frames: `SetAtlas(.., true)` resizes the texture.

### Pattern 3: Tooltip builder with pending blank
`GameTooltip` has no per-line spacing; the UI-SPEC blank-line rule (never leading/trailing/double) is easiest as a tiny writer:
```lua
local function Tip(tt)
	local w, pending, wrote = {}, false, false
	function w.line(text, r, g, b, wrap)
		if pending and wrote then tt:AddLine(" ") end
		pending, wrote = false, true
		tt:AddLine(text, r or 1, g or 1, b or 1, wrap)   -- always explicit RGB (default colour of AddLine is [ASSUMED] gold)
	end
	function w.blank() pending = true end
	return w
end
```
Inline icons: `CreateAtlasMarkup(atlas, 14, 14)` is a global in `Blizzard_SharedXMLBase` (always loaded). Tooltip lines with such markup are the Blizzard norm (`Blizzard_DeathRecap.lua:63`, `GameTooltip:AddLine(CreateAtlasMarkup(...) .. text, 1,1,1,true)`). Our `W.Icon` already builds `|A:name:14:14|a` strings; add `W.AtlasMarkup(atlas, size)` that returns "" when `W.HasAtlas(atlas)` is false (never show raw markup) and uses `CreateAtlasMarkup` when present. Pass colour `1,1,1` on lines that carry `|cff` codes.

### Pattern 4: Tooltip refresh (UIP-16)
```lua
-- hovered state is captured BEFORE the list changes: the ScrollBox resetter (Table.lua BuildList) hides
-- the tooltip when it releases the owner frame
function Instance:HoveredRow()
	local owner = GameTooltip:IsShown() and GameTooltip:GetOwner()
	if not owner then return nil end
	local found
	self.list:ForEachFrame(function(frame) if frame == owner then found = true end end)
	return found and true or nil
end
-- Refresh:  local hovered = self:HoveredRow()  ... list:SetItems(...) ...  self:RefreshTooltip(hovered)
function Instance:RefreshTooltip(hovered)
	if not hovered then return end
	local target
	self.list:ForEachFrame(function(frame, item)
		if not target and not item.header and frame.listing and frame:IsMouseOver()
			and not frame.hide:IsMouseOver() and not frame.message:IsMouseOver() then
			target = frame
		end
	end)
	if target then ShowTooltip(target) else GameTooltip:Hide() end
end
```
- Both hosts expose `ForEachFrame(fn(frame, item))` (`Table.lua` host: `box:ForEachFrame`; `W.List:ForEachFrame` over `list.shown`), so the same code serves ScrollBox and fallback.
- `IsMouseOver()` rather than `GetMouseFoci()`: stock uses the focus list (`Browse.lua:497-503`) but focus is only recomputed on the next frame; `IsMouseOver()` is geometric and valid right after layout. The extra exclusion of the child buttons mirrors the real behaviour: entering the Whisper/hide button fires the row's `OnLeave` (the tooltip owner then becomes the button, so `HoveredRow()` is already nil in that case; the exclusion only protects the corner case where the geometry overlaps).
- Call `RefreshTooltip` on **every** exit path of `Refresh` (searching, failed, normal): the early returns call `self.list:Clear()`, and in the `W.List` fallback hidden rows keep a stale tooltip (no resetter there) so the Hide branch matters.
- The ScrollBox may rebind the frame under the mouse to a different listing; `ShowTooltip(target)` reads `target.listing` which `FillRow` has already updated.

### Anti-patterns to avoid
- Checking `GameTooltip:IsShown()` *after* `SetItems`: the resetter has already hidden it (Pitfall 1).
- `row.name:SetPoint("RIGHT", 0, 0)` plus a Discord texture: the FontString is as wide as the cell, so `GetStringWidth()` is the only way to place the icon right after the text (Pitfall 5).
- Calling `LFGBrowse_DoSearch` / `LFGListingFrame:RemoveListing` / `LFGParentFrameTab1_OnClick` from the delist handler (stock does; ours must not, UI-PARITY D9).
- Reusing the large-slot anchor step (15) for micro icons (step 20): re-anchor each slot per fill.
- Forgetting `SetDesaturated(false)` / alpha reset on reused frames (Phase 2 pattern, still applies to new textures).

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Button chrome for delist/hide | Textured custom button | `UIMenuButtonStretchTemplate` via `W.IconButton` | Stock pressed/highlight states; scriptless w.r.t. finder |
| Inline atlas in tooltips | Manual `\|A:` strings scattered | `CreateAtlasMarkup` through one `W.AtlasMarkup` | Argument order is h,w in the format; one place guards missing atlas |
| Voice label text | Own English table | `VOICE_CHAT_MODE_NONE/LEGACY/DISCORD/CUSTOM` + `VOICE_CHAT_MODE_FORMAT` | Localized; mapping identical to `Blizzard_LFGVanilla_VoiceChat.lua:3-8` |
| Playstyle text | Own table | `GetGeneralPlaystyleString` if defined, else `_G["GROUP_FINDER_GENERAL_PLAYSTYLE"..value]`, else preview names | Stock strings; availability is not guaranteed on camelot |
| Tooltip frame | Copy of `LFGBrowseSearchEntryTooltip` | `GameTooltip` | Deferred (custom tooltip needs a taint probe) |

**Key insight:** every "stock" element here is a string global, an atlas, or a scriptless template. The risk is not building them but guarding their absence (preview, client builds) and reused-frame state.

## Runtime State Inventory

Not a rename/refactor phase. Nothing persisted changes: no `TerribleGroupFinderDB` keys are added (`view`, `selectedID`, hovered state are session-only). The `ns.state.hidden` table is unchanged.

## Common Pitfalls

### Pitfall 1: The resetter hides the tooltip before the refresh can see it
**What goes wrong:** the hovered tooltip disappears on every results update and never returns.
**Why:** `BuildList` registers `SetElementResetter` that calls `GameTooltip:Hide()` when `GameTooltip:GetOwner() == frame` (`UI/Table.lua:1016-1020`). `SetDataProvider` releases and re-acquires every frame synchronously, so after `list:SetItems` the tooltip is already hidden and `GameTooltip:IsShown()` is false.
**How to avoid:** capture "a row of ours owns the tooltip" at the *top* of `Refresh` (Pattern 4) and re-show after. Keep the resetter (it prevents a tooltip owned by a recycled frame). Do not remove it to "fix" this.
**Warning signs:** harness test "tooltip refresh after Refresh" passes only if the stub releases frames through the resetter (the existing `releaseAll` does call `view.resetter`).

### Pitfall 2: `FitsMyRoles` reading server zeros for role-less activities
**What goes wrong:** with Needs my role on, every quest/custom group is greyed because the server reports all `*_REMAINING == 0` for activities that have no role expectations.
**Why:** stock only uses remaining as a sort preference (`Browse.lua:1432-1440`), never as a hard filter. Semantics for `useDungeonRoleExpectations == false` activities are unknown here `[ASSUMED]`.
**How to avoid:** treat the server table as authoritative only when it can be trusted: if `l.remaining` exists but all three values are 0 **and** the group is not full (`#l.members < Size(l)`), fall back to the `COMPOSITION` estimate. Keep the rest literal (D-22). Record as Open Question 1 (in-game check).

### Pitfall 3: `GetGeneralPlaystyleString` may be nil on Forever
**What goes wrong:** Lua error (`attempt to call a nil value`) on first tooltip with a playstyle, or no playstyle text.
**Why:** it is defined only in `Blizzard_LFGUtil/Mainline/LFGUtil.lua:315-326`; `Blizzard_LFGUtil.toc` loads `[Family]\LFGUtil.lua` only for mainline and `[Game]\LFGUtil.lua` (= `Camelot/LFGUtil.lua`, 14 lines, `SetLookingForGroupUIAvailable` only) for camelot. Forever's own Browse code calls it (`Browse.lua:478`, guarded by `self.PlaystyleLabel`) so it may exist at runtime `[ASSUMED]`, but the source tree does not prove it.
**How to avoid:** `W.Playstyle(value)`: `type(GetGeneralPlaystyleString)=="function"` -> use it (result `""` = none); else `_G["GROUP_FINDER_GENERAL_PLAYSTYLE"..value]` for value 1-4 (strings the function returns, `LFGUtil.lua:317-323`); else `ns.Preview.playstyles[value]` (preview names are in enum order). Value 0/nil -> no line.

### Pitfall 4: Enum constants missing in the preview
`Enum.LFGEntryVoiceMode` exists on the modern client but not in the harness (`G.Enum = {}`). Define once (Core.lua) `ns.VOICE = (Enum and Enum.LFGEntryVoiceMode) or { None = 0, Legacy = 1, Discord = 2, Custom = 3 }` (values `[CITED: LFGConstantsDocumentation.lua:42-45]`) and compare against `ns.VOICE.Discord` everywhere. Preview samples then carry numeric `voiceMode`.

### Pitfall 5: Name cell geometry vs the Discord icon
**What goes wrong:** UI-SPEC says the name width clamps to `150 - 16 - 4 = 130` with the icon, but today the name FontString starts at x=20 (class/leader icon 16 + 4) and is anchored RIGHT 0, so it already tops out at 130 without any icon; with the icon the real limit is 110.
**How to avoid:** replace the RIGHT anchor with an explicit width: `maxW = 130 - (showDiscord and 20 or 0)`; `row.name:SetWidth(maxW)` (WordWrap is already off, so overflow ellipsizes); place the texture at `LEFT` of the cell with `x = 20 + min(row.name:GetStringWidth(), maxW) + 4`. `GetStringWidth()` is valid right after `SetText`. The inline tags (new-player icon, friend marks) are part of the same string, so the Discord icon lands after them; drop the `W.Icon("voice")` tag from the tag list (D-07). Keep the vertical centre on the name line (cell TOPLEFT y -4).

### Pitfall 6: Leader icon source differs between row and tooltip
Row `PartyIcon` is the atlas `groupfinder-icon-leader` (`Browse.xml:150`, already used). The stock **tooltip** leader icon is `Interface\GroupFrame\UI-Group-LeaderIcon` 18x18 (`Browse.xml:384-390`); only shown when `numMembers > 1` (`Browse.lua:612-618`). UI-SPEC lists the atlas; prefer the stock texture via `CreateSimpleTextureMarkup("Interface\\GroupFrame\\UI-Group-LeaderIcon", 16, 16)` (texture files need no atlas probe), keeping the atlas only as the documented UI-SPEC alternative. Stock role icons in the tooltip are 16 px (UI-SPEC fixes 14; keep UI-SPEC).

### Pitfall 7: Own-row preview data duplicates the label
`Core.lua` `MyEntry()` sets `comment = "Your listing"`; with the new Activity cell text it would show twice. Set `comment = nil` there (and map `voice = mine.voice` to `voiceMode`, `playstyle = mine.playstyle`). In the game the own row's comment is the real comment.

### Pitfall 8: Static tooltip titles on a stateful button
`W.Tooltip(f, title, body)` captures strings at build time, but the hide button must read "Hide" vs "Show" per row state, and the frame is reused. Allow `title`/`body` to be functions (`type(title)=="function" and title(self) or title`), or set `b.tipTitle` in `FillRow` and read it in the hook. The delist button's title is the global `LFG_LIST_UNLIST` (static).

### Pitfall 9: Frame reuse for new fields
Each `FillRow` must set: micro vs large icon atlas **and size and anchor** of every slot, Discord shown/hidden + desaturation + position, name width, delist/hide/message `SetShown`, hide icon atlas, comment colour (no longer through `__tgfColor`), own-row activity text colour (back to GRAY/BRIGHTBLUE afterwards). A solo row followed by a group row on the same frame is the regression case (UI-SPEC).

### Pitfall 10: `Compare` and `FitsMyRoles` cost
`VALUES.role` calls `FitsMyRoles` per comparison for groups. The remaining-count path is O(3) and allocation free; keep the `COMPOSITION` estimate (which shares the module-level `counts/open` tables) as is. Do not allocate per call.

## Code Examples

### Voice label (tooltip block 7)
```lua
-- Source: Blizzard_LFGVanilla_VoiceChat.lua:3-8, Browse.lua:701-709
local VOICE_LABEL = {
	[ns.VOICE.None] = VOICE_CHAT_MODE_NONE, [ns.VOICE.Legacy] = VOICE_CHAT_MODE_LEGACY,
	[ns.VOICE.Discord] = VOICE_CHAT_MODE_DISCORD, [ns.VOICE.Custom] = VOICE_CHAT_MODE_CUSTOM,
}  -- build lazily at tooltip time: globals are strings, evaluate when the client has them
local label = l.voiceMode ~= nil and VOICE_LABEL[l.voiceMode]
if label then tip.line(format(VOICE_CHAT_MODE_FORMAT or "Voice chat: %s", label), NORMAL.r, NORMAL.g, NORMAL.b) end
-- globals missing (preview): English names for the four modes; voiceMode nil: no line
```

### Activities grouped (tooltip block 8)
```lua
-- Source: Browse.lua:711-807 (order: groupless first, then groups by orderIndex/name; INDENT on children;
-- group name is BRIGHTBLUE if any child matches); activities in your listing: C_LFGList.GetActiveEntryInfo().activityIDs
local groups, order, loose = {}, {}, {}
for _, a in ipairs(l.acts) do
	if a.groupID and a.groupID ~= 0 then
		local g = groups[a.groupID] or { id = a.groupID, acts = {} }
		if #g.acts == 0 then order[#order + 1] = g; groups[a.groupID] = g end
		g.acts[#g.acts + 1] = a
	else
		loose[#loose + 1] = a
	end
end
-- per group: name, idx = C_LFGList.GetActivityGroupInfo(g.id) (pcall; nil -> flat fallback); sort order by idx then name
-- INDENT = LFG_LIST_INDENT (format string "%s"-based, Browse.lua:779): format(LFG_LIST_INDENT or "   %s", a.name)
-- match test: inst.activeIDs[a.key] (already built per refresh, ActiveActivityIDs)
```
Blank line between groups only when more than one group (UI-SPEC row 8; stock uses a 6 px gap, `Browse.lua:716,762`).

### Delist handler
```lua
-- Source: Browse.lua:1295-1302 (stock does more; ours must not), Minimap.lua:64-66 (Blizzard calls RemoveListing directly)
delist:SetScript("OnClick", function(b)
	W.PlayCheckbox(true)                       -- SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON
	if inst.source.preview() then
		ns.state.myListing = nil
		ns.Print("preview: unlisted (C_LFGList.RemoveListing).")
		T.RefreshAll()
	elseif C_LFGList.HasActiveEntryInfo() then
		C_LFGList.RemoveListing()               -- event LFG_LIST_ACTIVE_ENTRY_UPDATE -> ReadSoon -> Refresh drops the row
	end
end)
```
Consequence of skipping `LFGListingFrame:RemoveListing`: its local `PENDING_LISTING_UPDATE` stays false, so the Listing frame skips its `LFG_DENIED` feedback sound (`Blizzard_LFGVanilla_Listing.lua:113-115`) and no tab switch happens. The minimap Unlist entry behaves the same way (`Minimap.lua:64`). Acceptable and intended (D-12).

### Own-row visibility (Collect)
In game, an own result (`hasSelf`) is skipped when `not C_LFGList.HasActiveEntryInfo()` (guard for nil function and `issecretvalue`); the preview already builds `MyEntry()` only while `myListing` exists. Put the check behind the `source` table (`source.hasListing()`), so tests can toggle it without `C_LFGList`.

### Row text colours (Widgets)
```lua
-- UI-SPEC colour fallbacks; engine globals are defined client-side [ASSUMED], `.r/.g/.b` used by Browse.lua:926,934
W.LIGHTGREEN = LIGHTGREEN_FONT_COLOR or { r = 0.25, g = 0.75, b = 0.25 }
W.LIGHTGRAY  = LIGHTGRAY_FONT_COLOR  or { r = 0.753, g = 0.753, b = 0.753 }
W.GREEN      = GREEN_FONT_COLOR      or { r = 0.1, g = 1, b = 0.1 }
W.NORMAL     = NORMAL_FONT_COLOR     or { r = 1, g = 0.82, b = 0 }
W.RED        = RED_FONT_COLOR        or { r = 1, g = 0.1, b = 0.1 }
```
(`W.GRAY`, `W.BRIGHTBLUE`, `W.DELISTED` exist.) Delisted tooltip header uses the `GameFontRed` colour: use `W.RED`-equivalent `{1, 0.1, 0.1}`.

## State of the Art

| Old (this repo, Phase 2) | Current (stock) | Impact |
|--------------------------|-----------------|--------|
| Large role icons for solo players | `micro` atlases, simple mapping | Smaller, packed from left |
| `groupfinder-icon-voice` inline tag for any voice mode | `UI-ChatIcon-Discord` only for Discord | Legacy/Custom/None show nothing on the row |
| Tooltip: gold activity title, "Can play:", "Looking for:" | Leader line with inline role icons, member count, voice, activities | Stock order |
| Hard-coded `COMPOSITION` | Server `*_REMAINING` | Needs my role agrees with Forever's own sort |

**Deprecated here:** `Instance:Message`'s "Unlist" branch, `" (you)"` suffix, `row.message` text "Unlist", `W.Icon("voice")` on rows, `l.comment = "Your listing"` in `MyEntry`.

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | `C_LFGList.RemoveListing()` is callable from addon code (unrestricted). Blizzard's own minimap/queue entries call it directly (`Minimap.lua:65`, `QueueStatusFrameOverrides.lua:44`) but it is absent from the API docs | Delist handler | If protected, click triggers `ADDON_ACTION_BLOCKED`; Phase 2 already calls it so UAT should have shown it; CLAUDE.md lists only Search/CreateListing/UpdateListing as restricted |
| A2 | `GetSearchResultMemberCounts` returns a table with `TANK, HEALER, DAMAGER, NOROLE, TANK_REMAINING, HEALER_REMAINING, DAMAGER_REMAINING, LEADER_ROLE_*` (keys seen at `Browse.lua:698,996,1335-1337,1413`); may return nil; field secrecy unknown | Pattern 1 | Fields nil/secret -> `counts/remaining` nil -> estimate path (designed fallback) |
| A3 | `*_REMAINING` is 0 for all roles on role-less activities | Pitfall 2 | Needs my role greys valid groups; guard proposed |
| A4 | `GetGeneralPlaystyleString` may be nil on camelot | Pitfall 3 | Mitigated by fallback chain |
| A5 | `GameTooltip:AddLine` default colour is gold when RGB omitted | Pattern 3 | None: we always pass RGB |
| A6 | Atlases `transmog-icon-hidden`, `socialqueuing-icon-eye`, `groupfinder-icon-role-micro-*`, `UI-ChatIcon-Discord`, `newplayerchat-chaticon-newcomer`, `groupfinder-icon-redx` exist in the Forever atlas data (each is used by name in the local source: `Blizzard_Wardrobe.xml:79`, `QuickJoin.xml:29`, `Browse.lua:18-20`, `Browse.xml:162,180,124`) | Rows | Cosmetic; every site has a fallback |
| A7 | English fallback text of the globals (`Your listing`, `Unlist`, `Bosses defeated:` etc.) | Copy | Preview only; real client uses the localized globals. The global strings are engine-side and not in the source tree |
| A8 | `IsMouseOver()` is true for a pooled row immediately after `SetItems` re-layout | Pattern 4 | If not, the tooltip hides until the next mouse move (the row's `OnEnter` re-shows it); in-game check |

## Open Questions

1. **Remaining counts on role-less activities (A3).**
   - Known: stock never filters on it. Unknown: values for quest/zone/custom activities.
   - Recommendation: ship the "all zero and not full -> estimate" guard (Pitfall 2); verify in game with a quest-category group.
2. **Does the engine re-fire `OnEnter` on a pooled row that the cursor sits on after release/re-acquire?**
   - Unknown; our explicit re-show makes it irrelevant. Double `ShowTooltip` is idempotent (`SetOwner` rebuilds).
3. **Hide icon legibility (UI-PARITY Q10) and micro icon 18 px.** In-game checks, fallbacks coded.

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| node | smoke harness | yes | v24.14.0 | - |
| fengari (scratchpad `smoke/node_modules`) | smoke harness | yes | installed | - |
| stylua | CLAUDE.md "run after each task" | yes | 2.3.1 | - |
| Forever client | in-game UAT | assumed (author's machine) | - | preview via `/tgf preview` |

Baseline re-run this session: `node run.js "C:/Users/jonat/Repositories/TerribleGroupFinder"` with no flag, `--gs`, `--fallback` and `--attach` each ends `SUMMARY: 0 failed`.

## Validation Architecture

(`workflow.nyquist_validation` is `false`; included because the task asks for it.)

### Test Framework
| Property | Value |
|----------|-------|
| Framework | Custom fengari (Lua 5.3 in node) smoke harness, outside the repo |
| Location | `C:\Users\jonat\AppData\Local\Temp\claude\3a677a53f55271b6\8039163f-18e8-4930-88a2-d8efcca63b25\scratchpad\smoke\` (`run.js`, `harness.lua` stubs on top, `tail.lua` assertions from `local fail = 0`, `splice.js`) |
| Run | `node run.js "C:/Users/jonat/Repositories/TerribleGroupFinder" [--gs] [--fallback] [--attach]` |
| Edit flow | stubs: edit the top of `harness.lua`; assertions: edit `tail.lua`, then `node splice.js` (re-splices from `local fail = 0`). `probe(name, fn)` wraps a block in `pcall`; `check(cond, msg)` counts failures; exit 0 only when 0 failed |
| Gate | all four modes end `SUMMARY: 0 failed`, plus `stylua .` in the repo |

### What the harness does today (relevant to this phase)
- `newFrame` records `__text`, `__color` (`SetTextColor`), `__desat`, `__alpha`, `__atlas` (also appended to `log.atlases`), `__w/__h` (`SetSize`), `__points` (`SetPoint` list), `__shown`, `__scripts`. `HookScript` keeps only the **first** hook; `hooksecurefunc` wraps a global and records hooks; `SetShown` is implemented. `IsMouseOver` returns false (override per frame: `fr.IsMouseOver = function() return true end`).
- `GameTooltip` is a frame with `AddLine/AddDoubleLine/SetText` overridden to push **only string args** onto `log.tips` (no colour, no wrap flag, no owner). `SetOwner`, `GetOwner`, `IsShown`, `Hide`, `Show` fall through to generic stubs: `GetOwner()` returns the tooltip itself (matches the resetter check by accident; must be replaced).
- `Enum = {}`, no `C_LFGList` unless `--attach` (then a minimal one with `GetSearchResultInfo/GetActiveEntryInfo/HasActiveEntryInfo` only), `C_Texture.GetAtlasInfo` returns nil (returns `{width=16}` only under `--attach`; tests flip it to `function() return {} end` to exercise atlas branches), `CreateFrame` ignores the template but stores `__template`, `C_XMLUtil.GetTemplateInfo` reads the `KNOWN` table, ScrollBox stubs (`SetDataProvider` releases frames through `view.resetter`, then re-acquires per template pool), `G.PlaySound` records ids in `log.sounds`, `SOUNDKIT` has ids 856/857, `UnitIsGroupLeader` returns true, `IsInGroup` false.
- Existing `rowlook` assertions touch `fr.slots[1].tex.__desat/__alpha`, `fr.hide.__scripts.OnClick`, `fr.name.__color`: keep `row.slots`, `row.hide`, `row.name`, `row.icon` field names stable (or update the probe).

### Stubs to add (top of `harness.lua`)
1. `Enum.LFGEntryVoiceMode = { None = 0, Legacy = 1, Discord = 2, Custom = 3 }`, `Enum.LFGEntryGeneralPlaystyle = { None = 0, Learning = 1, FunRelaxed = 2, FunSerious = 3, Expert = 4 }` (toggle-able to exercise `ns.VOICE` fallback).
2. Globals: `LFG_SELF_LISTING`, `LFG_LIST_UNLIST`, `LFG_LIST_ENTRY_DELISTED`, `LFG_LIST_NEW_PLAYER_FRIENDLY_HEADER`, `LEVEL_ABBR`, `LFG_LIST_COMMENT_FORMAT = '"%s"'`, `LFG_LIST_TOOLTIP_MEMBERS = "Members: %d (%d Tank, %d Healer, %d Damage)"`, `LFG_LIST_TOOLTIP_MEMBERS_SIMPLE = "Members: %d"`, `VOICE_CHAT_MODE_FORMAT`, `VOICE_CHAT_MODE_NONE/LEGACY/DISCORD/CUSTOM`, `LFG_LIST_INDENT = "   %s"`, `LFG_LIST_BOSSES_DEFEATED`, `LFG_LIST_TOOLTIP_FRIENDS_IN_GROUP`, `GROUP_FINDER_GENERAL_PLAYSTYLE1..4`; colour globals `LIGHTGREEN_FONT_COLOR`, `LIGHTGRAY_FONT_COLOR`, `GREEN_FONT_COLOR`, `NORMAL_FONT_COLOR`, `RED_FONT_COLOR` as `{r,g,b}` tables (a toggle that sets them to nil exercises the fallbacks). `CreateAtlasMarkup(name, w, h)` returning `"|A:"..name..":"..h..":"..w..":0:0|a"` and `CreateSimpleTextureMarkup` (toggle nil).
3. `GetGeneralPlaystyleString = function(v) return GROUP_FINDER_GENERAL_PLAYSTYLE1.. end` with a toggle to nil (Pitfall 3 path).
4. GameTooltip capture: replace the string-only overrides with `log.tipLines[#+1] = { text = text, r = r, g = g, b = b, wrap = wrap }` for `AddLine` (keep pushing strings into `log.tips` so the existing GS check still works), `SetOwner(self, owner, anchor)` sets `__owner`/`__anchor` and clears `log.tipLines`, `GetOwner` returns `__owner`, `Hide` clears `__shown`. Count `Show` calls (`log.tipShows`).
5. `UIMenuButtonStretchTemplate` in `KNOWN` (toggle) and `decorate(f, "UIMenuButtonStretchTemplate")` setting `f.MiddleMiddle = newFrame("Texture")` (so `W.IconButton`'s `b.MiddleMiddle` probe works; when the template is "unknown" the part is absent).
6. `C_LFGList` stubs usable outside `--attach` for direct `ns.Listings.Read()` checks: `GetFilteredSearchResults() -> 2, {101, 102}`, `GetSearchResultInfo(id)` (numMembers 1 and 3, `voiceMode`, `generalPlaystyle`, `comment`, `activityIDs`), `GetSearchResultPlayerInfo`, `GetActivityInfoTable(id)` (incl. `groupFinderActivityGroupID`), `GetSearchResultMemberCounts(id)` (with `TANK_REMAINING`...), `GetSearchResultEncounterInfo(id)`, `GetActivityGroupInfo(gid)` (`name, order`), `HasActiveEntryInfo` (flag), `RemoveListing` (records `log.removed`), `GetActiveEntryInfo`.
7. `LFGBrowse_DoSearch`, `LFGListingFrame.RemoveListing`, `LFGParentFrameTab1_OnClick` as recorders (assert they are **not** called).

### Phase Requirements -> Test Map
| Req | Behaviour | Test type | Harness assertion |
|-----|-----------|-----------|-------------------|
| UIP-07 | Solo rows use micro atlases in T>H>D order, left-packed, 18 px, step 20; group rows keep `-large-` 14 px (reset after a solo row on the same frame) | smoke (atlas flag on) | pick a solo item with roles `TD`/`THD`: `row.slots[1].tex.__atlas == "groupfinder-icon-role-micro-tank"`, `[2]` heal/dps, `__w == 18`, third slot hidden; then bind a group item to the same frame (`row:FillRow` through the stub box): slots large, `__w == 14`, anchor x step 15 |
| UIP-07 | Micro atlas missing -> existing large icon / letter fallback | smoke (atlas info nil) | no error; slot letter text set |
| UIP-07 | Discord icon only for `voiceMode == Discord`; greyed -> desaturated + alpha 0.5; none for Legacy/Custom/None/nil/secret; fallback tag when atlas missing | smoke | sample listings with each mode: `row.discord.__shown`, `__atlas == "UI-ChatIcon-Discord"`, `__w == 16`; greyed (hide it) -> `__desat == true`; atlas-missing mode -> `W.Icon("voice")` text tag in `row.name.__text`; no `groupfinder-icon-voice` text anywhere on rows |
| UIP-07 | Tooltip voice line: `VOICE_CHAT_MODE_FORMAT` + label | smoke | tip line text equals `format(VOICE_CHAT_MODE_FORMAT, VOICE_CHAT_MODE_DISCORD)`; absent when `voiceMode` nil; English fallback when globals nil |
| UIP-08 | Own row Activity text == `LFG_SELF_LISTING` colour `LIGHTGREEN`; no "(you)"; no Whisper, no hide on it | smoke (`ns.state.myListing` set) | own frame: `activity.__text == "Your listing"`, colour eq LIGHTGREEN, `name.__text` has no "(you)", `message.__shown == false`, `hide.__shown == false`; the following normal row afterwards has GRAY/BRIGHTBLUE activity colour (reuse reset) |
| UIP-08 | Delist button shown solo/leader, hidden otherwise; atlas, size 24x22, tooltip | smoke | `IsInGroup=false` -> `delist.__shown == true`, `__w,__h == 24,22`, `Icon.__atlas == "groupfinder-icon-redx"`; `IsInGroup=true` + `UnitIsGroupLeader=false` (non-preview, `--attach` with `source.preview=false` if feasible, else call `CanUnlist` through a stubbed source) -> `__shown == false` |
| UIP-08 | Click -> checkbox sound, `RemoveListing` only if active entry, never DoSearch/Tab1/Listing:RemoveListing | smoke | click: `log.sounds` gains 856; `HasActiveEntryInfo=true` -> `log.removed == 1`; false -> 0; recorders for `LFGBrowse_DoSearch`, `LFGListingFrame.RemoveListing`, `LFGParentFrameTab1_OnClick` stay 0; preview mode: `ns.state.myListing == nil` and the own item gone after refresh |
| UIP-08 | Own row disappears after delist without a search; only shown while HasActiveEntryInfo | smoke | set flag false -> `Collect` yields no `mine` item |
| UIP-09 | Stock tooltip order and wording | smoke | hover (`OnEnter`) a group with delisted+newPlayer, comment, voice, 2 activity groups, then extras; index each marker in `log.tipLines` and assert the increasing order: Delisted < NewPlayer? (mutually exclusive) < leader line (contains `LEVEL_ABBR .. " "`) < member lines < comment < members count < voice < activities < bosses < playstyle < spec/area < Friends header < "Listed" < "Hidden until"; no blank first/last/double; header lines `LFG_LIST_TOOLTIP_FRIENDS_IN_GROUP`; solo uses `LFG_LIST_TOOLTIP_MEMBERS_SIMPLE`; group > 10 members: no member lines and no "more" line; `GameTooltip` shown once (`log.tipShows == 1`) |
| UIP-09 | Activity colours: BRIGHTBLUE when in active listing, else GRAY; group name BRIGHTBLUE if any child matches; children indented via `LFG_LIST_INDENT`; flat fallback when no `groupID` | smoke | `tipLines[i].r,g,b` per activity |
| UIP-09 | Bosses defeated read on show only, single activity, pcall + secret guard | smoke | `GetSearchResultEncounterInfo` call counter 0 after `Listings.Read`, 1 after hover; secret/erroring stub raises nothing |
| UIP-13 | Playstyle extra line first after the stock block, `GREEN` colour; comment line `LIGHTGRAY`, wrapped; row comment colour `LIGHTGRAY`, greyed row `{0.3,0.3,0.3}` | smoke | `tipLines` for playstyle text: colour eq GREEN; for comment: eq LIGHTGRAY and `wrap == true`; `row.comment.__color` LIGHTGRAY on a normal row and 0.3 grey on a hidden one; `GetGeneralPlaystyleString = nil` -> text from `GROUP_FINDER_GENERAL_PLAYSTYLE<v>`; value 0 -> no line |
| UIP-14 | Hide button: 24 wide, icon `transmog-icon-hidden` normal / `socialqueuing-icon-eye` when hidden, 16 px icon, never redx; tooltip title Hide/Show; fallback text "x"/"+" when template/atlas missing; `ACTIONS_W == 95` (listed cell anchored accordingly) | smoke (template known / unknown, atlas on / off) | click hide then look at the rebound frame: `hide.Icon.__atlas` swapped; `hide.Icon.__atlas ~= "groupfinder-icon-redx"`; template unknown -> `hide.__text == "x"` then `"+"`; header and row `listed` cell `SetPoint` offset identical |
| UIP-15 | `FitsMyRoles` uses `l.remaining` + `ns.MyRoles()`; fallback to estimate when nil or all-zero-and-not-full; solo rule unchanged; sort value agrees with greying | smoke | preview groups with `remaining = {TANK=0,HEALER=0,DAMAGER=0}` (full) and `{TANK=1,..}`; `ns.state.roles = {tank=false, healer=true, dps=false}`; fitsRoles on -> demoted set equals expected; `Compare` order puts them last; `remaining = nil` group matches old `COMPOSITION` result |
| UIP-16 | After `Refresh` a hovered row's tooltip is re-shown for the listing now in that frame; hidden when nothing under the mouse; also fallback path and searching/failed exits | smoke (default + `--fallback`) | hover row A (owner set), override `IsMouseOver` true on the frame now bound to listing B after a sort change, call `inst:Refresh()`: `log.tipLines` first line matches B; no mouse-over frame -> `GameTooltip.__shown == false`; searching state -> hidden; assert the tooltip was captured **before** the resetter (i.e. refresh still shows it) |
| Data | `Listings.Read` fills `voiceMode`, `voice`, `playstyle`, `counts`, `remaining`; secret/non-number fields -> nil; missing function -> nil | smoke | direct call with the C_LFGList stubs and a secret-valued field via `issecretvalue` override |
| Taint guard | No writes on Blizzard frames, no stock functions called | smoke | attach mode: assert `LFGBrowseFrame`/`LFGParentFrame` keys unchanged versus a snapshot taken before the refresh; tooltip never calls `LFGBrowseSearchEntryTooltip_UpdateAndShow` (recorder) |
| Regression | GS off/on, fallback, attach modes | smoke | `SUMMARY: 0 failed` x4 + `stylua .` clean |

### Sampling Rate
- Per task commit: `node run.js ...` default + `stylua .`.
- Per wave merge: all four modes.
- Phase gate: all four modes 0 failed, then `./scripts/install.bat` and the in-game checks below.

### Wave 0 Gaps
- [ ] Harness stub additions above (harness.lua top; owned by the plan's test task, D-24).
- [ ] Update the `rowlook` probe where it assumes the old slot sizes / "message" text.
- [ ] `ns.VOICE` constant in Core.lua before Listings/Preview/Table use it (load order: Core.lua is first in the TOC).

### In-game checks (cannot be proven from source)
1. `C_LFGList.RemoveListing()` click from our button: no `ADDON_ACTION_BLOCKED`; own row disappears.
2. Hide icon legibility (`transmog-icon-hidden` / `socialqueuing-icon-eye` 16 px in 24x22); micro icon 18 px; Discord icon level with the name; name truncation at 110/130.
3. Tooltip refresh while hovering during a search result update; scroll while hovering.
4. Needs my role on a quest/custom-activity group (remaining semantics, Pitfall 2).
5. Playstyle text appears (function or global fallback); atlas existence list (UI-SPEC "In-game Checks").
6. No taint messages when hovering rows and clicking delist/hide (`/console taintLog 1`).

## Security Domain

`security_enforcement` is not set (enabled by default); this is a client-side UI addon with no network or credentials.

| ASVS Category | Applies | Control |
|---------------|---------|---------|
| V2/V3/V4 auth, session, access | no | - |
| V5 Input validation | yes (limited) | Every API-derived value is type-checked and `issecretvalue`-guarded before string/number use; comment text only goes to `AddLine`/`format("%s")`; search stays plain `string.find(..., 1, true)` |
| V6 Cryptography | no | - |

| Pattern | STRIDE | Mitigation |
|---------|--------|------------|
| Tainted call into restricted finder functions | Elevation | Delist calls only `C_LFGList.RemoveListing()`; never `Search/CreateListing/UpdateListing/LFGBrowse_DoSearch/LFGListingFrame:RemoveListing`; no stock tooltip function; no field writes on Blizzard frames; `UIMenuButtonStretchTemplate` only (no finder mixin) |
| Secret values (chat lockdown) in counts/voice/playstyle/comment | Information disclosure / Lua error | `Secret()` guard per field, `pcall` around undocumented calls, lockdown early return in `Read` already exists |
| Format-string injection via comment | Tampering | Comment is an argument to `format`, never the format string (`LFG_LIST_COMMENT_FORMAT` is the format) |

## Sources

### Primary (HIGH confidence, local `forever` branch)
- `Blizzard_GroupFinder_VanillaStyle/Blizzard_LFGVanilla_Browse.lua` lines 1-45, 364-504, 505-575, 578-875, 880-1003, 1290-1340, 1390-1440, 1479-1538
- `Blizzard_GroupFinder_VanillaStyle/Mainline/Blizzard_LFGVanilla_Browse.xml` 1-215 (data display, delist button, row base), 316-424 (tooltip frame), 250-270 (`PlaystyleLabel`)
- `Blizzard_GroupFinder_VanillaStyle/Blizzard_LFGVanilla_VoiceChat.lua`, `..._ParentFrame.lua:185-273`, `..._Listing.lua:92-130,296-335,925-945`, `..._Minimap.lua:58-70`, `.toc`
- `Blizzard_SharedXML/Mainline/SharedUIPanelTemplates.xml:772-858`, `.lua:905-968`
- `Blizzard_SharedXMLBase/TextureUtil.lua:279-318`
- `Blizzard_LFGUtil/Blizzard_LFGUtil.toc`, `Mainline/LFGUtil.lua:311-326`, `Camelot/LFGUtil.lua`
- `Blizzard_APIDocumentationGenerated/LFGListInfoDocumentation.lua` (search result fields, `GetActivityGroupInfo`, `HasActiveEntryInfo`), `LFGConstantsDocumentation.lua:6-45`
- `Blizzard_GroupFinder/Mainline/LFGList.lua:3946,4105-4125,4517-4529` (same API usage in the retail finder), `Blizzard_DeathRecap.lua:63` (markup in `AddLine`), `Blizzard_QueueStatusFrame/Camelot/QueueStatusFrameOverrides.lua:36-50`
- Project: `UI/Table.lua`, `UI/Widgets.lua`, `Listings.lua`, `Preview.lua`, `Core.lua`, `UI/InPlace.lua`, `TerribleGroupFinder.toc`, smoke harness `run.js` / `harness.lua` / `tail.lua` (baseline re-run: 4 modes, 0 failed)

### Secondary / Tertiary
- None. No web search used (source is local and authoritative). Global string texts, colour globals and atlas data are engine-side (see Assumptions).

## Metadata

**Confidence breakdown:**
- Standard stack / template and API behaviour: HIGH (read end to end)
- Architecture and refresh pitfall (resetter ordering): HIGH (read `Table.lua` and the harness release path)
- Server count semantics for role-less activities, `RemoveListing` restriction, `GetGeneralPlaystyleString` presence: MEDIUM (guards designed)
- Atlases / global strings: MEDIUM (usage cited, data client-side)

**Research date:** 2026-11-11
**Valid until:** 2026-12-11 (re-check `Browse.lua`/`Browse.xml` if the `forever` branch updates)
